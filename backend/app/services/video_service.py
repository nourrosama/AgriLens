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
import base64
import uuid
from collections import Counter

import cv2
import numpy as np
from flask import current_app

from app.services import detection_proxy_service, storage_service

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def analyze_video(video_path: str, crop_type: str = "tomato", scan_id: str = "") -> dict | None:
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
    keyframe_selection = None
    frame_entries = []
    total_candidate_frames = 0
    if cfg["keyframe_model_enabled"]:
        frame_entries, keyframe_selection = _extract_keyframes_with_model(video_path, cfg)
        total_candidate_frames = int((keyframe_selection or {}).get("input_frames") or len(frame_entries))

    if not frame_entries:
        keyframe_selection = None
        frames = _extract_frames(video_path, cfg["interval_sec"], cfg["max_frames"])
        frame_entries = _frame_entries_from_frames(frames)
        total_candidate_frames = len(frames)

    if not frame_entries:
        logger.warning("No frames could be extracted from video: %s", video_path)
        return None

    logger.info("Extracted %d candidate frames", len(frame_entries))

    # --- Step 2: Filter blurry / near-duplicate frames ---
    sharp_entries = _filter_frame_entries(frame_entries, cfg["blur_threshold"])
    logger.info(
        "%d frames survived quality filter (blur_threshold=%.1f)",
        len(sharp_entries), cfg["blur_threshold"],
    )

    if len(sharp_entries) < cfg["min_frames_required"]:
        logger.warning(
            "Too few usable frames (%d < %d). Aborting video analysis.",
            len(sharp_entries), cfg["min_frames_required"],
        )
        return None

    # --- Step 3: Run detection on each frame ---
    frame_results = _run_detection_on_frames(
        sharp_entries, crop_type,
        scan_id=scan_id,
        debug_frames=cfg["debug_frames"],
        upload_folder=cfg["upload_folder"],
    )
    if not frame_results:
        service_url = current_app.config.get('DETECTION_SERVICE_URL', 'http://localhost:5001')
        raise RuntimeError(
            f"Detection service returned no result for any of the {len(sharp_entries)} frame(s). "
            f"Verify the service is running and reachable at {service_url}."
        )

    logger.info("Detection completed on %d / %d frames", len(frame_results), len(sharp_entries))

    # --- Step 4: Aggregate into a single result ---
    result = _aggregate_results(
        frame_results,
        total_candidate_frames,
        len(sharp_entries),
        crop_type,
        keyframe_selection=keyframe_selection,
    )
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


def _frame_entries_from_frames(frames: list[np.ndarray]) -> list[dict]:
    return [
        {
            "frame": frame,
            "frame_index": index,
            "keyframe_score": None,
        }
        for index, frame in enumerate(frames)
    ]


def _extract_keyframes_with_model(video_path: str, cfg: dict) -> tuple[list[dict], dict | None]:
    selection = detection_proxy_service.select_video_keyframes(video_path, cfg["max_frames"])
    if not selection:
        return [], None

    selected_indices = selection.get("selected_indices") or []
    if not selected_indices:
        logger.warning("Video keyframe model returned no selected indices.")
        return [], selection

    frame_entries = _extract_frames_for_keyframe_indices(
        video_path,
        [int(idx) for idx in selected_indices],
        float(selection.get("target_fps") or cfg["keyframe_target_fps"]),
        [float(score) for score in (selection.get("selected_scores") or [])],
    )
    if not frame_entries:
        logger.warning("Could not map video keyframe indices back to frames; falling back.")
        return [], selection

    logger.info(
        "Video keyframe model selected %d/%s frames",
        len(frame_entries),
        selection.get("input_frames", "?"),
    )
    return frame_entries, selection


def _extract_frames_for_keyframe_indices(
    video_path: str,
    selected_indices: list[int],
    target_fps: float,
    selected_scores: list[float] | None = None,
) -> list[dict]:
    selected = set(selected_indices)
    frames_by_index: dict[int, np.ndarray] = {}
    score_by_index = {
        idx: selected_scores[pos]
        for pos, idx in enumerate(selected_indices)
        if selected_scores and pos < len(selected_scores)
    }
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        logger.error("cv2.VideoCapture could not open: %s", video_path)
        return []

    native_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frame_interval = max(1, int(round(native_fps / target_fps)))
    frame_index = 0
    sampled_index = 0

    try:
        while len(frames_by_index) < len(selected):
            ret, frame = cap.read()
            if not ret:
                break
            if frame_index % frame_interval == 0:
                if sampled_index in selected:
                    frames_by_index[sampled_index] = frame
                sampled_index += 1
            frame_index += 1
    finally:
        cap.release()

    return [
        {
            "frame": frames_by_index[idx],
            "frame_index": idx,
            "keyframe_score": score_by_index.get(idx),
        }
        for idx in selected_indices
        if idx in frames_by_index
    ]


# ---------------------------------------------------------------------------
# Step 2 — Frame filtering
# ---------------------------------------------------------------------------

def _filter_frames(frames: list[np.ndarray], blur_threshold: float) -> list[np.ndarray]:
    return [entry["frame"] for entry in _filter_frame_entries(_frame_entries_from_frames(frames), blur_threshold)]


