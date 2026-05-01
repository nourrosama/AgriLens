from datetime import timezone

import jwt

from app.services import auth_service


class FakePipeline:
    def __init__(self, store):
        self.store = store
        self.key = None

    def incr(self, key):
        self.key = key
        self.store[key] = self.store.get(key, 0) + 1
        return self

    def expire(self, key, seconds):
        self.store[f"{key}:ttl"] = seconds
        return self

    def execute(self):
        return []


class FakeRedis:
    def __init__(self):
        self.store = {}

    def get(self, key):
        value = self.store.get(key)
        return str(value).encode("utf-8") if value is not None else None

    def pipeline(self):
        return FakePipeline(self.store)


def test_generate_token_contains_subject_and_expiry(flask_app, user_id):
    with flask_app.app_context():
        token = auth_service.generate_token(user_id)

    payload = jwt.decode(token, flask_app.config["JWT_SECRET"], algorithms=["HS256"])
    assert payload["sub"] == user_id
    assert payload["exp"] > payload["iat"]


def test_mock_otp_flow_accepts_only_default_code(flask_app):
    with flask_app.app_context():
        auth_service._twilio_client = None
        auth_service._verify_sid = None

        assert auth_service.send_otp("+201001234567") == {"status": "pending", "mock": True}
        assert auth_service.verify_otp("+201001234567", "123456") is True
        assert auth_service.verify_otp("+201001234567", "000000") is False


def test_rate_limit_blocks_after_configured_attempts(flask_app, monkeypatch):
    fake_redis = FakeRedis()
    monkeypatch.setattr(auth_service, "_redis", fake_redis)
    flask_app.config.update(OTP_RATE_LIMIT_MAX=2, OTP_RATE_LIMIT_WINDOW=60)

    with flask_app.app_context():
        assert auth_service.check_otp_rate_limit("+201001234567") is True
        assert auth_service.check_otp_rate_limit("+201001234567") is True
        assert auth_service.check_otp_rate_limit("+201001234567") is False

    assert fake_redis.store["otp_send:+201001234567:ttl"] == 60


def test_should_use_mock_fallback_in_testing(flask_app):
    with flask_app.app_context():
        assert auth_service._should_use_mock_fallback() is True
