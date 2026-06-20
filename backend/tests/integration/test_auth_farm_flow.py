"""
Integration tests — Auth → Farm → Field flow
Simulates the complete onboarding journey: register, verify OTP,
create a farm, add a field, and retrieve the farm list.
Each test builds on the previous state to mimic a real user session.
"""
import pytest
from bson import ObjectId


@pytest.fixture
def flow_client(client_for, monkeypatch, current_user):
    from app.controllers.auth_controller import auth_bp
    from app.controllers.farm_controller import farm_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(auth_bp, farm_bp)


# ── 1. OTP send ───────────────────────────────────────────────────────────────

def test_step1_send_otp(flow_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "send_otp",
                        lambda phone: {"status": "pending"})
    monkeypatch.setattr(auth_controller.auth_service, "check_otp_rate_limit",
                        lambda phone: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    monkeypatch.setattr(auth_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = flow_client.post("/api/auth/send-otp", json={"phone": "+201000000001"})
    assert r.status_code == 200


# ── 2. OTP verify → JWT issued ────────────────────────────────────────────────

def test_step2_verify_otp_returns_token(flow_client, monkeypatch, current_user):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp",
                        lambda phone, code: True)
    monkeypatch.setattr(auth_controller.auth_service, "check_verify_rate_limit",
                        lambda phone: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone",
                        lambda p: current_user)
    monkeypatch.setattr(auth_controller.auth_service, "generate_token",
                        lambda uid: "integration.test.token")
    monkeypatch.setattr(auth_controller.user_model, "serialize",
                        lambda u: {**u, "_id": str(u["_id"])})
    monkeypatch.setattr(auth_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = flow_client.post("/api/auth/verify-otp",
                         json={"phone": "+201000000001", "code": "123456"})
    assert r.status_code == 200
    body = r.get_json()
    assert body is not None


# ── 3. Profile accessible after login ─────────────────────────────────────────

def test_step3_profile_accessible(flow_client, auth_headers, monkeypatch, current_user):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_id",
                        lambda _id: current_user)
    r = flow_client.get("/api/auth/me", headers=auth_headers)
    assert r.status_code == 200


# ── 4. Create farm ────────────────────────────────────────────────────────────

def test_step4_create_farm(flow_client, auth_headers, monkeypatch, current_user):
    from app.controllers import farm_controller
    farm_id = ObjectId()
    farm = {
        "_id": farm_id,
        "owner_id": current_user["_id"],
        "name": "Nile Delta Farm",
        "location": {"lat": 30.5, "lng": 31.2},
        "fields": [],
    }
    monkeypatch.setattr(farm_controller.farm_model, "create_farm",
                        lambda uid, name, location=None: farm)
    monkeypatch.setattr(farm_controller.farm_model, "get_farm_by_id", lambda fid: farm)
    monkeypatch.setattr(farm_controller.farm_model, "update_farm", lambda fid, data: True)
    monkeypatch.setattr(farm_controller.farm_model, "serialize",
                        lambda f: {**f, "_id": str(f["_id"]), "owner_id": str(f["owner_id"])})
    monkeypatch.setattr(farm_controller.user_model, "add_farm_ref", lambda uid, fid: None)
    monkeypatch.setattr(farm_controller.insights_service, "build_weather",
                        lambda loc: {"temp": 25})
    monkeypatch.setattr(farm_controller.cache, "delete", lambda key: None)
    monkeypatch.setattr(farm_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = flow_client.post("/api/farms",
                         json={"name": "Nile Delta Farm",
                               "location": {"lat": 30.5, "lng": 31.2}},
                         headers=auth_headers)
    assert r.status_code in (200, 201)


# ── 5. List farms shows new farm ──────────────────────────────────────────────

def test_step5_list_farms(flow_client, auth_headers, monkeypatch, current_user):
    from app.controllers import farm_controller
    farm = {"_id": ObjectId(), "owner_id": current_user["_id"],
            "name": "Nile Delta Farm", "fields": []}
    monkeypatch.setattr(farm_controller.farm_model, "get_farms_by_owner",
                        lambda uid: [farm])
    monkeypatch.setattr(farm_controller.farm_model, "serialize",
                        lambda f: {**f, "_id": str(f["_id"]), "owner_id": str(f["owner_id"])})
    r = flow_client.get("/api/farms", headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert len(body["data"]["farms"]) == 1


# ── 6. Add field to farm ──────────────────────────────────────────────────────

def test_step6_add_field(flow_client, auth_headers, monkeypatch, current_user):
    from app.controllers import farm_controller
    farm_id = ObjectId()
    farm = {"_id": farm_id, "owner_id": current_user["_id"],
            "name": "Nile Delta Farm", "fields": []}
    field = {"_id": ObjectId(), "name": "Block A", "crop_type": "tomato", "area_ha": 2.5}
    monkeypatch.setattr(farm_controller.farm_model, "get_farm_by_id", lambda fid: farm)
    monkeypatch.setattr(farm_controller.farm_model, "add_field",
                        lambda *a, **kw: field)
    monkeypatch.setattr(farm_controller.farm_model, "serialize_field",
                        lambda f: {**f, "_id": str(f["_id"]), "field_id": str(f["_id"])})
    monkeypatch.setattr(farm_controller.cache, "delete", lambda key: None)
    r = flow_client.post(f"/api/farms/{farm_id}/fields",
                         json={"name": "Block A", "crop_type": "tomato", "area_ha": 2.5},
                         headers=auth_headers)
    assert r.status_code in (200, 201)


# ── 7. Get farm detail includes field ─────────────────────────────────────────

def test_step7_farm_detail_with_field(flow_client, auth_headers, monkeypatch, current_user):
    from app.controllers import farm_controller
    farm_id = ObjectId()
    field = {"_id": ObjectId(), "name": "Block A", "crop_type": "tomato"}
    farm = {"_id": farm_id, "owner_id": current_user["_id"],
            "name": "Nile Delta Farm", "fields": [field]}
    monkeypatch.setattr(farm_controller.farm_model, "get_farm_by_id", lambda fid: farm)
    def _serialize_farm(f):
        fields = [{**fld, "_id": str(fld["_id"])} for fld in f.get("fields", [])]
        return {**f, "_id": str(f["_id"]), "owner_id": str(f["owner_id"]), "fields": fields}
    monkeypatch.setattr(farm_controller.farm_model, "serialize", _serialize_farm)
    r = flow_client.get(f"/api/farms/{farm_id}", headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert len(body["data"]["farm"]["fields"]) == 1


# ── 8. Update farm name ───────────────────────────────────────────────────────

def test_step8_update_farm(flow_client, auth_headers, monkeypatch, current_user):
    from app.controllers import farm_controller
    farm_id = ObjectId()
    farm = {"_id": farm_id, "owner_id": current_user["_id"],
            "name": "Old Name", "fields": []}
    updated = {**farm, "name": "New Name"}
    monkeypatch.setattr(farm_controller.farm_model, "get_farm_by_id",
                        lambda fid: updated)
    monkeypatch.setattr(farm_controller.farm_model, "update_farm",
                        lambda fid, data: True)
    monkeypatch.setattr(farm_controller.farm_model, "serialize",
                        lambda f: {**f, "_id": str(f["_id"]),
                                   "owner_id": str(f["owner_id"])})
    monkeypatch.setattr(farm_controller.cache, "delete", lambda key: None)
    monkeypatch.setattr(farm_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = flow_client.put(f"/api/farms/{farm_id}", json={"name": "New Name"},
                        headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert body["data"]["farm"]["name"] == "New Name"
