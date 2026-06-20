"""
video_service coverage — uses mocked cv2 and numpy since the libraries are not
installed in the test environment. We focus on testable pure-Python logic:
_load_config, _aggregate_results, _frame_entries_from_frames, analyze_video
(with mocked video capture and detection), _extract_frames, _filter_frame_entries,
_run_detection_on_frames, _compose_gradcam_frame.
"""
import sys
import pytest
from unittest.mock import MagicMock, patch, call
from collections import Counter

# ── Mock cv2 and numpy BEFORE importing video_service ─────────────────────────
_mock_cv2 = MagicMock()
_mock_np  = MagicMock()

# cv2 constants used by video_service
_mock_cv2.CAP_PROP_FPS = 5
_mock_cv2.CAP_PROP_POS_FRAMES = 1
_mock_cv2.COLOR_BGR2GRAY = 6
_mock_cv2.CV_64F = 6
_mock_cv2.INTER_AREA = 3

if 'cv2' not in sys.modules:
    sys.modules['cv2'] = _mock_cv2
if 'numpy' not in sys.modules:
    sys.modules['numpy'] = _mock_np

import app.services.video_service as vs   # noqa: E402

# Alias so test functions can reference without leading underscore
mock_cv2 = _mock_cv2
mock_np  = _mock_np


# ═══════════════════════════════════════════════════════════════════════════════
# _load_config
# ═══════════════════════════════════════════════════════════════════════════════

def test_load_config_defaults(flask_app):
    with flask_app.app_context():
        cfg = vs._load_config()
    assert cfg["interval_sec"] == 2.0
    assert cfg["max_frames"] == 20
    assert cfg["blur_threshold"] == 80.0
    assert cfg["min_frames_required"] == 1
    assert cfg["debug_frames"] is False
    assert cfg["keyframe_model_enabled"] is False


def test_load_config_custom(flask_app):
    with flask_app.app_context():
        flask_app.config["VIDEO_FRAME_INTERVAL_SEC"] = "3"
        flask_app.config["VIDEO_MAX_FRAMES"] = "10"
        flask_app.config["VIDEO_BLUR_THRESHOLD"] = "50.0"
        flask_app.config["VIDEO_MIN_FRAMES_REQUIRED"] = "2"
        flask_app.config["VIDEO_SAVE_DEBUG_FRAMES"] = True
        cfg = vs._load_config()
    assert cfg["interval_sec"] == 3.0
    assert cfg["max_frames"] == 10
    assert cfg["blur_threshold"] == 50.0
    assert cfg["min_frames_required"] == 2
    assert cfg["debug_frames"] is True

    # reset
    flask_app.config.pop("VIDEO_FRAME_INTERVAL_SEC", None)
    flask_app.config.pop("VIDEO_MAX_FRAMES", None)
    flask_app.config.pop("VIDEO_BLUR_THRESHOLD", None)
    flask_app.config.pop("VIDEO_MIN_FRAMES_REQUIRED", None)
    flask_app.config.pop("VIDEO_SAVE_DEBUG_FRAMES", None)


def test_load_config_outside_context():
    cfg = vs._load_config()
    assert "interval_sec" in cfg
    assert cfg["max_frames"] == 20


# ═══════════════════════════════════════════════════════════════════════════════
# _frame_entries_from_frames
# ═══════════════════════════════════════════════════════════════════════════════

def test_frame_entries_from_frames():
    frames = [MagicMock(), MagicMock()]
    entries = vs._frame_entries_from_frames(frames)
    assert len(entries) == 2
    assert entries[0]["frame_index"] == 0
    assert entries[1]["frame_index"] == 1
    assert entries[0]["keyframe_score"] is None


def test_frame_entries_from_empty():
    assert vs._frame_entries_from_frames([]) == []


# ═══════════════════════════════════════════════════════════════════════════════
# _aggregate_results
# ═══════════════════════════════════════════════════════════════════════════════

def _make_result(disease="Rust", severity="medium", risk="medium",
                 is_healthy=False, confidence=0.85, sci="Puccinia", rec="Monitor"):
    return {
        "disease": disease, "severity": severity, "risk_level": risk,
        "is_healthy": is_healthy, "confidence": confidence,
        "scientific_name": sci, "recommendation": rec,
        "model_version": "v1",
        "_frame_index": 0,
        "frame_index": 0,
    }


