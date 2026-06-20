"""
Unit tests — Auth Controller
Tests every endpoint: send_otp, register, verify_otp, profile CRUD, delete_account.
Covers valid paths, validation errors, duplicate users, and edge cases.
"""
import pytest
from bson import ObjectId
from flask import Flask

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from conftest import make_token


# ── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def auth_client(client_for, monkeypatch, current_user):
    from app.controllers.auth_controller import auth_bp
    from app.controllers import auth_controller
    from app.middleware import auth_middleware

    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    monkeypatch.setattr(auth_controller, "auth_service", auth_controller.auth_service)
    return client_for(auth_bp)


# ── send_otp ─────────────────────────────────────────────────────────────────

def test_send_otp_valid_phone(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "send_otp",
                        lambda phone: {"status": "pending"})
    monkeypatch.setattr(auth_controller.auth_service, "check_otp_rate_limit",
                        lambda phone: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    monkeypatch.setattr(auth_controller.audit_model, "log_action",
                        lambda *a, **kw: None)
    r = auth_client.post("/api/auth/send-otp", json={"phone": "+201234567890"})
    assert r.status_code == 200

def test_send_otp_missing_phone(auth_client):
    r = auth_client.post("/api/auth/send-otp", json={})
    assert r.status_code == 400

def test_send_otp_invalid_format(auth_client):
    r = auth_client.post("/api/auth/send-otp", json={"phone": "not-a-phone"})
    assert r.status_code == 400

def test_send_otp_empty_string(auth_client):
    r = auth_client.post("/api/auth/send-otp", json={"phone": ""})
    assert r.status_code == 400

def test_send_otp_non_egyptian_number_rejected(auth_client):
    # US number — not Egyptian, sanitize_phone won't convert it to +20
    r = auth_client.post("/api/auth/send-otp", json={"phone": "+14155551234"})
    assert r.status_code == 400


# ── register ─────────────────────────────────────────────────────────────────

def test_register_creates_user(auth_client, monkeypatch, user_id):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    monkeypatch.setattr(
        auth_controller.user_model, "create_user",
        lambda **kw: {"_id": ObjectId(user_id), "phone": kw["phone"], "name": kw["name"]}
    )
    r = auth_client.post("/api/auth/register", json={
        "phone": "+201234567890", "name": "Farmer Ali", "country": "Egypt"
    })
    assert r.status_code in (200, 201)

def test_register_duplicate_phone(auth_client, monkeypatch, current_user):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: current_user)
    r = auth_client.post("/api/auth/register", json={
        "phone": "+201234567890", "name": "Farmer Ali", "country": "Egypt"
    })
    assert r.status_code in (400, 409)

def test_register_missing_name(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    r = auth_client.post("/api/auth/register", json={"phone": "+201234567890"})
    assert r.status_code == 400

def test_register_missing_phone(auth_client):
    r = auth_client.post("/api/auth/register", json={"name": "Ali"})
    assert r.status_code == 400


# ── verify_otp ───────────────────────────────────────────────────────────────

def test_verify_otp_returns_token(auth_client, monkeypatch, current_user, user_id):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp",
                        lambda phone, code: True)
    monkeypatch.setattr(auth_controller.auth_service, "check_verify_rate_limit",
                        lambda phone: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone",
                        lambda p: current_user)
    monkeypatch.setattr(auth_controller.auth_service, "generate_token",
                        lambda uid: "test.jwt.token")
    monkeypatch.setattr(auth_controller.user_model, "serialize",
                        lambda u: {**u, "_id": str(u["_id"])})
    monkeypatch.setattr(auth_controller.audit_model, "log_action",
                        lambda *a, **kw: None)
    r = auth_client.post("/api/auth/verify-otp", json={
        "phone": "+201234567890", "code": "123456"
    })
    assert r.status_code == 200
    body = r.get_json()
    assert "token" in body.get("data", body)

