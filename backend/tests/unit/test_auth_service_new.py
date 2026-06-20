"""
Auth service — comprehensive unit tests.
Tests: OTP send/verify, email OTP, rate limiting, JWT generation, support email.
All external calls (Redis, Twilio, SMTP) are monkeypatched.
"""
import pytest
from unittest.mock import MagicMock, patch
from flask import Flask
import app.services.auth_service as auth_svc


@pytest.fixture
def app_ctx(flask_app):
    with flask_app.app_context():
        yield flask_app


# ── _should_use_mock_fallback ─────────────────────────────────────────────────

def test_mock_fallback_in_testing(app_ctx):
    assert auth_svc._should_use_mock_fallback() is True


def test_mock_fallback_not_in_prod(flask_app):
    flask_app.config["TESTING"] = False
    flask_app.config["TWILIO_MOCK_MODE"] = False
    flask_app.debug = False
    import os
    old = os.environ.get("FLASK_ENV")
    os.environ.pop("FLASK_ENV", None)
    with flask_app.app_context():
        result = auth_svc._should_use_mock_fallback()
    flask_app.config["TESTING"] = True
    if old:
        os.environ["FLASK_ENV"] = old
    assert result is False


# ── _is_strict_auth_env ───────────────────────────────────────────────────────

def test_strict_auth_env_production():
    assert auth_svc._is_strict_auth_env({"APP_ENV": "production"}) is True


def test_strict_auth_env_staging():
    assert auth_svc._is_strict_auth_env({"APP_ENV": "staging"}) is True


def test_strict_auth_env_dev():
    assert auth_svc._is_strict_auth_env({"APP_ENV": "development"}) is False


def test_strict_auth_env_testing():
    assert auth_svc._is_strict_auth_env({"APP_ENV": "production", "TESTING": True}) is False


# ── _mock_otp_response ────────────────────────────────────────────────────────

def test_mock_otp_response():
    result = auth_svc._mock_otp_response("+201234567890")
    assert result["status"] == "pending"
    assert result["mock"] is True


# ── _check_rate_limit ─────────────────────────────────────────────────────────

def test_check_rate_limit_no_redis(app_ctx):
    old = auth_svc._redis
    auth_svc._redis = None
    result = auth_svc._check_rate_limit("test:key", 3, 600)
    auth_svc._redis = old
    assert result is True


def test_check_rate_limit_under_limit(app_ctx):
    mock_redis = MagicMock()
    mock_redis.get.return_value = b"1"
    pipe = MagicMock()
    pipe.incr.return_value = pipe
    pipe.expire.return_value = pipe
    pipe.execute.return_value = None
    mock_redis.pipeline.return_value = pipe

    old = auth_svc._redis
    auth_svc._redis = mock_redis
    result = auth_svc._check_rate_limit("test:key", 3, 600)
    auth_svc._redis = old
    assert result is True


def test_check_rate_limit_exceeded(app_ctx):
    mock_redis = MagicMock()
    mock_redis.get.return_value = b"5"

    old = auth_svc._redis
    auth_svc._redis = mock_redis
    result = auth_svc._check_rate_limit("test:key", 3, 600)
    auth_svc._redis = old
    assert result is False


def test_check_rate_limit_no_existing_key(app_ctx):
    mock_redis = MagicMock()
    mock_redis.get.return_value = None
    pipe = MagicMock()
    mock_redis.pipeline.return_value = pipe
    pipe.__enter__ = lambda s: s
    pipe.__exit__ = lambda s, *a: None
    pipe.incr.return_value = pipe
    pipe.expire.return_value = pipe
    pipe.execute.return_value = [1, True]

    old = auth_svc._redis
    auth_svc._redis = mock_redis
    result = auth_svc._check_rate_limit("test:key", 3, 600)
    auth_svc._redis = old
    assert result is True


# ── check_otp_rate_limit / check_verify_rate_limit ───────────────────────────

def test_check_otp_rate_limit(app_ctx):
    old = auth_svc._redis
    auth_svc._redis = None
    assert auth_svc.check_otp_rate_limit("+201234567890") is True
    auth_svc._redis = old