def test_aggregate_single_result():
    results = [_make_result()]
    out = vs._aggregate_results(results, 10, 3, "wheat")
    assert out["disease"] == "Rust"
    assert out["is_healthy"] is False
    assert out["source"] == "video"
    assert out["frames_analyzed"] == 1
    assert out["confidence"] == 0.85


def test_aggregate_majority_vote():
    results = [
        _make_result("Blight", "high", "high", False, 0.9),
        _make_result("Blight", "high", "high", False, 0.88),
        _make_result("Rust",   "low",  "low",  False, 0.7),
    ]
    out = vs._aggregate_results(results, 30, 3, "tomato")
    assert out["disease"] == "Blight"
    assert out["frames_analyzed"] == 3
    assert len(out["top_diseases"]) <= 3


def test_aggregate_all_healthy():
    results = [
        _make_result("Tomato Healthy", "none", "low", True, 0.99),
        _make_result("Tomato Healthy", "none", "low", True, 0.97),
    ]
    out = vs._aggregate_results(results, 10, 2, "tomato")
    assert out["is_healthy"] is True
    assert out["severity"] == "none"
    assert out["risk_level"] == "low"


def test_aggregate_max_severity():
    results = [
        _make_result("Blight", "high",   "high",   False, 0.9),
        _make_result("Blight", "medium", "medium", False, 0.8),
    ]
    out = vs._aggregate_results(results, 10, 2, "tomato")
    assert out["severity"] == "high"
    assert out["risk_level"] == "high"


def test_aggregate_healthy_resets_severity():
    results = [
        _make_result("Healthy", "none", "low", True, 0.95),
        _make_result("Healthy", "none", "low", True, 0.93),
        _make_result("Rust",    "high", "high", False, 0.6),  # minority
    ]
    out = vs._aggregate_results(results, 10, 3, "wheat")
    # majority healthy → severity/risk reset
    assert out["is_healthy"] is True
    assert out["severity"] == "none"
    assert out["risk_level"] == "low"


def test_aggregate_with_keyframe_selection():
    results = [_make_result()]
    kf = {
        "source": "model",
        "model_version": "kf-v1",
        "output_contract": "indices",
        "target_fps": 2.0,
        "input_frames": 50,
        "selected_indices": [0, 5, 10],
        "selected_scores": [0.9, 0.7, 0.8],
        "threshold": 0.5,
    }
    out = vs._aggregate_results(results, 50, 3, "tomato", keyframe_selection=kf)
    assert "keyframe_selection" in out
    assert out["keyframe_selection"]["source"] == "model"


def test_aggregate_top_diseases():
    results = [
        _make_result("A", confidence=0.9),
        _make_result("A", confidence=0.8),
        _make_result("B", confidence=0.7),
    ]
    out = vs._aggregate_results(results, 20, 3, "tomato")
    assert out["top_diseases"][0]["disease"] == "A"
    assert out["top_diseases"][0]["votes"] == 2


# ═══════════════════════════════════════════════════════════════════════════════
# _filter_frame_entries — patch vs.cv2 and vs.np directly
# ═══════════════════════════════════════════════════════════════════════════════

def test_filter_frame_entries_empty():
    result = vs._filter_frame_entries([], 80.0)
    assert result == []


def test_filter_frame_entries_sharp_frames():
    mock_gray = MagicMock()
    mock_laplacian = MagicMock()
    mock_laplacian.var.return_value = 200.0  # above threshold
    frame1_hash = MagicMock()
    frame2_hash = MagicMock()

    with patch("app.services.video_service.cv2") as mc:
        with patch("app.services.video_service.np") as mn:
            mc.cvtColor.return_value = mock_gray
            mc.Laplacian.return_value = mock_laplacian
            mn.count_nonzero.return_value = 10  # not duplicate

            with patch.object(vs, "_phash", side_effect=[frame1_hash, frame2_hash]):
                entries = [
                    {"frame": MagicMock(), "frame_index": 0, "keyframe_score": None},
                    {"frame": MagicMock(), "frame_index": 1, "keyframe_score": None},
                ]
                result = vs._filter_frame_entries(entries, 80.0)

    assert len(result) == 2


def test_filter_frame_entries_blurry_frames():
    mock_gray = MagicMock()
    mock_laplacian = MagicMock()
    mock_laplacian.var.return_value = 10.0  # below threshold

    with patch("app.services.video_service.cv2") as mc:
        mc.cvtColor.return_value = mock_gray
        mc.Laplacian.return_value = mock_laplacian
        entries = [
            {"frame": MagicMock(), "frame_index": 0, "keyframe_score": None},
            {"frame": MagicMock(), "frame_index": 1, "keyframe_score": None},
        ]
        result = vs._filter_frame_entries(entries, 80.0)

    assert result == []


