"""
Weather controller, farm controller, and scan controller coverage.
"""
import pytest
from unittest.mock import MagicMock, patch
from bson import ObjectId
from datetime import datetime, timezone


# ═══════════════════════════════════════════════════════════════════════════════
# Weather controller tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def weather_client(client_for, monkeypatch, current_user):
    from app.controllers.weather_controller import weather_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(weather_bp)


@pytest.fixture
def weather_headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


FAKE_WEATHER = {"temperature": 28, "condition": "Sunny", "source": "fallback"}


def test_get_weather_by_coords(weather_client, weather_headers, monkeypatch):
    from app.services import insights_service as ins
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: FAKE_WEATHER)
    r = weather_client.get("/api/weather?lat=30.0&lng=31.0", headers=weather_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["weather"]["temperature"] == 28


def test_get_weather_no_params_no_farms(weather_client, weather_headers, monkeypatch):
    from app.models import farm_model as fm
    from app.services import insights_service as ins
    monkeypatch.setattr(fm, "get_farms_by_owner", lambda uid: [])
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: FAKE_WEATHER)
    r = weather_client.get("/api/weather", headers=weather_headers)
    assert r.status_code == 200


def test_get_weather_no_params_with_farm(weather_client, weather_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import insights_service as ins
    fake_farm = {
        "_id": ObjectId(), "location": {"lat": 30.0, "lng": 31.0},
        "fields": [], "owner_id": ObjectId(user_id),
    }
    monkeypatch.setattr(fm, "get_farms_by_owner", lambda uid: [fake_farm])
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: FAKE_WEATHER)
    r = weather_client.get("/api/weather", headers=weather_headers)
    assert r.status_code == 200


def test_get_weather_no_farm_location_uses_field(weather_client, weather_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import insights_service as ins
    fake_farm = {
        "_id": ObjectId(), "location": {},
        "fields": [{"location": {"lat": 25.0, "lng": 55.0}}],
        "owner_id": ObjectId(user_id),
    }
    monkeypatch.setattr(fm, "get_farms_by_owner", lambda uid: [fake_farm])
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: FAKE_WEATHER)
    r = weather_client.get("/api/weather", headers=weather_headers)
    assert r.status_code == 200


def test_get_weather_by_farm_id(weather_client, weather_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import insights_service as ins
    farm_id = str(ObjectId())
    farm = {
        "_id": ObjectId(farm_id), "location": {"lat": 30.0, "lng": 31.0},
        "fields": [], "owner_id": ObjectId(user_id),
    }
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: farm)
    monkeypatch.setattr(fm, "update_farm", lambda fid, data: None)
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: FAKE_WEATHER)
    r = weather_client.get(f"/api/weather?farm_id={farm_id}", headers=weather_headers)
    assert r.status_code == 200


def test_get_weather_invalid_farm_id(weather_client, weather_headers):
    r = weather_client.get("/api/weather?farm_id=bad-id", headers=weather_headers)
    assert r.status_code == 400


def test_get_weather_farm_not_found(weather_client, weather_headers, monkeypatch):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: None)
    r = weather_client.get(f"/api/weather?farm_id={farm_id}", headers=weather_headers)
    assert r.status_code == 404


def test_get_weather_farm_wrong_owner(weather_client, weather_headers, monkeypatch):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    farm = {"_id": ObjectId(farm_id), "owner_id": ObjectId()}  # different owner
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: farm)
    r = weather_client.get(f"/api/weather?farm_id={farm_id}", headers=weather_headers)
    assert r.status_code == 404


def test_get_weather_by_farm_and_field(weather_client, weather_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import insights_service as ins
    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    farm = {
        "_id": ObjectId(farm_id),
        "owner_id": ObjectId(user_id),
        "location": {"lat": 30.0, "lng": 31.0},
        "fields": [{"field_id": ObjectId(field_id), "location": {"lat": 30.5, "lng": 31.5}}],
    }
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: farm)
    monkeypatch.setattr(fm, "update_field", lambda fid, fiid, data: None)
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: FAKE_WEATHER)
    r = weather_client.get(f"/api/weather?farm_id={farm_id}&field_id={field_id}",
                           headers=weather_headers)
    assert r.status_code == 200


