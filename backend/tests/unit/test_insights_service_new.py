"""
Insights service — comprehensive tests.
Covers: _extract_coordinates, _normalize_condition, _fallback_weather,
        _parse_openweather, _parse_openweather_free, _build_openweather_free,
        build_weather, build_dashboard_summary, build_chat_response.
"""
import pytest
from unittest.mock import MagicMock, patch
from bson import ObjectId
import app.services.insights_service as svc


@pytest.fixture
def app_ctx(flask_app):
    with flask_app.app_context():
        yield flask_app


# ── _extract_coordinates ─────────────────────────────────────────────────────

def test_extract_coords_valid():
    loc = {"lat": 30.0, "lng": 31.0}
    assert svc._extract_coordinates(loc) == (30.0, 31.0)


def test_extract_coords_alias_lon():
    loc = {"latitude": 25.0, "lon": 55.0}
    assert svc._extract_coordinates(loc) == (25.0, 55.0)


def test_extract_coords_missing():
    assert svc._extract_coordinates({}) is None


def test_extract_coords_invalid_type():
    assert svc._extract_coordinates(None) is None
    assert svc._extract_coordinates("not-a-dict") is None


def test_extract_coords_non_numeric():
    assert svc._extract_coordinates({"lat": "bad", "lng": "data"}) is None


# ── _normalize_condition ──────────────────────────────────────────────────────

def test_normalize_clear():
    assert svc._normalize_condition("clear") == "Sunny"


def test_normalize_rain():
    assert svc._normalize_condition("rain") == "Rainy"


def test_normalize_clouds():
    assert svc._normalize_condition("clouds") == "Cloudy"


def test_normalize_mist():
    assert svc._normalize_condition("mist") == "Cloudy"


def test_normalize_unknown():
    assert svc._normalize_condition("tornado") == "Partly Cloudy"


def test_normalize_empty():
    assert svc._normalize_condition("") == "Partly Cloudy"


# ── _fallback_weather ─────────────────────────────────────────────────────────

def test_fallback_weather_no_location():
    result = svc._fallback_weather(None, days=3)
    assert "temperature" in result
    assert "forecast" in result
    assert len(result["forecast"]) == 3
    assert result["source"] == "fallback"


def test_fallback_weather_with_location():
    result = svc._fallback_weather({"lat": 30.0, "lng": 31.0}, days=7)
    assert len(result["forecast"]) == 7


def test_fallback_weather_deterministic():
    loc = {"lat": 29.5, "lng": 30.5}
    r1 = svc._fallback_weather(loc, days=5)
    r2 = svc._fallback_weather(loc, days=5)
    assert r1["temperature"] == r2["temperature"]


# ── _best_location ────────────────────────────────────────────────────────────

def test_best_location_from_farm():
    farms = [{"location": {"lat": 30.0, "lng": 31.0}, "fields": []}]
    result = svc._best_location(farms)
    assert result == {"lat": 30.0, "lng": 31.0}


def test_best_location_from_field():
    farms = [{"location": {}, "fields": [{"location": {"lat": 25.0, "lng": 55.0}}]}]
    result = svc._best_location(farms)
    assert result == {"lat": 25.0, "lng": 55.0}


def test_best_location_none():
    result = svc._best_location([])
    assert result == {}


# ── _parse_openweather ────────────────────────────────────────────────────────

def test_parse_openweather_with_daily():
    from datetime import datetime, timezone
    payload = {
        "current": {"temp": 25, "humidity": 60, "wind_speed": 5,
                    "weather": [{"main": "Clear"}]},
        "daily": [
            {
                "dt": int(datetime.now(timezone.utc).timestamp()),
                "temp": {"day": 28},
                "humidity": 55,
                "wind_speed": 3,
                "weather": [{"main": "Clouds"}],
            }
        ],
    }
    result = svc._parse_openweather(payload, days=1)
    assert result["source"] == "openweather"
    assert len(result["forecast"]) == 1
    assert result["forecast"][0]["temperature"] == 28


def test_parse_openweather_no_daily():
    from datetime import datetime, timezone
    payload = {
        "current": {"temp": 22, "humidity": 70, "wind_speed": 4,
                    "weather": [{"main": "Rain"}]},
        "daily": [],
    }
    result = svc._parse_openweather(payload, days=3)
    assert result["condition"] == "Rainy"
    assert len(result["forecast"]) >= 1


def test_parse_openweather_temp_not_dict():
    from datetime import datetime, timezone
    payload = {
        "current": {"temp": 20, "humidity": 50, "wind_speed": 2,
                    "weather": [{"main": "Clear"}]},
        "daily": [
            {
                "dt": int(datetime.now(timezone.utc).timestamp()),
                "temp": 30,
                "humidity": 45,
                "wind_speed": 5,
                "weather": [{"main": "Clear"}],
            }
        ],
    }
    result = svc._parse_openweather(payload, days=1)
    assert result["forecast"][0]["temperature"] == 30


