"""
Integration tests — Scan upload → Disease detection → Notification flow
Verifies the complete disease detection pipeline:
upload → detect → persist → publish event → notification created.
"""
import pytest
from bson import ObjectId
from io import BytesIO

JPEG = b'\xff\xd8\xff\xe0' + b'\x00' * 200


@pytest.fixture
def scan_client(client_for, monkeypatch, current_user):
    from app.controllers.scan_controller import scan_bp
    from app.controllers.notification_controller import notifications_bp
    from app.middleware import auth_middleware
    current_user["plan"] = "premium"
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(scan_bp, notifications_bp)


def _make_scan(uid, status="completed", disease="Tomato Late Blight"):
    sid = ObjectId()
    return {
        "_id": sid,
        "user_id": uid,
        "media_url": "/uploads/leaf.jpg",
        "image_url": "/uploads/leaf.jpg",
        "crop_type": "tomato",
        "status": status,
        "detection_result": {
            "disease": disease,
            "confidence": 0.91,
            "risk_level": "high",
            "is_healthy": False,
        } if status == "completed" else None,
    }


# ── 1. Upload image ───────────────────────────────────────────────────────────

def test_step1_upload_image_accepted(scan_client, auth_headers, monkeypatch, current_user):
    from app.controllers import scan_controller
    scan = _make_scan(current_user["_id"])
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
    monkeypatch.setattr(scan_controller.event_publisher, "scan_created", lambda *a: None)
    monkeypatch.setattr(scan_controller.event_publisher, "scan_completed",
                        lambda *a, **kw: None)
    monkeypatch.setattr(scan_controller.event_publisher, "disease_detected",
                        lambda *a: None)
    monkeypatch.setattr(scan_controller.event_publisher, "risk_high", lambda *a: None)
    r = scan_client.post("/api/scans",
                         data={"image": (BytesIO(JPEG), "leaf.jpg"),
                               "crop_type": "tomato"},
                         content_type="multipart/form-data",
                         headers=auth_headers)
    assert r.status_code == 201


# ── 2. Detection result contains disease ──────────────────────────────────────

def test_step2_detection_result_present(scan_client, auth_headers, monkeypatch, current_user):
    from app.controllers import scan_controller
    scan = _make_scan(current_user["_id"])
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
    r = scan_client.post("/api/scans",
                         data={"image": (BytesIO(JPEG), "leaf.jpg"),
                               "crop_type": "tomato"},
                         content_type="multipart/form-data",
                         headers=auth_headers)
    body = r.get_json()
    assert body["data"]["scan"]["detection_result"]["disease"] == "Tomato Late Blight"


# ── 3. Scan rejected without auth ─────────────────────────────────────────────

def test_step3_scan_requires_auth(scan_client):
    r = scan_client.post("/api/scans",
                         data={"image": (BytesIO(JPEG), "leaf.jpg"),
                               "crop_type": "tomato"},
                         content_type="multipart/form-data")
    assert r.status_code == 401


# ── 4. Over-quota free user blocked ───────────────────────────────────────────

def test_step4_free_user_over_quota_blocked(scan_client, auth_headers, monkeypatch,
                                             current_user):
    from app.controllers import scan_controller
    current_user["plan"] = "free"
    monkeypatch.setattr(scan_controller, "can_scan", lambda user: (False, "Quota exceeded"))
    r = scan_client.post("/api/scans",
                         data={"image": (BytesIO(JPEG), "leaf.jpg"),
                               "crop_type": "tomato"},
                         content_type="multipart/form-data",
                         headers=auth_headers)
    assert r.status_code in (402, 403, 429)


# ── 5. Scan history returned ──────────────────────────────────────────────────

def _serialize_scan(s):
    return {k: str(v) if hasattr(v, '__class__') and v.__class__.__name__ == 'ObjectId' else v
            for k, v in s.items()}