def _filter_frame_entries(frame_entries: list[dict], blur_threshold: float) -> list[dict]:
    """
    Remove frames that are too blurry using Laplacian variance.
    Also drops near-duplicate frames (perceptual hash difference < 5 bits).

    A frame is kept only if:
      - Its Laplacian variance >= blur_threshold  (sharp enough)
      - Its pHash differs from the previous kept frame by >= 5 bits  (not a duplicate)
    """
    if not frame_entries:
        return []

    kept: list[dict] = []
    last_hash: np.ndarray | None = None

    for entry in frame_entries:
        frame = entry["frame"]
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

        kept.append(entry)
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
    frame_entries: list[dict],
    crop_type: str,
    scan_id: str = "",
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
    artifact_scan_id = scan_id or uuid.uuid4().hex

    for i, entry in enumerate(frame_entries):
        frame = entry["frame"]
        frame_index = int(entry.get("frame_index", i))
        keyframe_score = entry.get("keyframe_score")
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
                detection["frame_index"] = frame_index
                if keyframe_score is not None:
                    detection["keyframe_score"] = round(float(keyframe_score), 4)
                _attach_frame_artifacts(detection, frame, artifact_scan_id, frame_index)
                results.append(detection)
            else:
                logger.warning("Frame %d: detection service returned no result", i)

        except detection_proxy_service.DetectionValidationError:
            raise
        except Exception as exc:
            logger.warning("Frame %d detection error: %s", i, exc)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    return results


def _attach_frame_artifacts(
    detection: dict,
    frame_bgr: np.ndarray,
    scan_id: str,
    frame_index: int,
) -> None:
    encoded, frame_buffer = cv2.imencode(".jpg", frame_bgr)
    if encoded:
        try:
            detection["frame_url"] = storage_service.upload_scan_frame_bytes(
                frame_buffer.tobytes(),
                scan_id,
                frame_index,
            )
        except Exception as exc:
            logger.warning("Failed to upload selected frame artifact: %s", exc)

    gradcam_overlay = detection.pop("gradcam_overlay", None)
    if detection.get("is_healthy", True) or not gradcam_overlay:
        return

    gradcam_bytes = _compose_gradcam_frame(frame_bgr, gradcam_overlay)
    if not gradcam_bytes:
        return

    try:
        detection["gradcam_url"] = storage_service.upload_scan_gradcam_bytes(
            gradcam_bytes,
            scan_id,
            frame_index,
        )
    except Exception as exc:
        logger.warning("Failed to upload Grad-CAM frame artifact: %s", exc)


def _compose_gradcam_frame(frame_bgr: np.ndarray, overlay_base64: str) -> bytes | None:
    try:
        encoded = overlay_base64.split(",", 1)[-1]
        overlay_bytes = base64.b64decode(encoded)
        overlay = cv2.imdecode(np.frombuffer(overlay_bytes, dtype=np.uint8), cv2.IMREAD_UNCHANGED)
        if overlay is None:
            return None

        height, width = frame_bgr.shape[:2]
        overlay = cv2.resize(overlay, (width, height), interpolation=cv2.INTER_AREA)
        if overlay.ndim == 3 and overlay.shape[2] == 4:
            alpha = overlay[:, :, 3:4].astype(np.float32) / 255.0
            overlay_bgr = overlay[:, :, :3].astype(np.float32)
            frame_float = frame_bgr.astype(np.float32)
            composed = overlay_bgr * alpha + frame_float * (1.0 - alpha)
        else:
            overlay_bgr = overlay[:, :, :3] if overlay.ndim == 3 else cv2.cvtColor(overlay, cv2.COLOR_GRAY2BGR)
            composed = cv2.addWeighted(frame_bgr, 0.6, overlay_bgr, 0.4, 0)

        success, buffer = cv2.imencode(".jpg", np.clip(composed, 0, 255).astype(np.uint8))
        if not success:
            return None
        return buffer.tobytes()
    except Exception as exc:
        logger.warning("Failed to compose Grad-CAM frame: %s", exc)
        return None


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
    keyframe_selection: dict | None = None,
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

    # --- Healthy if majority of frames agree (>50% threshold) ---
    # Using unanimous `all()` was too strict: a single noisy frame would flip a
    # healthy video to "diseased" while the majority-vote disease name stayed
    # "Healthy", producing a contradictory result with max severity attached.
    healthy_votes = sum(1 for r in clean if r.get("is_healthy", False))
    is_healthy = healthy_votes / len(clean) > 0.5

    # When the majority says healthy, noisy-frame severity/risk must be reset so
    # the scan controller does not fire a disease-detected notification.
    if is_healthy:
        severity = "none"
        risk_level = "low"

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
    selected_frames = [
        {
            "frame_index": r.get("frame_index"),
            "keyframe_score": r.get("keyframe_score"),
            "frame_url": r.get("frame_url", ""),
            "gradcam_url": r.get("gradcam_url", ""),
            "display_url": r.get("gradcam_url") or r.get("frame_url", ""),
            "disease": r.get("disease", "Unknown"),
            "confidence": r.get("confidence", 0.0),
            "severity": r.get("severity", "none"),
            "risk_level": r.get("risk_level", "low"),
            "is_healthy": r.get("is_healthy", False),
        }
        for r in clean
        if r.get("frame_url") or r.get("gradcam_url")
    ]

    result = {
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
        "selected_frames":          selected_frames,
    }
    if keyframe_selection:
        result["keyframe_selection"] = {
            "source": keyframe_selection.get("source"),
            "model_version": keyframe_selection.get("model_version"),
            "output_contract": keyframe_selection.get("output_contract"),
            "target_fps": keyframe_selection.get("target_fps"),
            "input_frames": keyframe_selection.get("input_frames"),
            "selected_indices": keyframe_selection.get("selected_indices"),
            "selected_scores": keyframe_selection.get("selected_scores"),
            "threshold": keyframe_selection.get("threshold"),
        }
    return result


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
        "keyframe_model_enabled": bool(app_config.get("VIDEO_KEYFRAME_MODEL_ENABLED", False)),
        "keyframe_target_fps": float(app_config.get("VIDEO_KEYFRAME_TARGET_FPS", 10)),
    }