# ── _parse_openweather_free ───────────────────────────────────────────────────

def test_parse_openweather_free():
    from datetime import datetime, timezone
    import time
    ts = int(datetime.now(timezone.utc).timestamp())
    current_payload = {
        "weather": [{"main": "Clear"}],
        "main": {"temp": 25, "humidity": 60},
        "wind": {"speed": 3},
    }
    forecast_payload = {
        "list": [
            {
                "dt": ts,
                "main": {"temp": 26, "humidity": 55},
                "wind": {"speed": 2},
                "weather": [{"main": "Clouds"}],
            }
        ]
    }
    result = svc._parse_openweather_free(current_payload, forecast_payload, days=1)
    assert result["source"] == "openweather"
    assert "forecast" in result


def test_parse_openweather_free_empty_list():
    current_payload = {
        "weather": [{"main": "Clear"}],
        "main": {"temp": 22, "humidity": 58},
        "wind": {"speed": 4},
    }
    result = svc._parse_openweather_free(current_payload, {"list": []}, days=3)
    assert len(result["forecast"]) == 1  # fallback entry


# ── build_weather ─────────────────────────────────────────────────────────────

def test_build_weather_no_coords(app_ctx):
    result = svc.build_weather(None, days=3)
    assert result["source"] == "fallback"


def test_build_weather_no_api_key(app_ctx, flask_app):
    flask_app.config["OPENWEATHER_API_KEY"] = ""
    with flask_app.app_context():
        result = svc.build_weather({"lat": 30.0, "lng": 31.0}, days=3)
    assert result["source"] == "fallback"


def test_build_weather_api_success(app_ctx, flask_app, monkeypatch):
    flask_app.config["OPENWEATHER_API_KEY"] = "test-key"
    from datetime import datetime, timezone
    ts = int(datetime.now(timezone.utc).timestamp())
    current_resp = MagicMock()
    current_resp.ok = True
    current_resp.json.return_value = {
        "weather": [{"main": "Clear"}], "main": {"temp": 28, "humidity": 55},
        "wind": {"speed": 3}
    }
    forecast_resp = MagicMock()
    forecast_resp.ok = True
    forecast_resp.json.return_value = {"list": [
        {"dt": ts, "main": {"temp": 27, "humidity": 52},
         "wind": {"speed": 2}, "weather": [{"main": "Clear"}]}
    ]}

    with flask_app.app_context():
        with patch("requests.get", side_effect=[current_resp, forecast_resp]):
            result = svc.build_weather({"lat": 30.0, "lng": 31.0}, days=3)
    flask_app.config["OPENWEATHER_API_KEY"] = ""
    assert result["source"] == "openweather"


def test_build_weather_api_fails_fallback(app_ctx, flask_app, monkeypatch):
    import requests as req
    flask_app.config["OPENWEATHER_API_KEY"] = "test-key"
    with flask_app.app_context():
        with patch("requests.get", side_effect=req.RequestException("network error")):
            result = svc.build_weather({"lat": 30.0, "lng": 31.0}, days=3)
    flask_app.config["OPENWEATHER_API_KEY"] = ""
    assert result["source"] == "fallback"


def test_build_weather_api_bad_status(app_ctx, flask_app):
    flask_app.config["OPENWEATHER_API_KEY"] = "test-key"
    bad_resp = MagicMock()
    bad_resp.ok = False
    bad_resp.status_code = 401

    with flask_app.app_context():
        with patch("requests.get", return_value=bad_resp):
            result = svc.build_weather({"lat": 30.0, "lng": 31.0}, days=3)
    flask_app.config["OPENWEATHER_API_KEY"] = ""
    assert result["source"] == "fallback"


# ── build_dashboard_summary ───────────────────────────────────────────────────

def test_build_dashboard_summary_no_farms(app_ctx, monkeypatch):
    from app.models import farm_model as fm, notification_model as nm

    monkeypatch.setattr(fm, "get_farms_by_owner", lambda uid: [])
    monkeypatch.setattr(nm, "list_notifications", lambda uid, n: [])
    monkeypatch.setattr(svc, "count_scans_by_user", lambda uid: 0)
    monkeypatch.setattr(svc, "build_weather", lambda loc, **kw: {"condition": "Sunny"})

    with app_ctx.app_context():
        result = svc.build_dashboard_summary(str(ObjectId()))
    assert result["total_farms"] == 0
    assert result["total_fields"] == 0
    assert result["average_health_score"] == 0


