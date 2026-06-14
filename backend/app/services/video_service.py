"""
Video analysis service — FR-5: Video Uploads.

Pipeline:
    1. Extract frames from video at a fixed interval (every N seconds).
    2. Filter out blurry or duplicate frames.
    3. Run disease detection on each surviving frame via detection_proxy_service.
    4. Aggregate per-frame results into a single VideoAnalysisResult dict.

The returned dict is compatible with scan_model.update_detection_result() and
the existing detection_result schema used throughout the codebase.

Configuration keys (all optional, read from Flask app.config):
    VIDEO_FRAME_INTERVAL_SEC   — sample one frame every N seconds (default: 2)
    VIDEO_MAX_FRAMES           — hard cap on frames sent to the model (default: 20)
    VIDEO_BLUR_THRESHOLD       — Laplacian variance below this = blurry (default: 80.0)
    VIDEO_MIN_FRAMES_REQUIRED  — abort if fewer frames survive filtering (default: 1)
"""

import logging
import os
import tempfile
import uuid
from collections import Counter

import cv2
import numpy as np
from flask import current_app

from app.services import detection_proxy_service

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def analyze_video(video_path: str, crop_type: str = "tomato") -> dict | None:
    """
    Run the full frame-extraction → detection → aggregation pipeline.

    Args:
        video_path: Absolute path to the video file on disk.
        crop_type:  Crop type string forwarded to the detection service.

    Returns:
        A VideoAnalysisResult dict on success, or None if the pipeline fails
        (e.g. video unreadable, no usable frames, detection service down).
    """
    cfg = _load_config()
    logger.info(
        "Starting video analysis: path=%s crop=%s interval=%ss max_frames=%s",
        video_path, crop_type, cfg["interval_sec"], cfg["max_frames"],
    )

    # --- Step 1: Extract candidate frames ---
    frames = _extract_frames(video_path, cfg["interval_sec"], cfg["max_frames"])
    if not frames:
        logger.warning("No frames could be extracted from video: %s", video_path)
        return None

    logger.info("Extracted %d candidate frames", len(frames))

    # --- Step 2: Filter blurry / near-duplicate frames ---
    sharp_frames = _filter_frames(frames, cfg["blur_threshold"])
    logger.info(
        "%d frames survived quality filter (blur_threshold=%.1f)",
        len(sharp_frames), cfg["blur_threshold"],
    )

    if len(sharp_frames) < cfg["min_frames_required"]:
        logger.warning(
            "Too few usable frames (%d < %d). Aborting video analysis.",
            len(sharp_frames), cfg["min_frames_required"],
        )
        return None

    # --- Step 3: Run detection on each frame ---
    frame_results = _run_detection_on_frames(
        sharp_frames, crop_type,
        debug_frames=cfg["debug_frames"],
        upload_folder=cfg["upload_folder"],
    )
    if not frame_results:
        logger.warning("Detection returned no results for any frame.")
        return None

    logger.info("Detection completed on %d / %d frames", len(frame_results), len(sharp_frames))

    # --- Step 4: Aggregate into a single result ---
    result = _aggregate_results(frame_results, len(frames), len(sharp_frames), crop_type)
    logger.info(
        "Video analysis complete: disease=%s severity=%s confidence=%.3f frames_analyzed=%d",
        result["disease"], result["severity"], result["confidence"], result["frames_analyzed"],
    )
    return result


# ---------------------------------------------------------------------------
# Step 1 — Frame extraction
# ---------------------------------------------------------------------------

def _extract_frames(video_path: str, interval_sec: float, max_frames: int) -> list[np.ndarray]:
    """
    Seek through the video and grab one frame every `interval_sec` seconds.
    Returns a list of BGR numpy arrays (raw OpenCV frames).
    """
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        logger.error("cv2.VideoCapture could not open: %s", video_path)
        return []

    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0          # fall back to 25 fps if unknown
    frame_step = max(1, int(fps * interval_sec))       # frames between samples
    frames: list[np.ndarray] = []
    frame_index = 0

    try:
        while len(frames) < max_frames:
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
            ret, frame = cap.read()
            if not ret:
                break                                  # end of video
            frames.append(frame)
            frame_index += frame_step
    finally:
        cap.release()

    return frames