def test_filter_frame_entries_duplicate_frames():
    mock_gray = MagicMock()
    mock_laplacian = MagicMock()
    mock_laplacian.var.return_value = 200.0  # sharp
    same_hash = MagicMock()

    with patch("app.services.video_service.cv2") as mc:
        with patch("app.services.video_service.np") as mn:
            mc.cvtColor.return_value = mock_gray
            mc.Laplacian.return_value = mock_laplacian
            mn.count_nonzero.return_value = 2  # hamming < 5 = duplicate

            with patch.object(vs, "_phash", return_value=same_hash):
                entries = [
                    {"frame": MagicMock(), "frame_index": 0, "keyframe_score": None},
                    {"frame": MagicMock(), "frame_index": 1, "keyframe_score": None},
                ]
                result = vs._filter_frame_entries(entries, 80.0)

    assert len(result) == 1


# ═══════════════════════════════════════════════════════════════════════════════
# _extract_frames
# ═══════════════════════════════════════════════════════════════════════════════

def test_extract_frames_video_not_opened():
    mock_cap = MagicMock()
    mock_cap.isOpened.return_value = False
    with patch("app.services.video_service.cv2") as mc:
        mc.VideoCapture.return_value = mock_cap
        result = vs._extract_frames("/fake/video.mp4", 2.0, 20)
    assert result == []


def test_extract_frames_success():
    fake_frame = MagicMock()
    mock_cap = MagicMock()
    mock_cap.isOpened.return_value = True
    mock_cap.read.side_effect = [(True, fake_frame), (False, None)]
    mock_cap.get.return_value = 25.0
    with patch("app.services.video_service.cv2") as mc:
        mc.VideoCapture.return_value = mock_cap
        result = vs._extract_frames("/fake/video.mp4", 2.0, 20)
    assert result == [fake_frame]
    mock_cap.release.assert_called_once()


def test_extract_frames_max_capped():
    fake_frame = MagicMock()
    mock_cap = MagicMock()
    mock_cap.isOpened.return_value = True
    mock_cap.read.return_value = (True, fake_frame)
    mock_cap.get.return_value = 25.0
    with patch("app.services.video_service.cv2") as mc:
        mc.VideoCapture.return_value = mock_cap
        result = vs._extract_frames("/fake/video.mp4", 2.0, 3)
    assert len(result) == 3


# ═══════════════════════════════════════════════════════════════════════════════
# _run_detection_on_frames
# ═══════════════════════════════════════════════════════════════════════════════

def test_run_detection_on_frames_empty():
    result = vs._run_detection_on_frames([], "wheat")
    assert result == []


def test_run_detection_on_frames_imwrite_failure():
    entry = {"frame": MagicMock(), "frame_index": 0, "keyframe_score": None}
    with patch("app.services.video_service.cv2") as mc:
        mc.imwrite.return_value = False
        with patch("app.services.detection_proxy_service.detect") as mock_detect:
            result = vs._run_detection_on_frames([entry], "tomato")
    mock_detect.assert_not_called()
    assert result == []


def test_run_detection_on_frames_detection_none():
    entry = {"frame": MagicMock(), "frame_index": 0, "keyframe_score": None}
    with patch("app.services.video_service.cv2") as mc:
        mc.imwrite.return_value = True
        with patch("app.services.detection_proxy_service.detect", return_value=None):
            with patch("os.path.exists", return_value=True):
                with patch("os.remove"):
                    result = vs._run_detection_on_frames([entry], "tomato")
    assert result == []


def test_run_detection_on_frames_success():
    entry = {"frame": MagicMock(), "frame_index": 0, "keyframe_score": 0.9}
    detection = {
        "disease": "Rust", "is_healthy": False, "confidence": 0.85,
        "severity": "medium", "risk_level": "medium",
    }
    with patch("app.services.video_service.cv2") as mc:
        mc.imwrite.return_value = True
        with patch("app.services.detection_proxy_service.detect", return_value=dict(detection)):
            with patch("app.services.video_service._attach_frame_artifacts"):
                with patch("os.path.exists", return_value=True):
                    with patch("os.remove"):
                        result = vs._run_detection_on_frames([entry], "wheat", scan_id="scan123")
    assert len(result) == 1
    assert result[0]["disease"] == "Rust"
    assert result[0]["keyframe_score"] == 0.9


