"""
Auth controller — extra endpoint tests.
Covers: send_email_otp, verify_email_otp, link_phone, verify_link_phone,
        link_email, verify_link_email, update_profile (multipart + photo),
        delete_account error path.
"""
import pytest
from bson import ObjectId


@pytest.fixture
def auth_client(client_for, monkeypatch, current_user):
    from app.controllers.auth_controller import auth_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(auth_bp)


@pytest.fixture
def headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


# ── send_email_otp ────────────────────────────────────────────────────────────

def test_send_email_otp_valid(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_otp_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "send_email_otp",
                        lambda e: {"status": "pending", "mock": True, "dev_code": "123456"})
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: None)
    r = auth_client.post("/api/auth/send-email-otp", json={"email": "test@example.com"})
    assert r.status_code == 200
    body = r.get_json()
    assert body["data"]["dev_code"] == "123456"


def test_send_email_otp_missing_email(auth_client):
    r = auth_client.post("/api/auth/send-email-otp", json={})
    assert r.status_code == 400


def test_send_email_otp_invalid_email(auth_client):
    r = auth_client.post("/api/auth/send-email-otp", json={"email": "not-an-email"})
    assert r.status_code == 400


def test_send_email_otp_rate_limited(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_otp_rate_limit", lambda e: False)
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: None)
    r = auth_client.post("/api/auth/send-email-otp", json={"email": "test@example.com"})
    assert r.status_code == 429


def test_send_email_otp_signup_duplicate(auth_client, monkeypatch, current_user):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: current_user)
    r = auth_client.post("/api/auth/send-email-otp",
                         json={"email": "test@example.com", "name": "Ali"})
    assert r.status_code == 409


def test_send_email_otp_delivery_error(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: None)
    monkeypatch.setattr(auth_controller.auth_service, "check_email_otp_rate_limit", lambda e: True)

    class _Err(Exception):
        message = "smtp fail"
        status_code = 502
    monkeypatch.setattr(auth_controller.auth_service, "send_email_otp",
                        lambda e: (_ for _ in ()).throw(_Err()))
    monkeypatch.setattr(auth_controller.auth_service, "OtpDeliveryError", _Err)
    r = auth_client.post("/api/auth/send-email-otp", json={"email": "test@example.com"})
    assert r.status_code == 502