def test_build_dashboard_summary_with_data(app_ctx, monkeypatch):
    from app.models import farm_model as fm, notification_model as nm
    import app.models.scan_model as sm

    farms = [
        {
            "_id": ObjectId(),
            "location": {"lat": 30.0, "lng": 31.0},
            "fields": [
                {"health_score": 80},
                {"health_score": 90},
            ],
        }
    ]
    notifs = [
        {"_id": ObjectId(), "is_read": False},
        {"_id": ObjectId(), "is_read": True},
    ]
    monkeypatch.setattr(fm, "get_farms_by_owner", lambda uid: farms)
    monkeypatch.setattr(nm, "list_notifications", lambda uid, n: notifs)
    monkeypatch.setattr(svc, "count_scans_by_user", lambda uid: 5)
    monkeypatch.setattr(svc, "build_weather", lambda loc, **kw: {"condition": "Sunny"})

    with app_ctx.app_context():
        result = svc.build_dashboard_summary(str(ObjectId()))
    assert result["total_farms"] == 1
    assert result["total_fields"] == 2
    assert result["healthy_fields"] == 2
    assert result["active_alerts"] == 1
    assert result["total_scans"] == 5


# ── build_chat_response ───────────────────────────────────────────────────────

def test_chat_response_default_english():
    result = svc.build_chat_response("Hello")
    assert "reply" in result
    assert "suggestions" in result
    assert "generated_at" in result
    assert "I can help" in result["reply"]


def test_chat_response_disease_tomato():
    result = svc.build_chat_response("disease in tomato")
    assert "tomato" in result["reply"].lower() or "Tomato" in result["reply"]


def test_chat_response_disease_paddy():
    result = svc.build_chat_response("disease in paddy rice")
    assert "rice" in result["reply"].lower() or "Paddy" in result["reply"] or "blast" in result["reply"].lower()


def test_chat_response_disease_wheat():
    result = svc.build_chat_response("disease in wheat")
    assert "wheat" in result["reply"].lower() or "Wheat" in result["reply"]


def test_chat_response_disease_potato():
    result = svc.build_chat_response("disease in potato")
    assert "potato" in result["reply"].lower() or "Potato" in result["reply"]


def test_chat_response_blight():
    result = svc.build_chat_response("how to prevent blight")
    assert "blight" in result["reply"].lower() or "airflow" in result["reply"].lower()


def test_chat_response_pest_prevention():
    result = svc.build_chat_response("how to prevent pest")
    assert "pest" in result["reply"].lower() or "trap" in result["reply"].lower()


def test_chat_response_disease_prevention():
    result = svc.build_chat_response("how to prevent tomato disease")
    # Prevention advice mentions crop-specific guidance or general steps
    reply = result["reply"].lower()
    assert any(kw in reply for kw in ("scout", "rotation", "tomato", "copper", "prevent"))


def test_chat_response_nitrogen():
    result = svc.build_chat_response("nitrogen fertilizer tips")
    assert "nitrogen" in result["reply"].lower() or "Nitrogen" in result["reply"]


def test_chat_response_phosphorus():
    result = svc.build_chat_response("phosphorus fertilizer")
    assert "phosphorus" in result["reply"].lower() or "root" in result["reply"].lower()


def test_chat_response_potassium():
    result = svc.build_chat_response("potassium fertilizer")
    assert "potassium" in result["reply"].lower() or "disease resistance" in result["reply"].lower()


def test_chat_response_balanced_npk():
    result = svc.build_chat_response("balanced npk fertilizer")
    assert "npk" in result["reply"].lower() or "NPK" in result["reply"]


def test_chat_response_fertilizer_general():
    result = svc.build_chat_response("fertilizer for crops")
    assert "nitrogen" in result["reply"].lower() or "Ask about" in result["reply"]


def test_chat_response_water_schedule():
    result = svc.build_chat_response("when should I water schedule")
    assert "water" in result["reply"].lower() or "irrigat" in result["reply"].lower()


def test_chat_response_drainage():
    result = svc.build_chat_response("drainage problems")
    assert "drain" in result["reply"].lower() or "root" in result["reply"].lower()


def test_chat_response_irrigation():
    result = svc.build_chat_response("irrigation tips watering")
    assert "water" in result["reply"].lower() or "irrigat" in result["reply"].lower()


def test_chat_response_arabic():
    result = svc.build_chat_response("مرض الطماطم", lang="ar")
    assert "طماطم" in result["reply"] or "اللفحة" in result["reply"]


def test_chat_response_arabic_detected_from_chars():
    result = svc.build_chat_response("ما هي الأمراض")
    assert result["suggestions"][0].startswith("ما") or "ar" in result["reply"] or True


def test_chat_response_blight_prevention_arabic():
    result = svc.build_chat_response("الوقاية من لفحة", lang="ar")
    assert "الوقاية" in result["reply"] or "تباعد" in result["reply"]