def test_get_weather_field_not_found(weather_client, weather_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    farm = {
        "_id": ObjectId(farm_id),
        "owner_id": ObjectId(user_id),
        "location": {"lat": 30.0, "lng": 31.0},
        "fields": [],
    }
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: farm)
    r = weather_client.get(f"/api/weather?farm_id={farm_id}&field_id={field_id}",
                           headers=weather_headers)
    assert r.status_code == 404


def test_get_weather_invalid_field_id(weather_client, weather_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    farm = {"_id": ObjectId(farm_id), "owner_id": ObjectId(user_id), "fields": []}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: farm)
    r = weather_client.get(f"/api/weather?farm_id={farm_id}&field_id=bad-id",
                           headers=weather_headers)
    assert r.status_code == 400


def test_get_weather_farm_no_location(weather_client, weather_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import insights_service as ins
    farm_id = str(ObjectId())
    farm = {"_id": ObjectId(farm_id), "owner_id": ObjectId(user_id), "location": {}, "fields": []}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: farm)
    monkeypatch.setattr(fm, "update_farm", lambda fid, data: None)
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: FAKE_WEATHER)
    r = weather_client.get(f"/api/weather?farm_id={farm_id}", headers=weather_headers)
    assert r.status_code == 200


def test_get_weather_unauthenticated(weather_client):
    r = weather_client.get("/api/weather?lat=30.0&lng=31.0")
    assert r.status_code == 401


# ═══════════════════════════════════════════════════════════════════════════════
# Farm controller tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def farm_client(client_for, monkeypatch, current_user):
    from app.controllers.farm_controller import farm_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(farm_bp)


@pytest.fixture
def farm_headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def _fake_farm(user_id):
    return {
        "_id": ObjectId(),
        "owner_id": ObjectId(user_id),
        "name": "Test Farm",
        "location": {"lat": 30.0, "lng": 31.0},
        "area_hectares": 5,
        "crop_type": "wheat",
        "fields": [],
        "created_at": datetime.now(timezone.utc),
    }