# ---------------------------------------------------------------------------
# Step 2 — Frame filtering
# ---------------------------------------------------------------------------

def _filter_frames(frames: list[np.ndarray], blur_threshold: float) -> list[np.ndarray]:
    """
    Remove frames that are too blurry using Laplacian variance.
    Also drops near-duplicate frames (perceptual hash difference < 5 bits).

    A frame is kept only if:
      - Its Laplacian variance >= blur_threshold  (sharp enough)
      - Its pHash differs from the previous kept frame by >= 5 bits  (not a duplicate)
    """
    if not frames:
        return []

    kept: list[np.ndarray] = []
    last_hash: np.ndarray | None = None

    for frame in frames:
        # Blur check
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        variance = cv2.Laplacian(gray, cv2.CV_64F).var()
        if variance < blur_threshold:
            logger.debug("Dropping blurry frame (variance=%.1f)", variance)
            continue

        # Duplicate check — 8×8 perceptual hash
        current_hash = _phash(gray)
        if last_hash is not None:
            hamming = np.count_nonzero(current_hash != last_hash)
            if hamming < 5:
                logger.debug("Dropping near-duplicate frame (hamming=%d)", hamming)
                continue

        kept.append(frame)
        last_hash = current_hash

    return kept


def _phash(gray: np.ndarray) -> np.ndarray:
    """Simple 8×8 perceptual hash as a boolean array of 64 bits."""
    small = cv2.resize(gray, (8, 8), interpolation=cv2.INTER_AREA).astype(np.float32)
    mean = small.mean()
    return small > mean          # shape (8, 8) bool


# ---------------------------------------------------------------------------
# Step 3 — Per-frame detection
# ---------------------------------------------------------------------------

def _run_detection_on_frames(
    frames: list[np.ndarray],
    crop_type: str,
    debug_frames: bool = False,
    upload_folder: str = "uploads",
) -> list[dict]:
    """
    Save each frame to a temp file, send it to detection_proxy_service.detect(),
    and collect the results.

    If debug_frames is True, frames are saved to <upload_folder>/debug_frames/
    and kept on disk for inspection instead of being deleted.
    """
    results: list[dict] = []

    if debug_frames:
        debug_dir = os.path.join(upload_folder, "debug_frames")
        os.makedirs(debug_dir, exist_ok=True)
        logger.info("Debug mode: frames will be saved to %s", debug_dir)
    else:
        debug_dir = None

    tmp_dir = tempfile.gettempdir()

    for i, frame in enumerate(frames):
        tmp_path = os.path.join(tmp_dir, f"agrilens_frame_{uuid.uuid4().hex}.jpg")
        try:
            success = cv2.imwrite(tmp_path, frame)
            if not success:
                logger.warning("cv2.imwrite failed for frame %d — skipping", i)
                continue

            if debug_dir:
                debug_path = os.path.join(debug_dir, f"frame_{i:03d}.jpg")
                cv2.imwrite(debug_path, frame)
                logger.info("Debug: saved frame %d → %s", i, debug_path)

            detection = detection_proxy_service.detect(tmp_path, crop_type)
            if detection:
                detection["_frame_index"] = i   # internal metadata, stripped on aggregation
                results.append(detection)
            else:
                logger.debug("Frame %d: detection returned None", i)

        except Exception as exc:
            logger.warning("Frame %d detection error: %s", i, exc)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    return results


# ---------------------------------------------------------------------------
# Step 4 — Aggregation
# ---------------------------------------------------------------------------

_SEVERITY_RANK = {"none": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}
_RISK_RANK     = {"low": 0, "medium": 1, "high": 2, "critical": 3}