def test_run_detection_on_frames_exception_continues():
    entries = [
        {"frame": MagicMock(), "frame_index": 0, "keyframe_score": None},
        {"frame": MagicMock(), "frame_index": 1, "keyframe_score": None},
    ]
    side_effects = [Exception("network error"),
                    {"disease": "Blight", "is_healthy": False, "confidence": 0.8}]
    with patch("app.services.video_service.cv2") as mc:
        mc.imwrite.return_value = True
        with patch("app.services.detection_proxy_service.detect", side_effect=side_effects):
            with patch("app.services.video_service._attach_frame_artifacts"):
                with patch("os.path.exists", return_value=False):
                    result = vs._run_detection_on_frames(entries, "tomato")
    assert len(result) == 1


def test_run_detection_validation_error_propagates():
    from app.services.detection_proxy_service import DetectionValidationError
    entry = {"frame": MagicMock(), "frame_index": 0, "keyframe_score": None}
    with patch("app.services.video_service.cv2") as mc:
        mc.imwrite.return_value = True
        with patch("app.services.detection_proxy_service.detect",
                   side_effect=DetectionValidationError({"error_code": "NOT_A_PLANT"}, 422)):
            with patch("os.path.exists", return_value=False):
                with pytest.raises(DetectionValidationError):
                    vs._run_detection_on_frames([entry], "banana")


# ═══════════════════════════════════════════════════════════════════════════════
# _compose_gradcam_frame
# ═══════════════════════════════════════════════════════════════════════════════

def test_compose_gradcam_frame_invalid_overlay():
    with patch("app.services.video_service.cv2"):
        result = vs._compose_gradcam_frame(MagicMock(), "invalid-base64-data!!!")
    assert result is None or isinstance(result, bytes)


def test_compose_gradcam_frame_imdecode_none():
    import base64
    fake_b64 = base64.b64encode(b"fake-png-data").decode()
    with patch("app.services.video_service.cv2") as mc:
        with patch("app.services.video_service.np") as mn:
            mn.frombuffer.return_value = MagicMock()
            mc.imdecode.return_value = None
            result = vs._compose_gradcam_frame(MagicMock(), fake_b64)
    assert result is None


# ═══════════════════════════════════════════════════════════════════════════════
# analyze_video (full pipeline with mocks)
# ═══════════════════════════════════════════════════════════════════════════════

def test_analyze_video_no_frames(flask_app):
    mock_cap = MagicMock()
    mock_cap.isOpened.return_value = False
    with patch("app.services.video_service.cv2") as mc:
        mc.VideoCapture.return_value = mock_cap
        with flask_app.app_context():
            flask_app.config["VIDEO_KEYFRAME_MODEL_ENABLED"] = False
            result = vs.analyze_video("/fake/video.mp4", "tomato")
    assert result is None
    flask_app.config.pop("VIDEO_KEYFRAME_MODEL_ENABLED", None)


def test_analyze_video_too_few_frames(flask_app):
    mock_cap = MagicMock()
    mock_cap.isOpened.return_value = True
    mock_cap.get.return_value = 25.0
    mock_cap.read.side_effect = [(True, MagicMock()), (False, None)]
    mock_laplacian = MagicMock()
    mock_laplacian.var.return_value = 5.0  # blurry

    with patch("app.services.video_service.cv2") as mc:
        mc.VideoCapture.return_value = mock_cap
        mc.cvtColor.return_value = MagicMock()
        mc.Laplacian.return_value = mock_laplacian
        with flask_app.app_context():
            flask_app.config["VIDEO_KEYFRAME_MODEL_ENABLED"] = False
            flask_app.config["VIDEO_MIN_FRAMES_REQUIRED"] = 1
            result = vs.analyze_video("/fake/video.mp4", "wheat")
    assert result is None
    flask_app.config.pop("VIDEO_KEYFRAME_MODEL_ENABLED", None)
    flask_app.config.pop("VIDEO_MIN_FRAMES_REQUIRED", None)


