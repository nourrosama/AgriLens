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

    response = make_client().post(
        "/api/detect",
        json={"image_url": "https://example.test/leaf.jpg", "crop_type": "banana"},
    )

    assert response.status_code == 422
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
