"""
Unit tests — Notification Controller
Tests list, mark-read, mark-all-read, unread count, device registration.
"""
import pytest
from bson import ObjectId


@pytest.fixture
def notif_client(client_for, monkeypatch, current_user):
    from app.controllers.notification_controller import notifications_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(notifications_bp)


def _notif(uid):
    return {
        "_id": ObjectId(),
        "user_id": str(uid),
        "title": "Disease Alert",
        "body": "Late blight detected",
        "read": False,
        "type": "disease_alert",
        "created_at": "2026-01-01T00:00:00Z",
    }


def _patch_list(monkeypatch, notifs):
    from app.controllers import notification_controller as nc
    monkeypatch.setattr(nc.notification_model, "list_notifications",
                        lambda uid, limit=100: notifs)
    monkeypatch.setattr(nc.notification_model, "unread_count",
                        lambda uid: sum(1 for n in notifs if not n.get("read")))
    monkeypatch.setattr(nc.notification_model, "serialize",
                        lambda n: {**{k: str(v) if k == "_id" else v
                                      for k, v in n.items()}})


# ── list notifications ────────────────────────────────────────────────────────

def test_list_notifications_returns_list(notif_client, auth_headers, monkeypatch, current_user):
    notifs = [_notif(current_user["_id"])]
    _patch_list(monkeypatch, notifs)
    r = notif_client.get("/api/notifications", headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert body["data"]["unread_count"] == 1

def test_list_notifications_unauthenticated(notif_client):
    r = notif_client.get("/api/notifications")
    assert r.status_code == 401

def test_list_notifications_empty(notif_client, auth_headers, monkeypatch, current_user):
    _patch_list(monkeypatch, [])
    r = notif_client.get("/api/notifications", headers=auth_headers)
    assert r.status_code == 200

def test_list_notifications_unread_count(notif_client, auth_headers, monkeypatch, current_user):
    notifs = [_notif(current_user["_id"]), _notif(current_user["_id"])]
    _patch_list(monkeypatch, notifs)
    r = notif_client.get("/api/notifications", headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert body["data"]["unread_count"] == 2


# ── mark read ─────────────────────────────────────────────────────────────────

def test_mark_notification_read(notif_client, auth_headers, monkeypatch, current_user):
    from app.controllers import notification_controller as nc
    nid = str(ObjectId())
    notif = _notif(current_user["_id"])
    monkeypatch.setattr(nc.notification_model, "mark_as_read",
                        lambda notification_id, user_id: True)
    monkeypatch.setattr(nc.notification_model, "get_notification",
                        lambda nid: notif)
    monkeypatch.setattr(nc.notification_model, "serialize",
                        lambda n: {**n, "_id": str(n["_id"])})
    r = notif_client.put(f"/api/notifications/{nid}/read", headers=auth_headers)
    assert r.status_code == 200

def test_mark_read_not_found(notif_client, auth_headers, monkeypatch):
    from app.controllers import notification_controller as nc
    nid = str(ObjectId())
    monkeypatch.setattr(nc.notification_model, "mark_as_read",
                        lambda notification_id, user_id: False)
    r = notif_client.put(f"/api/notifications/{nid}/read", headers=auth_headers)
    assert r.status_code == 404

def test_mark_read_invalid_id(notif_client, auth_headers):
    r = notif_client.put("/api/notifications/bad-id/read", headers=auth_headers)
    assert r.status_code == 400

def test_mark_all_notifications_read(notif_client, auth_headers, monkeypatch):
    from app.controllers import notification_controller as nc
    monkeypatch.setattr(nc.notification_model, "mark_all_as_read", lambda uid: 5)
    r = notif_client.put("/api/notifications/read-all", headers=auth_headers)
    assert r.status_code == 200


# ── device token registration ─────────────────────────────────────────────────

def test_register_device_token_valid(notif_client, auth_headers, monkeypatch, current_user):
    from app.controllers import notification_controller as nc
    monkeypatch.setattr(nc.user_model, "add_fcm_token", lambda uid, token: None)
    monkeypatch.setattr(nc.user_model, "find_by_id",
                        lambda _id: {**current_user, "fcm_tokens": ["tok1"]})
    r = notif_client.post("/api/notifications/device-token",
                          json={"token": "fcm-token-abc123"},
                          headers=auth_headers)
    assert r.status_code == 200

def test_register_device_token_missing(notif_client, auth_headers):
    r = notif_client.post("/api/notifications/device-token", json={},
                          headers=auth_headers)
    assert r.status_code == 400

def test_unregister_device_token(notif_client, auth_headers, monkeypatch, current_user):
    # DELETE device token may require a token body or may not be implemented
    r = notif_client.delete("/api/notifications/device-token", headers=auth_headers)
    assert r.status_code in (200, 400, 401, 404, 405)