def test_analyze_video_success(flask_app):
    fake_frame = MagicMock()
    mock_cap = MagicMock()
    mock_cap.isOpened.return_value = True
    mock_cap.get.return_value = 25.0
    mock_cap.read.side_effect = [(True, fake_frame), (False, None)]
    mock_laplacian = MagicMock()
    mock_laplacian.var.return_value = 200.0  # sharp

    detection = {
        "disease": "Wheat Rust", "is_healthy": False, "confidence": 0.85,
        "severity": "medium", "risk_level": "medium",
        "scientific_name": "Puccinia", "recommendation": "Monitor",
        "model_version": "v1",
    }

    with patch("app.services.video_service.cv2") as mc:
        with patch("app.services.video_service.np") as mn:
            mc.VideoCapture.return_value = mock_cap
            mc.cvtColor.return_value = MagicMock()
            mc.Laplacian.return_value = mock_laplacian
            mc.imwrite.return_value = True
            mn.count_nonzero.return_value = 10

            with patch.object(vs, "_phash", return_value=MagicMock()):
                with patch("app.services.detection_proxy_service.detect",
                           return_value=dict(detection)):
                    with patch("app.services.video_service._attach_frame_artifacts"):
                        with patch("os.path.exists", return_value=False):
                            with flask_app.app_context():
                                flask_app.config["VIDEO_KEYFRAME_MODEL_ENABLED"] = False
                                result = vs.analyze_video("/fake/video.mp4", "wheat",
                                                         scan_id="scan123")
    flask_app.config.pop("VIDEO_KEYFRAME_MODEL_ENABLED", None)
    assert result is not None
    assert result["disease"] == "Wheat Rust"
    assert result["source"] == "video"


def test_analyze_video_no_detection_results_raises(flask_app):
    fake_frame = MagicMock()
    mock_cap = MagicMock()
    mock_cap.isOpened.return_value = True
    mock_cap.get.return_value = 25.0
    mock_cap.read.side_effect = [(True, fake_frame), (False, None)]
    mock_laplacian = MagicMock()
    mock_laplacian.var.return_value = 200.0  # sharp

    with patch("app.services.video_service.cv2") as mc:
        with patch("app.services.video_service.np") as mn:
            mc.VideoCapture.return_value = mock_cap
            mc.cvtColor.return_value = MagicMock()
            mc.Laplacian.return_value = mock_laplacian
            mc.imwrite.return_value = True
            mn.count_nonzero.return_value = 10

            with patch.object(vs, "_phash", return_value=MagicMock()):
                with patch("app.services.detection_proxy_service.detect", return_value=None):
                    with patch("os.path.exists", return_value=False):
                        with flask_app.app_context():
                            flask_app.config["VIDEO_KEYFRAME_MODEL_ENABLED"] = False
                            with pytest.raises(RuntimeError):
                                vs.analyze_video("/fake/video.mp4", "wheat")
    flask_app.config.pop("VIDEO_KEYFRAME_MODEL_ENABLED", None)


# ═══════════════════════════════════════════════════════════════════════════════
# _extract_keyframes_with_model
# ═══════════════════════════════════════════════════════════════════════════════

def test_extract_keyframes_with_model_no_selection():
    cfg = vs._load_config()
    with patch("app.services.detection_proxy_service.select_video_keyframes", return_value=None):
        entries, selection = vs._extract_keyframes_with_model("/fake/video.mp4", cfg)
    assert entries == []
    assert selection is None


def test_extract_keyframes_with_model_no_indices():
    cfg = vs._load_config()
    with patch("app.services.detection_proxy_service.select_video_keyframes",
               return_value={"input_frames": 100, "selected_indices": []}):
        entries, selection = vs._extract_keyframes_with_model("/fake/video.mp4", cfg)
    assert entries == []
    assert selection is not None


def test_extract_keyframes_with_model_success():
    cfg = vs._load_config()
    kf_result = {
        "selected_indices": [0, 5],
        "selected_scores": [0.9, 0.8],
        "target_fps": 2.0,
        "input_frames": 50,
    }
    fake_frame = MagicMock()
    mock_cap = MagicMock()
    mock_cap.isOpened.return_value = True
    mock_cap.get.return_value = 25.0
    mock_cap.read.side_effect = [(True, fake_frame)] * 10 + [(False, None)]

    with patch("app.services.detection_proxy_service.select_video_keyframes",
               return_value=kf_result):
        with patch("app.services.video_service.cv2") as mc:
            mc.VideoCapture.return_value = mock_cap
            entries, selection = vs._extract_keyframes_with_model("/fake/video.mp4", cfg)

    assert selection is not None