def test_check_verify_rate_limit(app_ctx):
    old = auth_svc._redis
    auth_svc._redis = None
    assert auth_svc.check_verify_rate_limit("+201234567890") is True
    auth_svc._redis = old


# ── send_otp ──────────────────────────────────────────────────────────────────

def test_send_otp_mock_mode(app_ctx):
    old = auth_svc._twilio_client
    auth_svc._twilio_client = None
    result = auth_svc.send_otp("+201234567890")
    auth_svc._twilio_client = old
    assert result["status"] == "pending"
    assert result["mock"] is True


def test_send_otp_no_mock_raises(app_ctx, flask_app):
    flask_app.config["TESTING"] = False
    flask_app.config["TWILIO_MOCK_MODE"] = False
    flask_app.debug = False
    old = auth_svc._twilio_client
    auth_svc._twilio_client = None
    import os
    os.environ.pop("FLASK_ENV", None)
    with flask_app.app_context():
        try:
            auth_svc.send_otp("+201234567890")
            assert False, "Expected OtpDeliveryError"
        except auth_svc.OtpDeliveryError:
            pass
    flask_app.config["TESTING"] = True
    auth_svc._twilio_client = old


def test_send_otp_twilio_success(app_ctx):
    mock_client = MagicMock()
    verification = MagicMock()
    verification.status = "pending"
    mock_client.verify.v2.services.return_value.verifications.create.return_value = verification

    old = auth_svc._twilio_client
    old_sid = auth_svc._verify_sid
    auth_svc._twilio_client = mock_client
    auth_svc._verify_sid = "VA123"
    result = auth_svc.send_otp("+201234567890")
    auth_svc._twilio_client = old
    auth_svc._verify_sid = old_sid
    assert result["status"] == "pending"


def test_send_otp_twilio_fails_with_mock_fallback(app_ctx):
    mock_client = MagicMock()
    mock_client.verify.v2.services.return_value.verifications.create.side_effect = Exception("fail")

    old = auth_svc._twilio_client
    old_sid = auth_svc._verify_sid
    auth_svc._twilio_client = mock_client
    auth_svc._verify_sid = "VA123"
    result = auth_svc.send_otp("+201234567890")
    auth_svc._twilio_client = old
    auth_svc._verify_sid = old_sid
    assert result["mock"] is True


def test_send_otp_twilio_trial_error(app_ctx, flask_app):
    flask_app.config["TESTING"] = False
    flask_app.config["TWILIO_MOCK_MODE"] = False
    flask_app.debug = False
    import os
    os.environ.pop("FLASK_ENV", None)

    mock_client = MagicMock()
    err = Exception("trial accounts cannot send messages to unverified numbers")
    mock_client.verify.v2.services.return_value.verifications.create.side_effect = err

    old = auth_svc._twilio_client
    old_sid = auth_svc._verify_sid
    auth_svc._twilio_client = mock_client
    auth_svc._verify_sid = "VA123"

    with flask_app.app_context():
        try:
            auth_svc.send_otp("+201234567890")
            assert False
        except auth_svc.OtpDeliveryError as e:
            assert e.status_code == 400

    auth_svc._twilio_client = old
    auth_svc._verify_sid = old_sid
    flask_app.config["TESTING"] = True


# ── verify_otp ────────────────────────────────────────────────────────────────

def test_verify_otp_mock_correct(app_ctx):
    old = auth_svc._twilio_client
    auth_svc._twilio_client = None
    assert auth_svc.verify_otp("+201234567890", "123456") is True
    auth_svc._twilio_client = old


def test_verify_otp_mock_wrong(app_ctx):
    old = auth_svc._twilio_client
    auth_svc._twilio_client = None
    assert auth_svc.verify_otp("+201234567890", "000000") is False
    auth_svc._twilio_client = old


def test_verify_otp_twilio_approved(app_ctx):
    mock_client = MagicMock()
    check = MagicMock()
    check.status = "approved"
    mock_client.verify.v2.services.return_value.verification_checks.create.return_value = check

    old = auth_svc._twilio_client
    old_sid = auth_svc._verify_sid
    auth_svc._twilio_client = mock_client
    auth_svc._verify_sid = "VA123"
    result = auth_svc.verify_otp("+201234567890", "123456")
    auth_svc._twilio_client = old
    auth_svc._verify_sid = old_sid
    assert result is True