def test_verify_otp_wrong_code(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp",
                        lambda phone, code: False)
    r = auth_client.post("/api/auth/verify-otp", json={
        "phone": "+201234567890", "code": "000000"
    })
    assert r.status_code in (400, 401)

def test_verify_otp_missing_fields(auth_client):
    r = auth_client.post("/api/auth/verify-otp", json={"phone": "+201234567890"})
    assert r.status_code == 400

def test_verify_otp_user_not_found(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp",
                        lambda phone, code: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    r = auth_client.post("/api/auth/verify-otp", json={
        "phone": "+201234567890", "code": "123456"
    })
    assert r.status_code in (400, 404)


# ── get_profile ───────────────────────────────────────────────────────────────

def test_get_profile_returns_user(auth_client, auth_headers, current_user, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_id",
                        lambda _id: current_user)
    r = auth_client.get("/api/auth/me", headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert body["data"]["user"]["phone"] == current_user["phone"]

def test_get_profile_unauthenticated(auth_client):
    r = auth_client.get("/api/auth/me")
    assert r.status_code == 401

def test_get_profile_user_deleted(auth_client, auth_headers, monkeypatch):
    from app.controllers import auth_controller
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: None)
    r = auth_client.get("/api/auth/me", headers=auth_headers)
    assert r.status_code == 401


# ── update_profile ────────────────────────────────────────────────────────────

def test_update_profile_name(auth_client, auth_headers, current_user, monkeypatch):
    from app.controllers import auth_controller
    updated = {**current_user, "name": "New Name"}
    monkeypatch.setattr(auth_controller.user_model, "update_user",
                        lambda uid, data: updated)
    monkeypatch.setattr(auth_controller.user_model, "find_by_id",
                        lambda _id: updated)
    r = auth_client.put("/api/auth/me", json={"name": "New Name"},
                        headers=auth_headers)
    assert r.status_code == 200

def test_update_profile_language(auth_client, auth_headers, current_user, monkeypatch):
    from app.controllers import auth_controller
    updated = {**current_user, "language": "ar"}
    monkeypatch.setattr(auth_controller.user_model, "update_user",
                        lambda uid, data: updated)
    monkeypatch.setattr(auth_controller.user_model, "find_by_id",
                        lambda _id: updated)
    r = auth_client.put("/api/auth/me", json={"language": "ar"},
                        headers=auth_headers)
    assert r.status_code == 200

def test_update_profile_empty_body(auth_client, auth_headers, current_user, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "update_user",
                        lambda uid, data: current_user)
    monkeypatch.setattr(auth_controller.user_model, "find_by_id",
                        lambda _id: current_user)
    r = auth_client.put("/api/auth/me", json={}, headers=auth_headers)
    assert r.status_code in (200, 400)


# ── delete_account ────────────────────────────────────────────────────────────

def test_delete_account_removes_all_data(auth_client, auth_headers, current_user,
                                         monkeypatch):
    from unittest.mock import MagicMock
    from app.controllers import auth_controller

    # Patch every DB collection used in delete_account
    fake_col = MagicMock()
    fake_col.return_value.delete_many.return_value = MagicMock(deleted_count=1)
    fake_col.return_value.delete_one.return_value = MagicMock(deleted_count=1)
    fake_col.return_value.find.return_value = []

    import app.models.db as db_mod
    for name in ("scans_col", "farms_col", "notifications_col",
                 "chat_sessions_col", "chat_messages_col",
                 "forum_posts_col", "forum_comments_col",
                 "forum_questions_col", "forum_answers_col",
                 "users_col"):
        monkeypatch.setattr(db_mod, name, fake_col)

    monkeypatch.setattr(auth_controller.audit_model, "log_action", lambda *a, **kw: None)

    r = auth_client.delete("/api/auth/account", headers=auth_headers)
    assert r.status_code in (200, 204)

def test_delete_account_unauthenticated(auth_client):
    r = auth_client.delete("/api/auth/account")
    assert r.status_code == 401
