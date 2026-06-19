from io import BytesIO
import os

import pytest
import requests
from werkzeug.datastructures import FileStorage

from app.services import detection_proxy_service, insights_service, storage_service, video_service


def test_build_weather_falls_back_without_api_key(flask_app):
    with flask_app.app_context():
        weather = insights_service.build_weather({"lat": "30.0", "lng": "31.2"}, days=4)

    assert weather["source"] == "fallback"
    assert len(weather["forecast"]) == 4
    assert {"temperature", "humidity", "condition"} <= weather.keys()


def test_detection_proxy_returns_none_when_service_fails_without_mock(flask_app, monkeypatch):
    def raise_connection(*args, **kwargs):
        raise requests.ConnectionError("down")

    monkeypatch.setattr(detection_proxy_service.requests, "post", raise_connection)
    flask_app.config["DETECTION_MOCK_FALLBACK"] = False

    with flask_app.app_context():
        assert detection_proxy_service.detect("http://example.test/leaf.jpg", "tomato") is None


def test_detection_proxy_uses_deterministic_mock_when_enabled(flask_app, monkeypatch):
    monkeypatch.setattr(
        detection_proxy_service.requests,
        "post",
        lambda *args, **kwargs: (_ for _ in ()).throw(requests.ConnectionError("down")),
    )
    flask_app.config["DETECTION_MOCK_FALLBACK"] = True

    with flask_app.app_context():
        first = detection_proxy_service.detect("/tmp/leaf-a.jpg", "tomatoes")
        second = detection_proxy_service.detect("/tmp/leaf-a.jpg", "tomatoes")

    assert first == second
    assert first["crop_type"] == "tomato"
    assert 0.74 <= first["confidence"] <= 0.95


def test_detection_proxy_mock_supports_new_crops(flask_app, monkeypatch):
    monkeypatch.setattr(
        detection_proxy_service.requests,
        "post",
        lambda *args, **kwargs: (_ for _ in ()).throw(requests.ConnectionError("down")),
    )
    flask_app.config["DETECTION_MOCK_FALLBACK"] = True

    with flask_app.app_context():
        grape = detection_proxy_service.detect("/tmp/grape.jpg", "grapes")
        sugarcane = detection_proxy_service.detect("/tmp/sugarcane.jpg", "sugar cane")
        cotton = detection_proxy_service.detect("/tmp/cotton.jpg", "cotton")

    assert grape["crop_type"] == "grape"
    assert "Grape" in grape["disease"]
    assert sugarcane["crop_type"] == "sugarcane"
    assert "Sugarcane" in sugarcane["disease"]
    assert cotton["crop_type"] == "cotton"
    assert "Cotton" in cotton["disease"]


def test_detection_proxy_rejects_mushroom_even_with_mock(flask_app, monkeypatch):
    monkeypatch.setattr(
        detection_proxy_service.requests,
        "post",
        lambda *args, **kwargs: (_ for _ in ()).throw(requests.ConnectionError("down")),
    )
    flask_app.config["DETECTION_MOCK_FALLBACK"] = True

    with flask_app.app_context(), pytest.raises(detection_proxy_service.DetectionValidationError) as exc:
        detection_proxy_service.detect("/tmp/mushroom.jpg", "mushrooms")

    assert exc.value.payload["error_code"] == "UNSUPPORTED_CROP"
    assert "mushroom" not in exc.value.payload["supported_crops"]


def test_detection_proxy_preserves_structured_validation_errors(flask_app, monkeypatch):
    payload = {
        "error_code": "CROP_MISMATCH",
        "selected_crop": "potato",
        "detected_crop": "tomato",
        "message": "This appears to be Tomato, not Potato.",
    }

    class FakeResponse:
        status_code = 422
        text = "validation"

        def json(self):
            return payload

    monkeypatch.setattr(detection_proxy_service.requests, "post", lambda *args, **kwargs: FakeResponse())
    flask_app.config["DETECTION_MOCK_FALLBACK"] = False

    with flask_app.app_context(), pytest.raises(detection_proxy_service.DetectionValidationError) as exc:
        detection_proxy_service.detect("http://example.test/leaf.jpg", "potato")

    assert exc.value.status_code == 422
    assert exc.value.payload["detected_crop"] == "tomato"


def test_detection_proxy_selects_video_keyframes(flask_app, monkeypatch, tmp_path):
    video_path = tmp_path / "clip.mp4"
    video_path.write_bytes(b"fake video")

    class FakeResponse:
        status_code = 200
        text = "ok"

        def json(self):
            return {
                "source": "video_keyframe_model",
                "selected_indices": [1, 4],
                "selected_scores": [0.91, 0.73],
            }

    def fake_post(url, files=None, data=None, timeout=None):
        assert url.endswith("/api/video/keyframes")
        assert data["max_frames"] == "2"
        return FakeResponse()

    monkeypatch.setattr(detection_proxy_service.requests, "post", fake_post)

    with flask_app.app_context():
        result = detection_proxy_service.select_video_keyframes(str(video_path), max_frames=2)

    assert result["selected_indices"] == [1, 4]


def test_video_aggregate_includes_keyframe_selection_metadata():
    result = video_service._aggregate_results(
        [
            {
                "disease": "Healthy",
                "confidence": 0.9,
                "severity": "none",
                "risk_level": "low",
                "is_healthy": True,
                "recommendation": "Keep monitoring.",
                "scientific_name": "Healthy plant",
                "model_version": "local",
                "frame_index": 2,
                "frame_url": "https://cdn.example/frame.jpg",
            }
        ],
        total_frames_extracted=12,
        frames_after_filter=1,
        crop_type="tomato",
        keyframe_selection={
            "source": "video_keyframe_model",
            "model_version": "resnet50-conv1d-keyframe-local-v1",
            "output_contract": "per_frame_keyframe_score",
            "target_fps": 10,
            "input_frames": 12,
            "selected_indices": [2],
            "selected_scores": [0.82],
            "threshold": 0.5,
        },
    )

    assert result["keyframe_selection"]["selected_indices"] == [2]
    assert result["selected_frames"][0]["frame_url"] == "https://cdn.example/frame.jpg"
    assert result["frames_extracted"] == 12


def test_generated_frame_bytes_are_saved_locally(flask_app, tmp_path):
    flask_app.config["UPLOAD_FOLDER"] = str(tmp_path)
    with flask_app.app_context():
        storage_service.init_storage(flask_app)
        url = storage_service.upload_scan_frame_bytes(b"frame", "scan-1", 3)
        path = storage_service.resolve_local_path(url)

    assert url.startswith("/uploads/")
    assert path is not None
    assert os.path.exists(path)


def test_local_storage_upload_and_delete_round_trip(flask_app, tmp_path):
    flask_app.config["UPLOAD_FOLDER"] = str(tmp_path)
    with flask_app.app_context():
        storage_service.init_storage(flask_app)
        file_obj = FileStorage(stream=BytesIO(b"fake image"), filename="leaf.PNG")

        url = storage_service.upload_image(file_obj)
        path = storage_service.resolve_local_path(url)

        assert url.startswith("/uploads/")
        assert path is not None
        assert path.endswith(".png")
        assert storage_service.delete_image(url) is True
        assert storage_service.delete_image(url) is False