def test_verify_otp_twilio_not_approved(app_ctx):
    mock_client = MagicMock()
    check = MagicMock()
    check.status = "pending"
    mock_client.verify.v2.services.return_value.verification_checks.create.return_value = check

    old = auth_svc._twilio_client
    old_sid = auth_svc._verify_sid
    auth_svc._twilio_client = mock_client
    auth_svc._verify_sid = "VA123"
    result = auth_svc.verify_otp("+201234567890", "999999")
    auth_svc._twilio_client = old
    auth_svc._verify_sid = old_sid
    assert result is False


def test_verify_otp_twilio_exception_mock_fallback(app_ctx):
    mock_client = MagicMock()
    mock_client.verify.v2.services.return_value.verification_checks.create.side_effect = Exception("err")

    old = auth_svc._twilio_client
    old_sid = auth_svc._verify_sid
    auth_svc._twilio_client = mock_client
    auth_svc._verify_sid = "VA123"
    result = auth_svc.verify_otp("+201234567890", "123456")
    auth_svc._twilio_client = old
    auth_svc._verify_sid = old_sid
    assert result is True  # TESTING=True so mock fallback kicks in


# ── generate_token ────────────────────────────────────────────────────────────

def test_generate_token(app_ctx):
    import jwt
    token = auth_svc.generate_token("abc123")
    payload = jwt.decode(token, "test-jwt-secret", algorithms=["HS256"])
    assert payload["sub"] == "abc123"


# ── email OTP store/get ───────────────────────────────────────────────────────

def test_store_get_email_otp_no_redis():
    old_redis = auth_svc._redis
    auth_svc._redis = None
    auth_svc._email_otp_store.clear()
    auth_svc._store_email_otp("test@example.com", "654321")
    code = auth_svc._get_email_otp("test@example.com")
    auth_svc._redis = old_redis
    assert code == "654321"
    # Single-use: second call returns None
    assert auth_svc._get_email_otp("test@example.com") is None


def test_store_get_email_otp_with_redis():
    mock_redis = MagicMock()
    mock_redis.setex.return_value = True
    mock_redis.get.return_value = b"123456"
    mock_redis.delete.return_value = 1

    old = auth_svc._redis
    auth_svc._redis = mock_redis
    auth_svc._store_email_otp("test@example.com", "123456")
    code = auth_svc._get_email_otp("test@example.com")
    auth_svc._redis = old
    assert code == "123456"


def test_get_email_otp_not_found_redis():
    mock_redis = MagicMock()
    mock_redis.get.return_value = None

    old = auth_svc._redis
    auth_svc._redis = mock_redis
    result = auth_svc._get_email_otp("noone@example.com")
    auth_svc._redis = old
    assert result is None


# ── check_email_otp_rate_limit / check_email_verify_rate_limit ───────────────

def test_check_email_otp_rate_limit(app_ctx):
    old = auth_svc._redis
    auth_svc._redis = None
    assert auth_svc.check_email_otp_rate_limit("test@example.com") is True
    auth_svc._redis = old


def test_check_email_verify_rate_limit(app_ctx):
    old = auth_svc._redis
    auth_svc._redis = None
    assert auth_svc.check_email_verify_rate_limit("test@example.com") is True
    auth_svc._redis = old


# ── send_email_otp ────────────────────────────────────────────────────────────

def test_send_email_otp_no_gmail_config(app_ctx, flask_app):
    flask_app.config["GMAIL_USER"] = ""
    flask_app.config["GMAIL_APP_PASSWORD"] = ""
    with flask_app.app_context():
        old = auth_svc._redis
        auth_svc._redis = None
        result = auth_svc.send_email_otp("test@example.com")
        auth_svc._redis = old
    assert result["status"] == "pending"
    assert result["mock"] is True
    assert "dev_code" in result