def _aggregate_results(
    frame_results: list[dict],
    total_frames_extracted: int,
    frames_after_filter: int,
    crop_type: str,
) -> dict:
    """
    Combine per-frame detections into a single result dict.

    Strategy:
      - disease:    majority vote across frames
      - confidence: mean confidence of frames that voted for the winning disease
      - severity:   maximum severity seen across all frames
      - is_healthy: True only if ALL frames report healthy
      - risk_level: maximum risk level seen
      - top_diseases: top-3 diseases by vote share (for UI display)
    """
    # Strip internal metadata
    clean = [{k: v for k, v in r.items() if k != "_frame_index"} for r in frame_results]

    # --- Majority vote on disease label ---
    disease_votes = Counter(r.get("disease", "Unknown") for r in clean)
    winning_disease, winning_votes = disease_votes.most_common(1)[0]

    # Mean confidence of frames that voted for the winner
    winner_frames = [r for r in clean if r.get("disease") == winning_disease]
    mean_confidence = round(
        sum(r.get("confidence", 0.0) for r in winner_frames) / len(winner_frames), 3
    )

    # --- Max severity ---
    max_severity = max(
        clean, key=lambda r: _SEVERITY_RANK.get(r.get("severity", "none"), 0)
    )
    severity     = max_severity.get("severity", "none")
    risk_level   = max_severity.get("risk_level", "low")

    # Re-check risk_level as max across all frames too
    max_risk_frame = max(
        clean, key=lambda r: _RISK_RANK.get(r.get("risk_level", "low"), 0)
    )
    risk_level = max_risk_frame.get("risk_level", risk_level)

    # --- Healthy only if unanimous ---
    is_healthy = all(r.get("is_healthy", False) for r in clean)

    # --- Recommendation from the highest-severity winning frame ---
    recommendation = (
        winner_frames[0].get("recommendation", "")
        if winner_frames else clean[0].get("recommendation", "")
    )

    # --- Scientific name from the winning disease frame ---
    scientific_name = winner_frames[0].get("scientific_name", "") if winner_frames else ""

    # --- Top-3 diseases by vote count ---
    top_diseases = [
        {
            "disease": disease,
            "votes": votes,
            "vote_share": round(votes / len(clean), 3),
        }
        for disease, votes in disease_votes.most_common(3)
    ]

    return {
        # Core fields — match existing detection_result schema in scan_model.py
        "crop_type":        crop_type,
        "disease":          winning_disease,
        "scientific_name":  scientific_name,
        "confidence":       mean_confidence,
        "severity":         severity,
        "is_healthy":       is_healthy,
        "risk_level":       risk_level,
        "recommendation":   recommendation,
        "model_version":    winner_frames[0].get("model_version", "") if winner_frames else "",

        # Video-specific metadata
        "source":                   "video",
        "frames_extracted":         total_frames_extracted,
        "frames_after_filter":      frames_after_filter,
        "frames_analyzed":          len(clean),
        "disease_vote_share":       round(winning_votes / len(clean), 3),
        "top_diseases":             top_diseases,
    }


# ---------------------------------------------------------------------------
# Config helper
# ---------------------------------------------------------------------------

def _load_config() -> dict:
    """Read video pipeline tuning parameters from Flask app config."""
    try:
        app_config = current_app.config
    except RuntimeError:
        # Outside app context (e.g. tests without app context)
        app_config = {}

    return {
        "interval_sec":        float(app_config.get("VIDEO_FRAME_INTERVAL_SEC", 2)),
        "max_frames":          int(app_config.get("VIDEO_MAX_FRAMES", 20)),
        "blur_threshold":      float(app_config.get("VIDEO_BLUR_THRESHOLD", 80.0)),
        "min_frames_required": int(app_config.get("VIDEO_MIN_FRAMES_REQUIRED", 1)),
        "debug_frames":        bool(app_config.get("VIDEO_SAVE_DEBUG_FRAMES", False)),
        "upload_folder":       str(app_config.get("UPLOAD_FOLDER", "uploads")),
    }