from io import BytesIO

from flask import Flask

from app.controllers.detection_controller import detection_bp
from app.controllers import detection_controller


def make_client():
    app = Flask(__name__)
    app.config["TESTING"] = True
    app.register_blueprint(detection_bp)
    return app.test_client()


def test_detect_rejects_missing_image():
    response = make_client().post("/api/detect", json={"crop_type": "tomato"})

    assert response.status_code == 400
    assert response.get_json()["error"] == "No image provided"


def test_detect_rejects_unsupported_crop(monkeypatch):
    monkeypatch.setattr(detection_controller.model_loader, "is_supported_crop", lambda crop: False)
    monkeypatch.setattr(detection_controller.model_loader, "supported_crops", lambda: ["tomato"])
    monkeypatch.setattr(
        detection_controller.model_loader,
        "unsupported_crop_payload",
        lambda crop: {
            "error_code": "UNSUPPORTED_CROP",
            "selected_crop": crop,
            "supported_crops": ["tomato"],
            "message": "This crop is not supported yet.",
        },
    )

    response = make_client().post(
        "/api/detect",
        json={"image_url": "https://example.test/leaf.jpg", "crop_type": "banana"},
    )

    assert response.status_code == 422
    assert response.get_json()["error_code"] == "UNSUPPORTED_CROP"
    assert response.get_json()["supported_crops"] == ["tomato"]


def test_detect_from_url_returns_prediction(monkeypatch):
    monkeypatch.setattr(detection_controller.model_loader, "is_supported_crop", lambda crop: True)
    monkeypatch.setattr(
        detection_controller.model_loader,
        "predict_from_url",
        lambda url, crop: {
            "crop_type": crop,
            "disease": "Early blight",
            "confidence": 0.91,
            "is_healthy": False,
        },
    )

    response = make_client().post(
        "/api/detect",
        json={"image_url": "https://example.test/leaf.jpg", "crop_type": "tomatoes"},
    )

    assert response.status_code == 200
    assert response.get_json()["crop_type"] == "tomato"
    assert response.get_json()["confidence"] == 0.91


def test_detect_from_file_reports_model_unavailable(monkeypatch):
    monkeypatch.setattr(detection_controller.model_loader, "is_supported_crop", lambda crop: True)
    monkeypatch.setattr(
        detection_controller.model_loader,
        "predict_from_file_bytes",
        lambda image, crop: (_ for _ in ()).throw(RuntimeError("tomato model is not loaded")),
    )
    monkeypatch.setattr(
        detection_controller.model_loader,
        "get_model_status",
        lambda crop: {"ready": False, "error": "missing checkpoint"},
    )

    response = make_client().post(
        "/api/detect",
        data={"image": (BytesIO(b"fake image"), "leaf.jpg"), "crop_type": "tomato"},
        content_type="multipart/form-data",
    )

    assert response.status_code == 503
    assert response.get_json()["model_status"]["ready"] is False


def test_detect_returns_validation_failure_payload(monkeypatch):
    monkeypatch.setattr(detection_controller.model_loader, "is_supported_crop", lambda crop: True)

    payload = {
        "error_code": "CROP_MISMATCH",
        "selected_crop": "potato",
        "detected_crop": "tomato",
        "message": "This appears to be Tomato, not Potato.",
        "supported_crops": ["tomato", "potato"],
    }
    monkeypatch.setattr(
        detection_controller.model_loader,
        "predict_from_file_bytes",
        lambda image, crop: (_ for _ in ()).throw(
            detection_controller.model_loader.ValidationFailure(payload)
        ),
    )

    response = make_client().post(
        "/api/detect",
        data={"image": (BytesIO(b"fake image"), "leaf.jpg"), "crop_type": "potato"},
        content_type="multipart/form-data",
    )

    assert response.status_code == 422
    assert response.get_json()["error_code"] == "CROP_MISMATCH"
    assert response.get_json()["detected_crop"] == "tomato"


def test_video_keyframes_requires_video_file():
    response = make_client().post("/api/video/keyframes", data={})

    assert response.status_code == 400
    assert response.get_json()["error"] == "No video provided"


def test_video_keyframes_returns_selected_indices(monkeypatch):
    monkeypatch.setattr(
        detection_controller.model_loader,
        "select_video_keyframes",
        lambda path, max_frames=None: {
            "source": "video_keyframe_model",
            "selected_indices": [3, 7],
            "selected_scores": [0.88, 0.76],
            "max_frames": max_frames,
        },
    )

    response = make_client().post(
        "/api/video/keyframes",
        data={"video": (BytesIO(b"fake video"), "clip.mp4"), "max_frames": "2"},
        content_type="multipart/form-data",
    )

    assert response.status_code == 200
    assert response.get_json()["selected_indices"] == [3, 7]
    assert response.get_json()["max_frames"] == 2