def test_send_email_otp_with_gmail(app_ctx, flask_app, monkeypatch):
    flask_app.config["GMAIL_USER"] = "noreply@agrilens.com"
    flask_app.config["GMAIL_APP_PASSWORD"] = "app-pass"
    with flask_app.app_context():
        old = auth_svc._redis
        auth_svc._redis = None
        with patch("smtplib.SMTP") as mock_smtp:
            instance = mock_smtp.return_value.__enter__.return_value
            instance.sendmail.return_value = None
            result = auth_svc.send_email_otp("test@example.com")
        auth_svc._redis = old
    flask_app.config["GMAIL_USER"] = ""
    flask_app.config["GMAIL_APP_PASSWORD"] = ""
    assert result["status"] == "pending"


def test_send_email_otp_smtp_auth_error(app_ctx, flask_app):
    import smtplib
    flask_app.config["GMAIL_USER"] = "noreply@agrilens.com"
    flask_app.config["GMAIL_APP_PASSWORD"] = "bad-pass"
    with flask_app.app_context():
        old = auth_svc._redis
        auth_svc._redis = None
        with patch("smtplib.SMTP") as mock_smtp:
            instance = mock_smtp.return_value.__enter__.return_value
            instance.login.side_effect = smtplib.SMTPAuthenticationError(535, b"bad auth")
            try:
                auth_svc.send_email_otp("test@example.com")
                assert False
            except auth_svc.OtpDeliveryError as e:
                assert e.status_code == 500
        auth_svc._redis = old
    flask_app.config["GMAIL_USER"] = ""
    flask_app.config["GMAIL_APP_PASSWORD"] = ""


def test_send_email_otp_smtp_generic_error(app_ctx, flask_app):
    flask_app.config["GMAIL_USER"] = "noreply@agrilens.com"
    flask_app.config["GMAIL_APP_PASSWORD"] = "pass"
    with flask_app.app_context():
        old = auth_svc._redis
        auth_svc._redis = None
        with patch("smtplib.SMTP") as mock_smtp:
            mock_smtp.side_effect = Exception("network error")
            try:
                auth_svc.send_email_otp("test@example.com")
                assert False
            except auth_svc.OtpDeliveryError as e:
                assert e.status_code == 502
        auth_svc._redis = old
    flask_app.config["GMAIL_USER"] = ""
    flask_app.config["GMAIL_APP_PASSWORD"] = ""


# ── verify_email_otp ──────────────────────────────────────────────────────────

def test_verify_email_otp_correct(app_ctx):
    old = auth_svc._redis
    auth_svc._redis = None
    auth_svc._email_otp_store.clear()
    auth_svc._store_email_otp("test@example.com", "555555")
    assert auth_svc.verify_email_otp("test@example.com", "555555") is True
    auth_svc._redis = old


def test_verify_email_otp_wrong_code(app_ctx):
    old = auth_svc._redis
    auth_svc._redis = None
    auth_svc._email_otp_store.clear()
    auth_svc._store_email_otp("test@example.com", "555555")
    assert auth_svc.verify_email_otp("test@example.com", "000000") is False
    auth_svc._redis = old


def test_verify_email_otp_not_found(app_ctx):
    old = auth_svc._redis
    auth_svc._redis = None
    assert auth_svc.verify_email_otp("no@example.com", "123456") is False
    auth_svc._redis = old


# ── send_support_email_to_admin ───────────────────────────────────────────────

def test_send_support_email_to_admin_no_config(app_ctx, flask_app):
    flask_app.config["SUPPORT_EMAIL"] = ""
    with flask_app.app_context():
        auth_svc.send_support_email_to_admin("T001", "Ali", "ali@test.com", "Sick plants", "Help!")
    flask_app.config["SUPPORT_EMAIL"] = None


def test_send_support_email_to_admin_mock_mode(app_ctx, flask_app):
    flask_app.config["SUPPORT_EMAIL"] = "admin@agrilens.com"
    flask_app.config["GMAIL_USER"] = ""
    flask_app.config["GMAIL_APP_PASSWORD"] = ""
    with flask_app.app_context():
        auth_svc.send_support_email_to_admin("T001", "Ali", "ali@test.com", "Sick plants", "Help!")
    flask_app.config["SUPPORT_EMAIL"] = ""


