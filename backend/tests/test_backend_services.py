from io import BytesIO

import pytest
import requests
from werkzeug.datastructures import FileStorage

from app.services import detection_proxy_service, insights_service, storage_service


def test_risk_level_thresholds_are_ordered():
    assert insights_service.risk_level_from_score(0.1) == "low"
    assert insights_service.risk_level_from_score(0.35) == "medium"
    assert insights_service.risk_level_from_score(0.6) == "high"
    assert insights_service.risk_level_from_score(0.8) == "critical"


def test_compute_forecast_uses_scan_severity_and_weather():
    scans = [
        {"detection_result": {"severity": "critical"}},
        {"detection_result": {"severity": "high"}},
    ]
    weather = {
        "humidity": 88,
        "condition": "Rainy",
        "temperature": 28,
        "wind_kmh": 9,
        "forecast": [{"day": "Mon", "humidity": 90, "condition": "Rainy"}],
    }

    result = insights_service.compute_forecast(scans, weather, days_ahead=3)

    assert result["risk_level"] == "critical"
    assert result["spread_probability"] > 0.7
    assert len(result["forecast"]) == 3
    assert all(point["risk_level"] in {"high", "critical"} for point in result["forecast"])


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
        mushroom = detection_proxy_service.detect("/tmp/mushroom.jpg", "mushrooms")

    assert grape["crop_type"] == "grape"
    assert "Grape" in grape["disease"]
    assert mushroom["crop_type"] == "mushroom"
    assert "Mushroom species" in mushroom["disease"]


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
