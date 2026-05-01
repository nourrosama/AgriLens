from app.main import create_app


def test_health_endpoint_reports_forecast_service_identity():
    client = create_app().test_client()

    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.get_json()["service"] == "agrilens-forecast-service"


def test_forecast_is_deterministic_for_same_input():
    client = create_app().test_client()
    payload = {
        "farm_id": "farm-1",
        "field_id": "field-a",
        "days_ahead": 5,
        "disease_count": 2,
    }

    first = client.post("/api/forecast", json=payload)
    second = client.post("/api/forecast", json=payload)

    assert first.status_code == 200
    assert first.get_json() == second.get_json()
    assert len(first.get_json()["forecast"]) == 5


def test_forecast_zero_days_returns_empty_series_but_valid_summary():
    client = create_app().test_client()

    response = client.post("/api/forecast", json={"farm_id": "farm-1", "days_ahead": 0})

    assert response.status_code == 200
    body = response.get_json()
    assert body["forecast"] == []
    assert 0 <= body["risk_score"] <= 1
    assert body["risk_level"] in {"low", "medium", "high", "critical"}