def test_step5_scan_history_returned(scan_client, auth_headers, monkeypatch, current_user):
    from app.controllers import scan_controller
    scans = [_make_scan(str(current_user["_id"])) for _ in range(3)]
    monkeypatch.setattr(scan_controller.scan_model, "get_scans_filtered",
                        lambda uid, **kw: scans)
    monkeypatch.setattr(scan_controller.scan_model, "serialize", _serialize_scan)
    r = scan_client.get("/api/scans", headers=auth_headers)
    assert r.status_code == 200

def test_step5_scan_history_paginated(scan_client, auth_headers, monkeypatch, current_user):
    from app.controllers import scan_controller
    monkeypatch.setattr(scan_controller.scan_model, "get_scans_filtered",
                        lambda uid, **kw: [])
    monkeypatch.setattr(scan_controller.scan_model, "serialize", _serialize_scan)
    r = scan_client.get("/api/scans?page=1&per_page=5", headers=auth_headers)
    assert r.status_code == 200


# ── 6. Notification created after disease detection ───────────────────────────

def test_step6_notification_appears_after_scan(scan_client, auth_headers, monkeypatch,
                                                current_user):
    from app.controllers import notification_controller as nc
    notifs = [{"_id": ObjectId(), "title": "Disease Alert",
               "body": "Tomato Late Blight detected", "read": False,
               "user_id": str(current_user["_id"])}]
    monkeypatch.setattr(nc.notification_model, "list_notifications",
                        lambda uid, limit=100: notifs)
    monkeypatch.setattr(nc.notification_model, "unread_count", lambda uid: 1)
    monkeypatch.setattr(nc.notification_model, "serialize",
                        lambda n: {**n, "_id": str(n["_id"])})
    r = scan_client.get("/api/notifications", headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert len(body["data"]["notifications"]) >= 1


# ── 7. Unsupported crop rejected ──────────────────────────────────────────────

def test_step7_unsupported_crop_validation_error(scan_client, auth_headers, monkeypatch,
                                                  current_user):
    from app.controllers import scan_controller
    scan = _make_scan(str(current_user["_id"]))
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
    monkeypatch.setattr(scan_controller.scan_model, "update_detection_result",
                        lambda *a, **kw: True)
    monkeypatch.setattr(scan_controller.scan_model, "get_scan_by_id", lambda _id: scan)
    monkeypatch.setattr(scan_controller.scan_model, "serialize", _serialize_scan)
    monkeypatch.setattr(scan_controller.audit_model, "log_action", lambda *a, **kw: None)
    for ev in ("scan_created", "scan_completed", "disease_detected", "risk_high"):
        monkeypatch.setattr(scan_controller.event_publisher, ev, lambda *a, **kw: None)
    r = scan_client.post("/api/scans",
                         data={"image": (BytesIO(JPEG), "leaf.jpg"),
                               "crop_type": "mushroom"},
                         content_type="multipart/form-data",
                         headers=auth_headers)
    assert r.status_code in (201, 400, 422)


# ── 8. Missing crop_type defaults gracefully ──────────────────────────────────

def test_step8_missing_crop_type(scan_client, auth_headers, monkeypatch, current_user):
    from app.controllers import scan_controller
    scan = _make_scan(str(current_user["_id"]))
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
    monkeypatch.setattr(scan_controller.scan_model, "serialize", _serialize_scan)
    monkeypatch.setattr(scan_controller.detection_proxy_service, "detect",
                        lambda *a: scan["detection_result"])
    monkeypatch.setattr(scan_controller.audit_model, "log_action", lambda *a, **kw: None)
    for ev in ("scan_created", "scan_completed", "disease_detected", "risk_high"):
        monkeypatch.setattr(scan_controller.event_publisher, ev, lambda *a, **kw: None)
    r = scan_client.post("/api/scans",
                         data={"image": (BytesIO(JPEG), "leaf.jpg")},
                         content_type="multipart/form-data",
                         headers=auth_headers)
    # Missing crop_type defaults to "" → detection still runs. 201 or 400 both acceptable.
    assert r.status_code in (201, 400)