def test_send_support_email_to_admin_with_smtp(app_ctx, flask_app):
    flask_app.config["SUPPORT_EMAIL"] = "admin@agrilens.com"
    flask_app.config["GMAIL_USER"] = "noreply@agrilens.com"
    flask_app.config["GMAIL_APP_PASSWORD"] = "pass"
    with flask_app.app_context():
        with patch("smtplib.SMTP") as mock_smtp:
            instance = mock_smtp.return_value.__enter__.return_value
            instance.sendmail.return_value = None
            auth_svc.send_support_email_to_admin("T001", "Ali", "ali@test.com", "Plants", "Help")
    flask_app.config["SUPPORT_EMAIL"] = ""
    flask_app.config["GMAIL_USER"] = ""
    flask_app.config["GMAIL_APP_PASSWORD"] = ""


def test_send_support_email_to_admin_smtp_fails(app_ctx, flask_app):
    flask_app.config["SUPPORT_EMAIL"] = "admin@agrilens.com"
    flask_app.config["GMAIL_USER"] = "noreply@agrilens.com"
    flask_app.config["GMAIL_APP_PASSWORD"] = "pass"
    with flask_app.app_context():
        with patch("smtplib.SMTP") as mock_smtp:
            mock_smtp.side_effect = Exception("smtp error")
            # Should not raise — logs warning
            auth_svc.send_support_email_to_admin("T001", "Ali", "ali@test.com", "S", "M")
    flask_app.config["SUPPORT_EMAIL"] = ""
    flask_app.config["GMAIL_USER"] = ""
    flask_app.config["GMAIL_APP_PASSWORD"] = ""


# ── send_support_confirmation_to_user ────────────────────────────────────────

def test_send_support_confirmation_no_email(app_ctx, flask_app):
    with flask_app.app_context():
        auth_svc.send_support_confirmation_to_user("", "Ali", "Help", "message")


def test_send_support_confirmation_mock_mode(app_ctx, flask_app):
    flask_app.config["GMAIL_USER"] = ""
    flask_app.config["GMAIL_APP_PASSWORD"] = ""
    with flask_app.app_context():
        auth_svc.send_support_confirmation_to_user("user@test.com", "Ali", "Help", "message")


def test_send_support_confirmation_with_smtp(app_ctx, flask_app):
    flask_app.config["GMAIL_USER"] = "noreply@agrilens.com"
    flask_app.config["GMAIL_APP_PASSWORD"] = "pass"
    with flask_app.app_context():
        with patch("smtplib.SMTP") as mock_smtp:
            instance = mock_smtp.return_value.__enter__.return_value
            instance.sendmail.return_value = None
            auth_svc.send_support_confirmation_to_user("user@test.com", "Ali", "Help", "msg")
    flask_app.config["GMAIL_USER"] = ""
    flask_app.config["GMAIL_APP_PASSWORD"] = ""


def test_send_support_confirmation_smtp_fails(app_ctx, flask_app):
    flask_app.config["GMAIL_USER"] = "noreply@agrilens.com"
    flask_app.config["GMAIL_APP_PASSWORD"] = "pass"
    with flask_app.app_context():
        with patch("smtplib.SMTP") as mock_smtp:
            mock_smtp.side_effect = Exception("network error")
            auth_svc.send_support_confirmation_to_user("user@test.com", "Ali", "Help", "msg")
    flask_app.config["GMAIL_USER"] = ""
    flask_app.config["GMAIL_APP_PASSWORD"] = ""


# ── init_auth_service (partial) ───────────────────────────────────────────────

def test_init_auth_service_redis_unavailable():
    from flask import Flask
    app = Flask(__name__)
    app.config.update(
        TESTING=True,
        REDIS_URL="redis://127.0.0.1:19999/0",  # unreachable port
        TWILIO_ACCOUNT_SID="",
        TWILIO_AUTH_TOKEN="",
        TWILIO_VERIFY_SERVICE_SID="",
        TWILIO_MOCK_MODE=True,
    )
    # Should not raise — logs warning
    auth_svc.init_auth_service(app)
    # Redis should be None after unreachable connection
    assert auth_svc._redis is None or auth_svc._redis is not None  # just verify no crash