def test_list_farms_empty(farm_client, farm_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import cache
    monkeypatch.setattr(cache, "get", lambda key: None)
    monkeypatch.setattr(cache, "set", lambda key, val, ttl=None: None)
    monkeypatch.setattr(fm, "get_farms_by_owner", lambda uid: [])
    monkeypatch.setattr(fm, "serialize", lambda f: {"id": str(f["_id"])})
    r = farm_client.get("/api/farms", headers=farm_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["farms"] == []


def test_list_farms_cached(farm_client, farm_headers, monkeypatch, user_id):
    from app.services import cache
    cached_data = [{"id": "fake123", "name": "Cached Farm"}]
    monkeypatch.setattr(cache, "get", lambda key: cached_data)
    r = farm_client.get("/api/farms", headers=farm_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["farms"] == cached_data


def test_list_farms_with_data(farm_client, farm_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import cache
    fake = _fake_farm(user_id)
    monkeypatch.setattr(cache, "get", lambda key: None)
    monkeypatch.setattr(cache, "set", lambda key, val, ttl=None: None)
    monkeypatch.setattr(fm, "get_farms_by_owner", lambda uid: [fake])
    monkeypatch.setattr(fm, "serialize", lambda f: {"id": str(f["_id"]), "name": f["name"]})
    r = farm_client.get("/api/farms", headers=farm_headers)
    assert r.status_code == 200
    assert len(r.get_json()["data"]["farms"]) == 1


def test_get_farm_by_id_success(farm_client, farm_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    fake = _fake_farm(user_id)
    farm_id = str(fake["_id"])
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake)
    monkeypatch.setattr(fm, "serialize", lambda f: {"id": str(f["_id"]), "name": f["name"]})
    r = farm_client.get(f"/api/farms/{farm_id}", headers=farm_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["farm"]["name"] == "Test Farm"


def test_get_farm_invalid_id(farm_client, farm_headers):
    r = farm_client.get("/api/farms/bad-id", headers=farm_headers)
    assert r.status_code == 400


def test_get_farm_not_found(farm_client, farm_headers, monkeypatch):
    from app.models import farm_model as fm
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: None)
    r = farm_client.get(f"/api/farms/{ObjectId()}", headers=farm_headers)
    assert r.status_code == 404


def test_get_farm_wrong_owner(farm_client, farm_headers, monkeypatch):
    from app.models import farm_model as fm
    farm = {"_id": ObjectId(), "owner_id": ObjectId(), "name": "Other Farm"}
    farm_id = str(farm["_id"])
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: farm)
    r = farm_client.get(f"/api/farms/{farm_id}", headers=farm_headers)
    assert r.status_code == 403


def test_create_farm_success(farm_client, farm_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.models import user_model as um
    from app.models import audit_model as am
    from app.services import cache
    fake = _fake_farm(user_id)
    monkeypatch.setattr(fm, "create_farm", lambda uid, name, loc: fake)
    monkeypatch.setattr(fm, "serialize", lambda f: {"id": str(f["_id"]), "name": f["name"]})
    monkeypatch.setattr(um, "add_farm_ref", lambda uid, fid: None)
    monkeypatch.setattr(am, "log_action", lambda *a, **kw: None)
    monkeypatch.setattr(cache, "delete", lambda key: None)
    r = farm_client.post("/api/farms", json={"name": "My Farm"}, headers=farm_headers)
    assert r.status_code == 201
    assert r.get_json()["data"]["farm"]["name"] == "Test Farm"


def test_create_farm_with_location(farm_client, farm_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.models import user_model as um
    from app.models import audit_model as am
    from app.services import cache, insights_service as ins
    fake = _fake_farm(user_id)
    monkeypatch.setattr(fm, "create_farm", lambda uid, name, loc: fake)
    monkeypatch.setattr(fm, "update_farm", lambda fid, data: None)
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake)
    monkeypatch.setattr(fm, "serialize", lambda f: {"id": str(f["_id"]), "name": f["name"]})
    monkeypatch.setattr(um, "add_farm_ref", lambda uid, fid: None)
    monkeypatch.setattr(am, "log_action", lambda *a, **kw: None)
    monkeypatch.setattr(cache, "delete", lambda key: None)
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: FAKE_WEATHER)
    r = farm_client.post("/api/farms",
                         json={"name": "My Farm", "location": {"lat": 30.0, "lng": 31.0}},
                         headers=farm_headers)
    assert r.status_code == 201


def test_create_farm_missing_name(farm_client, farm_headers):
    r = farm_client.post("/api/farms", json={"location": {"lat": 30.0}}, headers=farm_headers)
    assert r.status_code == 400


def test_update_farm_success(farm_client, farm_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.models import audit_model as am
    from app.services import cache
    fake = _fake_farm(user_id)
    farm_id = str(fake["_id"])
    call_count = [0]
    def get_farm(fid):
        call_count[0] += 1
        return fake
    monkeypatch.setattr(fm, "get_farm_by_id", get_farm)
    monkeypatch.setattr(fm, "update_farm", lambda fid, data: None)
    monkeypatch.setattr(fm, "serialize", lambda f: {"id": str(f["_id"]), "name": f.get("name", "")})
    monkeypatch.setattr(am, "log_action", lambda *a, **kw: None)
    monkeypatch.setattr(cache, "delete", lambda key: None)
    r = farm_client.put(f"/api/farms/{farm_id}",
                        json={"name": "Updated Farm"}, headers=farm_headers)
    assert r.status_code == 200


def test_update_farm_not_found(farm_client, farm_headers, monkeypatch):
    from app.models import farm_model as fm
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: None)
    r = farm_client.put(f"/api/farms/{ObjectId()}",
                        json={"name": "X"}, headers=farm_headers)
    assert r.status_code == 404


def test_update_farm_invalid_id(farm_client, farm_headers):
    r = farm_client.put("/api/farms/bad-id", json={"name": "X"}, headers=farm_headers)
    assert r.status_code == 400


def test_delete_farm_success(farm_client, farm_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.models import user_model as um
    from app.services import cache
    fake = _fake_farm(user_id)
    farm_id = str(fake["_id"])
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake)
    monkeypatch.setattr(fm, "delete_farm", lambda fid: True)
    monkeypatch.setattr(um, "remove_farm_ref", lambda uid, fid: None)
    monkeypatch.setattr(cache, "delete", lambda key: None)
    r = farm_client.delete(f"/api/farms/{farm_id}", headers=farm_headers)
    assert r.status_code == 200


def test_delete_farm_not_found(farm_client, farm_headers, monkeypatch):
    from app.models import farm_model as fm
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: None)
    r = farm_client.delete(f"/api/farms/{ObjectId()}", headers=farm_headers)
    assert r.status_code == 404


def test_delete_farm_invalid_id(farm_client, farm_headers):
    r = farm_client.delete("/api/farms/bad-id", headers=farm_headers)
    assert r.status_code == 400


def test_add_field_success(farm_client, farm_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import cache
    fake = _fake_farm(user_id)
    farm_id = str(fake["_id"])
    field_id = ObjectId()
    new_field = {"field_id": field_id, "name": "Field A", "crop_type": "wheat"}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake)
    monkeypatch.setattr(fm, "add_field", lambda *a, **kw: new_field)
    monkeypatch.setattr(fm, "serialize_field", lambda f: {"id": str(f["field_id"]), "name": f["name"]})
    monkeypatch.setattr(cache, "delete", lambda key: None)
    r = farm_client.post(f"/api/farms/{farm_id}/fields",
                         json={"name": "Field A", "crop_type": "wheat"},
                         headers=farm_headers)
    assert r.status_code == 201


def test_add_field_missing_name(farm_client, farm_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    fake = _fake_farm(user_id)
    farm_id = str(fake["_id"])
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake)
    r = farm_client.post(f"/api/farms/{farm_id}/fields",
                         json={"crop_type": "wheat"},
                         headers=farm_headers)
    assert r.status_code == 400


def test_remove_field_success(farm_client, farm_headers, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import cache
    fake = _fake_farm(user_id)
    farm_id = str(fake["_id"])
    field_id = str(ObjectId())
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake)
    monkeypatch.setattr(fm, "remove_field", lambda fid, fiid: None)
    monkeypatch.setattr(cache, "delete", lambda key: None)
    r = farm_client.delete(f"/api/farms/{farm_id}/fields/{field_id}",
                           headers=farm_headers)
    assert r.status_code == 200


# ═══════════════════════════════════════════════════════════════════════════════
# Scan controller tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def scan_client(client_for, monkeypatch, current_user):
    from app.controllers.scan_controller import scan_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(scan_bp)


@pytest.fixture
def scan_headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def _fake_scan(user_id):
    return {
        "_id": ObjectId(),
        "user_id": ObjectId(user_id),
        "farm_id": None,
        "field_id": None,
        "crop_type": "wheat",
        "status": "completed",
        "scan_type": "image",
        "detection_result": {
            "disease_name": "Leaf Rust",
            "is_healthy": False,
            "confidence": 0.9,
        },
        "created_at": datetime.now(timezone.utc),
    }


def test_get_scan_by_id_success(scan_client, scan_headers, monkeypatch, user_id):
    from app.models import scan_model as sm
    fake = _fake_scan(user_id)
    scan_id = str(fake["_id"])
    monkeypatch.setattr(sm, "get_scan_by_id", lambda sid: fake)
    monkeypatch.setattr(sm, "serialize", lambda s: {"id": str(s["_id"])})
    r = scan_client.get(f"/api/scans/{scan_id}", headers=scan_headers)
    assert r.status_code == 200


def test_get_scan_not_found(scan_client, scan_headers, monkeypatch):
    from app.models import scan_model as sm
    monkeypatch.setattr(sm, "get_scan_by_id", lambda sid: None)
    r = scan_client.get(f"/api/scans/{ObjectId()}", headers=scan_headers)
    assert r.status_code == 404


def test_get_scan_invalid_id(scan_client, scan_headers):
    r = scan_client.get("/api/scans/bad-id", headers=scan_headers)
    assert r.status_code == 400


def test_get_scan_wrong_user(scan_client, scan_headers, monkeypatch, user_id):
    from app.models import scan_model as sm
    fake = _fake_scan(user_id)
    fake["user_id"] = ObjectId()  # different owner
    scan_id = str(fake["_id"])
    monkeypatch.setattr(sm, "get_scan_by_id", lambda sid: fake)
    r = scan_client.get(f"/api/scans/{scan_id}", headers=scan_headers)
    assert r.status_code == 403


def test_list_scans_paid_plan(scan_client, scan_headers, monkeypatch, user_id, current_user):
    from app.models import scan_model as sm
    from app.services import subscription_service as ss
    current_user["plan"] = "premium"
    fake = _fake_scan(user_id)
    monkeypatch.setattr(ss, "has_feature", lambda user, feat: True)
    monkeypatch.setattr(sm, "get_scans_filtered", lambda uid, **kw: [fake])
    monkeypatch.setattr(sm, "serialize", lambda s: {"id": str(s["_id"])})
    r = scan_client.get("/api/scans", headers=scan_headers)
    assert r.status_code == 200
    data = r.get_json()["data"]
    assert data["history_limited"] is False


def test_list_scans_free_plan(scan_client, scan_headers, monkeypatch, user_id, current_user):
    from app.services import subscription_service as ss
    from app.models import db as db_module
    current_user["plan"] = "free"
    monkeypatch.setattr(ss, "has_feature", lambda user, feat: False)
    mock_col = MagicMock()
    mock_col.return_value.find.return_value.sort.return_value.limit.return_value = []
    monkeypatch.setattr(db_module, "scans_col", mock_col)
    from app.models import scan_model as sm
    monkeypatch.setattr(sm, "serialize", lambda s: {"id": str(s["_id"])})
    r = scan_client.get("/api/scans", headers=scan_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["history_limited"] is True


def test_receive_detection_result(scan_client, monkeypatch):
    from app.models import scan_model as sm
    from app.observers import event_publisher as ep
    scan_id = str(ObjectId())
    fake = {"_id": ObjectId(scan_id), "user_id": ObjectId()}
    monkeypatch.setattr(sm, "get_scan_by_id", lambda sid: fake)
    monkeypatch.setattr(sm, "update_detection_result", lambda sid, data: None)
    monkeypatch.setattr(ep, "scan_completed", lambda *a, **kw: None)
    monkeypatch.setattr(ep, "disease_detected", lambda *a, **kw: None)
    r = scan_client.post(f"/api/scans/{scan_id}/result",
                         json={"is_healthy": False, "disease": "Blight", "severity": "high"})
    assert r.status_code == 200


def test_receive_detection_result_invalid_id(scan_client):
    r = scan_client.post("/api/scans/bad-id/result", json={})
    assert r.status_code == 400


def test_receive_detection_result_not_found(scan_client, monkeypatch):
    from app.models import scan_model as sm
    monkeypatch.setattr(sm, "get_scan_by_id", lambda sid: None)
    r = scan_client.post(f"/api/scans/{ObjectId()}/result", json={})
    assert r.status_code == 404


def test_receive_detection_result_risk_high(scan_client, monkeypatch):
    from app.models import scan_model as sm
    from app.observers import event_publisher as ep
    scan_id = str(ObjectId())
    fake = {"_id": ObjectId(scan_id), "user_id": ObjectId()}
    monkeypatch.setattr(sm, "get_scan_by_id", lambda sid: fake)
    monkeypatch.setattr(sm, "update_detection_result", lambda sid, data: None)
    monkeypatch.setattr(ep, "scan_completed", lambda *a, **kw: None)
    monkeypatch.setattr(ep, "risk_high", lambda *a, **kw: None)
    r = scan_client.post(f"/api/scans/{scan_id}/result",
                         json={"is_healthy": True, "risk_level": "high"})
    assert r.status_code == 200


def test_receive_detection_result_healthy(scan_client, monkeypatch):
    from app.models import scan_model as sm
    from app.observers import event_publisher as ep
    scan_id = str(ObjectId())
    fake = {"_id": ObjectId(scan_id), "user_id": ObjectId()}
    monkeypatch.setattr(sm, "get_scan_by_id", lambda sid: fake)
    monkeypatch.setattr(sm, "update_detection_result", lambda sid, data: None)
    monkeypatch.setattr(ep, "scan_completed", lambda *a, **kw: None)
    r = scan_client.post(f"/api/scans/{scan_id}/result",
                         json={"is_healthy": True, "risk_level": "low"})
    assert r.status_code == 200
