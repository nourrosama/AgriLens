"""
End-to-End tests — Complete Farmer Journey
Simulates a real farmer's full session:
register → login → add farm → scan image → view results → read notification → delete account.
Each test is independent but mirrors a sequential real-world workflow.
"""
import pytest
from bson import ObjectId
from io import BytesIO
from unittest.mock import MagicMock
import app.models.db as db_mod

JPEG = b'\xff\xd8\xff\xe0' + b'\x00' * 200


@pytest.fixture
def e2e_client(client_for, monkeypatch, current_user):
    from app.controllers.auth_controller import auth_bp
    from app.controllers.farm_controller import farm_bp
    from app.controllers.scan_controller import scan_bp
    from app.controllers.notification_controller import notifications_bp
    from app.controllers.dashboard_controller import dashboard_bp
    from app.middleware import auth_middleware
    current_user["plan"] = "premium"
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(auth_bp, farm_bp, scan_bp, notifications_bp, dashboard_bp)


# ── Journey 1: New farmer onboards successfully ───────────────────────────────

def test_journey1_full_onboarding(e2e_client, auth_headers, monkeypatch, current_user):
    from app.controllers import auth_controller, farm_controller

    # Step A: Send OTP
    monkeypatch.setattr(auth_controller.auth_service, "send_otp",
                        lambda p: {"status": "pending"})
    monkeypatch.setattr(auth_controller.auth_service, "check_otp_rate_limit",
                        lambda p: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    monkeypatch.setattr(auth_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = e2e_client.post("/api/auth/send-otp", json={"phone": "+201000000099"})
    assert r.status_code == 200

    # Step B: Verify OTP → get token
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp",
                        lambda p, c: True)
    monkeypatch.setattr(auth_controller.auth_service, "check_verify_rate_limit",
                        lambda p: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone",
                        lambda p: current_user)
    monkeypatch.setattr(auth_controller.auth_service, "generate_token",
                        lambda uid: "e2e.test.jwt")
    monkeypatch.setattr(auth_controller.user_model, "serialize",
                        lambda u: {**u, "_id": str(u["_id"])})
    r = e2e_client.post("/api/auth/verify-otp",
                        json={"phone": "+201000000099", "code": "123456"})
    assert r.status_code == 200

    # Step C: Create farm (no location → no weather call)
    farm = {"_id": ObjectId(), "owner_id": current_user["_id"], "name": "E2E Farm",
            "fields": []}
    monkeypatch.setattr(farm_controller.farm_model, "create_farm",
                        lambda uid, name, location=None: farm)
    monkeypatch.setattr(farm_controller.farm_model, "get_farm_by_id", lambda fid: farm)
    monkeypatch.setattr(farm_controller.farm_model, "update_farm", lambda fid, data: True)
    monkeypatch.setattr(farm_controller.farm_model, "serialize",
                        lambda f: {**f, "_id": str(f["_id"]), "owner_id": str(f["owner_id"])})
    monkeypatch.setattr(farm_controller.user_model, "add_farm_ref", lambda uid, fid: None)
    monkeypatch.setattr(farm_controller.cache, "delete", lambda key: None)
    monkeypatch.setattr(farm_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = e2e_client.post("/api/farms", json={"name": "E2E Farm"}, headers=auth_headers)
    assert r.status_code in (200, 201)


# ── Journey 2: Farmer scans a diseased leaf ───────────────────────────────────

def test_journey2_scan_diseased_leaf(e2e_client, auth_headers, monkeypatch, current_user):
    from app.controllers import scan_controller
    scan = {
        "_id": ObjectId(),
        "user_id": current_user["_id"],
        "media_url": "/uploads/leaf.jpg",
        "image_url": "/uploads/leaf.jpg",
        "crop_type": "tomato",
        "status": "completed",
        "detection_result": {
            "disease": "Tomato Late Blight",
            "confidence": 0.94,
            "risk_level": "high",
            "is_healthy": False,
            "recommendations": ["Apply fungicide", "Remove infected leaves"],
        },
    }
    monkeypatch.setattr(scan_controller, "can_scan", lambda user: (True, ""))
    monkeypatch.setattr(scan_controller.storage_service, "upload_image",
                        lambda f: "/uploads/leaf.jpg")
    monkeypatch.setattr(scan_controller.storage_service, "get_storage_backend",
                        lambda: "local")
    monkeypatch.setattr(scan_controller.storage_service, "resolve_local_path",
                        lambda url: None)
    monkeypatch.setattr(scan_controller.scan_model, "create_scan", lambda **kw: scan)
    monkeypatch.setattr(scan_controller.scan_model, "update_status", lambda *a: True)
    monkeypatch.setattr(scan_controller.scan_model, "update_scan", lambda *a, **kw: True)
    monkeypatch.setattr(scan_controller.scan_model, "get_scan_by_id", lambda _id: scan)
    monkeypatch.setattr(scan_controller.detection_proxy_service, "detect",
                        lambda *a: scan["detection_result"])
    monkeypatch.setattr(scan_controller.audit_model, "log_action", lambda *a, **kw: None)
    for ev in ("scan_created", "scan_completed", "disease_detected", "risk_high"):
        monkeypatch.setattr(scan_controller.event_publisher, ev, lambda *a, **kw: None)

    r = e2e_client.post("/api/scans",
                        data={"image": (BytesIO(JPEG), "leaf.jpg"), "crop_type": "tomato"},
                        content_type="multipart/form-data",
                        headers=auth_headers)
    assert r.status_code == 201
    body = r.get_json()
    result = body["data"]["scan"]["detection_result"]
    assert result["is_healthy"] is False
    assert result["risk_level"] == "high"


# ── Journey 3: Farmer views healthy scan ─────────────────────────────────────

def test_journey3_scan_healthy_leaf(e2e_client, auth_headers, monkeypatch, current_user):
    from app.controllers import scan_controller
    scan = {
        "_id": ObjectId(),
        "user_id": current_user["_id"],
        "media_url": "/uploads/healthy.jpg",
        "image_url": "/uploads/healthy.jpg",
        "crop_type": "tomato",
        "status": "completed",
        "detection_result": {
            "disease": None,
            "confidence": 0.97,
            "risk_level": "low",
            "is_healthy": True,
        },
    }
    monkeypatch.setattr(scan_controller, "can_scan", lambda user: (True, ""))
    monkeypatch.setattr(scan_controller.storage_service, "upload_image",
                        lambda f: "/uploads/healthy.jpg")
    monkeypatch.setattr(scan_controller.storage_service, "get_storage_backend",
                        lambda: "local")
    monkeypatch.setattr(scan_controller.storage_service, "resolve_local_path",
                        lambda url: None)
    monkeypatch.setattr(scan_controller.scan_model, "create_scan", lambda **kw: scan)
    monkeypatch.setattr(scan_controller.scan_model, "update_status", lambda *a: True)
    monkeypatch.setattr(scan_controller.scan_model, "update_scan", lambda *a, **kw: True)
    monkeypatch.setattr(scan_controller.scan_model, "get_scan_by_id", lambda _id: scan)
    monkeypatch.setattr(scan_controller.detection_proxy_service, "detect",
                        lambda *a: scan["detection_result"])
    monkeypatch.setattr(scan_controller.audit_model, "log_action", lambda *a, **kw: None)
    for ev in ("scan_created", "scan_completed", "disease_detected", "risk_high"):
        monkeypatch.setattr(scan_controller.event_publisher, ev, lambda *a, **kw: None)

    r = e2e_client.post("/api/scans",
                        data={"image": (BytesIO(JPEG), "leaf.jpg"), "crop_type": "tomato"},
                        content_type="multipart/form-data",
                        headers=auth_headers)
    assert r.status_code == 201
    assert r.get_json()["data"]["scan"]["detection_result"]["is_healthy"] is True


# ── Journey 4: Farmer reads notification after disease detected ───────────────

def test_journey4_read_disease_notification(e2e_client, auth_headers, monkeypatch,
                                             current_user):
    from app.controllers import notification_controller as nc
    nid = ObjectId()
    notif = {"_id": nid, "user_id": str(current_user["_id"]),
             "title": "Disease Detected", "body": "Late blight on tomato",
             "read": False, "type": "disease_alert"}

    monkeypatch.setattr(nc.notification_model, "list_notifications",
                        lambda uid, limit=100: [notif])
    monkeypatch.setattr(nc.notification_model, "unread_count", lambda uid: 1)
    monkeypatch.setattr(nc.notification_model, "serialize",
                        lambda n: {**n, "_id": str(n["_id"])})
    monkeypatch.setattr(nc.notification_model, "mark_as_read",
                        lambda notification_id, user_id: True)
    monkeypatch.setattr(nc.notification_model, "get_notification",
                        lambda nid: notif)

    # List — 1 unread
    r = e2e_client.get("/api/notifications", headers=auth_headers)
    assert r.status_code == 200
    assert len(r.get_json()["data"]["notifications"]) == 1

    # Mark read
    r = e2e_client.put(f"/api/notifications/{nid}/read", headers=auth_headers)
    assert r.status_code == 200


# ── Journey 5: Arabic-language farmer ────────────────────────────────────────

def test_journey5_arabic_language_user(e2e_client, auth_headers, monkeypatch, current_user):
    from app.controllers import auth_controller
    current_user["language"] = "ar"
    monkeypatch.setattr(auth_controller.user_model, "find_by_id",
                        lambda _id: current_user)
    r = e2e_client.get("/api/auth/me", headers=auth_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["user"]["language"] == "ar"


# ── Journey 6: Farmer deletes account ────────────────────────────────────────

def test_journey6_delete_account(e2e_client, auth_headers, monkeypatch, current_user):
    from app.controllers import auth_controller

    fake_col = MagicMock()
    fake_col.return_value.delete_many.return_value = MagicMock(deleted_count=1)
    fake_col.return_value.delete_one.return_value = MagicMock(deleted_count=1)
    fake_col.return_value.find.return_value = []

    for name in ("scans_col", "farms_col", "notifications_col",
                 "chat_sessions_col", "chat_messages_col",
                 "forum_posts_col", "forum_comments_col",
                 "forum_questions_col", "forum_answers_col",
                 "users_col"):
        monkeypatch.setattr(db_mod, name, fake_col)

    monkeypatch.setattr(auth_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = e2e_client.delete("/api/auth/account", headers=auth_headers)
    assert r.status_code in (200, 204)