def test_send_email_otp_existing_user_audited(auth_client, monkeypatch, current_user):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_otp_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "send_email_otp",
                        lambda e: {"status": "pending"})
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: current_user)
    monkeypatch.setattr(auth_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = auth_client.post("/api/auth/send-email-otp", json={"email": "test@example.com"})
    assert r.status_code == 200


# ── verify_email_otp ─────────────────────────────────────────────────────────

def test_verify_email_otp_login(auth_client, monkeypatch, current_user, user_id):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_verify_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_email_otp", lambda e, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: current_user)
    monkeypatch.setattr(auth_controller.auth_service, "generate_token", lambda uid: "tok")
    monkeypatch.setattr(auth_controller.user_model, "serialize", lambda u: {**u, "_id": str(u["_id"])})
    monkeypatch.setattr(auth_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = auth_client.post("/api/auth/verify-email-otp",
                         json={"email": "test@example.com", "code": "123456"})
    assert r.status_code == 200
    assert r.get_json()["data"]["token"] == "tok"


def test_verify_email_otp_signup(auth_client, monkeypatch, current_user, user_id):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_verify_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_email_otp", lambda e, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: None)
    monkeypatch.setattr(auth_controller.user_model, "create_user",
                        lambda **kw: {**current_user, "email": "test@example.com"})
    monkeypatch.setattr(auth_controller.auth_service, "generate_token", lambda uid: "tok")
    monkeypatch.setattr(auth_controller.user_model, "serialize",
                        lambda u: {**u, "_id": str(u["_id"])})
    monkeypatch.setattr(auth_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = auth_client.post("/api/auth/verify-email-otp",
                         json={"email": "test@example.com", "code": "123456",
                               "name": "Ali", "country": "Egypt"})
    assert r.status_code == 200
    assert r.get_json()["data"]["is_new_user"] is True


def test_verify_email_otp_missing_code(auth_client):
    r = auth_client.post("/api/auth/verify-email-otp", json={"email": "test@example.com"})
    assert r.status_code == 400


def test_verify_email_otp_invalid_email(auth_client):
    r = auth_client.post("/api/auth/verify-email-otp", json={"email": "bad", "code": "123"})
    assert r.status_code == 400


def test_verify_email_otp_rate_limited(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_verify_rate_limit", lambda e: False)
    r = auth_client.post("/api/auth/verify-email-otp",
                         json={"email": "test@example.com", "code": "123456"})
    assert r.status_code == 429


def test_verify_email_otp_wrong_code(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_verify_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_email_otp", lambda e, c: False)
    r = auth_client.post("/api/auth/verify-email-otp",
                         json={"email": "test@example.com", "code": "000000"})
    assert r.status_code == 401


def test_verify_email_otp_login_no_account(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_verify_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_email_otp", lambda e, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: None)
    r = auth_client.post("/api/auth/verify-email-otp",
                         json={"email": "test@example.com", "code": "123456"})
    assert r.status_code == 404


def test_verify_email_otp_signup_conflict(auth_client, monkeypatch, current_user):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_verify_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_email_otp", lambda e, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: current_user)
    r = auth_client.post("/api/auth/verify-email-otp",
                         json={"email": "test@example.com", "code": "123456",
                               "name": "Ali", "country": "Egypt"})
    assert r.status_code == 409


# ── link_phone ────────────────────────────────────────────────────────────────

def test_link_phone_sends_otp(auth_client, headers, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    monkeypatch.setattr(auth_controller.auth_service, "check_otp_rate_limit", lambda p: True)
    monkeypatch.setattr(auth_controller.auth_service, "send_otp",
                        lambda p: {"status": "pending"})
    r = auth_client.post("/api/auth/link-phone",
                         json={"phone": "+201234567891"}, headers=headers)
    assert r.status_code == 200


def test_link_phone_invalid(auth_client, headers):
    r = auth_client.post("/api/auth/link-phone", json={"phone": "bad"}, headers=headers)
    assert r.status_code == 400


def test_link_phone_taken_by_another(auth_client, headers, monkeypatch, current_user):
    from app.controllers import auth_controller
    other_user = {**current_user, "_id": ObjectId()}
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: other_user)
    r = auth_client.post("/api/auth/link-phone",
                         json={"phone": "+201234567891"}, headers=headers)
    assert r.status_code == 409


def test_link_phone_rate_limited(auth_client, headers, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    monkeypatch.setattr(auth_controller.auth_service, "check_otp_rate_limit", lambda p: False)
    r = auth_client.post("/api/auth/link-phone",
                         json={"phone": "+201234567891"}, headers=headers)
    assert r.status_code == 429


# ── verify_link_phone ─────────────────────────────────────────────────────────

def test_verify_link_phone_success(auth_client, headers, monkeypatch, current_user):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_verify_rate_limit", lambda p: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp", lambda p, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    monkeypatch.setattr(auth_controller.user_model, "update_user", lambda uid, d: None)
    monkeypatch.setattr(auth_controller.user_model, "find_by_id", lambda _id: current_user)
    monkeypatch.setattr(auth_controller.user_model, "serialize",
                        lambda u: {**u, "_id": str(u["_id"])})
    r = auth_client.post("/api/auth/verify-link-phone",
                         json={"phone": "+201234567891", "code": "123456"}, headers=headers)
    assert r.status_code == 200


def test_verify_link_phone_bad_code(auth_client, headers, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_verify_rate_limit", lambda p: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp", lambda p, c: False)
    r = auth_client.post("/api/auth/verify-link-phone",
                         json={"phone": "+201234567891", "code": "000000"}, headers=headers)
    assert r.status_code == 401


def test_verify_link_phone_missing_code(auth_client, headers):
    r = auth_client.post("/api/auth/verify-link-phone",
                         json={"phone": "+201234567891"}, headers=headers)
    assert r.status_code == 400


def test_verify_link_phone_taken_by_other(auth_client, headers, monkeypatch, current_user):
    from app.controllers import auth_controller
    other = {**current_user, "_id": ObjectId()}
    monkeypatch.setattr(auth_controller.auth_service, "check_verify_rate_limit", lambda p: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp", lambda p, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: other)
    r = auth_client.post("/api/auth/verify-link-phone",
                         json={"phone": "+201234567891", "code": "123456"}, headers=headers)
    assert r.status_code == 409


# ── link_email ────────────────────────────────────────────────────────────────

def test_link_email_success(auth_client, headers, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: None)
    monkeypatch.setattr(auth_controller.auth_service, "check_email_otp_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "send_email_otp",
                        lambda e: {"status": "pending"})
    r = auth_client.post("/api/auth/link-email",
                         json={"email": "new@example.com"}, headers=headers)
    assert r.status_code == 200


def test_link_email_invalid(auth_client, headers):
    r = auth_client.post("/api/auth/link-email", json={"email": "bad"}, headers=headers)
    assert r.status_code == 400


def test_link_email_taken_by_other(auth_client, headers, monkeypatch, current_user):
    from app.controllers import auth_controller
    other = {**current_user, "_id": ObjectId()}
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: other)
    r = auth_client.post("/api/auth/link-email",
                         json={"email": "new@example.com"}, headers=headers)
    assert r.status_code == 409


# ── verify_link_email ─────────────────────────────────────────────────────────

def test_verify_link_email_success(auth_client, headers, monkeypatch, current_user):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_verify_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_email_otp", lambda e, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: None)
    monkeypatch.setattr(auth_controller.user_model, "update_user", lambda uid, d: None)
    monkeypatch.setattr(auth_controller.user_model, "find_by_id", lambda _id: current_user)
    monkeypatch.setattr(auth_controller.user_model, "serialize",
                        lambda u: {**u, "_id": str(u["_id"])})
    r = auth_client.post("/api/auth/verify-link-email",
                         json={"email": "new@example.com", "code": "123456"}, headers=headers)
    assert r.status_code == 200


def test_verify_link_email_wrong_code(auth_client, headers, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_email_verify_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_email_otp", lambda e, c: False)
    r = auth_client.post("/api/auth/verify-link-email",
                         json={"email": "new@example.com", "code": "000000"}, headers=headers)
    assert r.status_code == 401


def test_verify_link_email_taken_by_other(auth_client, headers, monkeypatch, current_user):
    from app.controllers import auth_controller
    other = {**current_user, "_id": ObjectId()}
    monkeypatch.setattr(auth_controller.auth_service, "check_email_verify_rate_limit", lambda e: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_email_otp", lambda e, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_email", lambda e: other)
    r = auth_client.post("/api/auth/verify-link-email",
                         json={"email": "new@example.com", "code": "123456"}, headers=headers)
    assert r.status_code == 409


# ── update_profile extra paths ────────────────────────────────────────────────

def test_update_profile_photo_upload_error(auth_client, headers, monkeypatch, current_user):
    from app.controllers import auth_controller
    from io import BytesIO
    monkeypatch.setattr(auth_controller.storage_service, "upload_profile_image",
                        lambda f: (_ for _ in ()).throw(Exception("cloud down")))
    monkeypatch.setattr(auth_controller.user_model, "find_by_id", lambda _id: current_user)
    data = {"photo": (BytesIO(b"\xff\xd8\xff\xe0fake"), "photo.jpg")}
    r = auth_client.put("/api/auth/me", data=data,
                        content_type="multipart/form-data", headers=headers)
    assert r.status_code == 503


def test_update_profile_complete_flag(auth_client, headers, monkeypatch, current_user):
    from app.controllers import auth_controller
    updated = {**current_user, "profile_completed": True}
    monkeypatch.setattr(auth_controller.user_model, "update_user", lambda uid, d: updated)
    monkeypatch.setattr(auth_controller.user_model, "find_by_id", lambda _id: updated)
    r = auth_client.put("/api/auth/me",
                        json={"profile_completed": True}, headers=headers)
    assert r.status_code == 200


# ── delete_account error path ─────────────────────────────────────────────────

def test_delete_account_db_error(auth_client, headers, monkeypatch):
    from unittest.mock import MagicMock
    import app.models.db as db_mod

    bad_col = MagicMock()
    bad_col.return_value.delete_many.side_effect = Exception("db error")

    for name in ("scans_col", "farms_col", "notifications_col",
                 "chat_sessions_col", "chat_messages_col",
                 "forum_posts_col", "forum_comments_col",
                 "forum_questions_col", "forum_answers_col",
                 "users_col"):
        monkeypatch.setattr(db_mod, name, bad_col)

    r = auth_client.delete("/api/auth/account", headers=headers)
    assert r.status_code == 500


# ── register rate limit path ──────────────────────────────────────────────────

def test_register_rate_limited(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    monkeypatch.setattr(auth_controller.auth_service, "check_otp_rate_limit", lambda p: False)
    r = auth_client.post("/api/auth/register",
                         json={"phone": "+201234567890", "name": "Ali", "country": "Egypt"})
    assert r.status_code == 429


def test_register_missing_country(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    r = auth_client.post("/api/auth/register",
                         json={"phone": "+201234567890", "name": "Ali"})
    assert r.status_code == 400


# ── verify_otp signup path ────────────────────────────────────────────────────

def test_verify_otp_signup_path(auth_client, monkeypatch, current_user, user_id):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_verify_rate_limit", lambda p: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp", lambda p, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    monkeypatch.setattr(auth_controller.user_model, "create_user",
                        lambda **kw: {**current_user})
    monkeypatch.setattr(auth_controller.auth_service, "generate_token", lambda uid: "tok")
    monkeypatch.setattr(auth_controller.user_model, "serialize",
                        lambda u: {**u, "_id": str(u["_id"])})
    monkeypatch.setattr(auth_controller.audit_model, "log_action", lambda *a, **kw: None)
    r = auth_client.post("/api/auth/verify-otp",
                         json={"phone": "+201234567890", "code": "123456",
                               "name": "Ali", "country": "Egypt"})
    assert r.status_code == 200
    assert r.get_json()["data"]["is_new_user"] is True


def test_verify_otp_signup_conflict(auth_client, monkeypatch, current_user):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_verify_rate_limit", lambda p: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp", lambda p, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: current_user)
    r = auth_client.post("/api/auth/verify-otp",
                         json={"phone": "+201234567890", "code": "123456",
                               "name": "Ali", "country": "Egypt"})
    assert r.status_code == 409


def test_verify_otp_login_no_account(auth_client, monkeypatch):
    from app.controllers import auth_controller
    monkeypatch.setattr(auth_controller.auth_service, "check_verify_rate_limit", lambda p: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp", lambda p, c: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda p: None)
    r = auth_client.post("/api/auth/verify-otp",
                         json={"phone": "+201234567890", "code": "123456"})
    assert r.status_code == 404
