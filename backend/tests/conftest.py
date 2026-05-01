import os
import sys
import types
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from bson import ObjectId
from flask import Flask


BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

if "cloudinary" not in sys.modules:
    cloudinary = types.ModuleType("cloudinary")
    uploader = types.ModuleType("cloudinary.uploader")
    uploader.upload = lambda *args, **kwargs: {"secure_url": "https://cloudinary.test/file.jpg"}
    uploader.destroy = lambda *args, **kwargs: {"result": "ok"}
    cloudinary.config = lambda *args, **kwargs: None
    cloudinary.uploader = uploader
    sys.modules["cloudinary"] = cloudinary
    sys.modules["cloudinary.uploader"] = uploader


@pytest.fixture
def user_id():
    return str(ObjectId())


@pytest.fixture
def current_user(user_id):
    return {
        "_id": ObjectId(user_id),
        "phone": "+201234567890",
        "name": "QA Farmer",
        "language": "en",
        "role": "farmer",
        "farms": [],
    }


def make_token(user_id: str, secret: str = "test-jwt-secret") -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {"sub": user_id, "iat": now, "exp": now + timedelta(hours=1)},
        secret,
        algorithm="HS256",
    )


@pytest.fixture
def auth_headers(user_id):
    return {"Authorization": f"Bearer {make_token(user_id)}"}


@pytest.fixture
def flask_app(monkeypatch, current_user):
    from app.middleware import auth_middleware

    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)

    app = Flask(__name__)
    app.config.update(
        TESTING=True,
        JWT_SECRET="test-jwt-secret",
        UPLOAD_FOLDER="uploads",
        MEDIA_STORAGE_PROVIDER="local",
        DETECTION_MOCK_FALLBACK=True,
        OPENWEATHER_API_KEY="",
    )
    return app


@pytest.fixture
def client_for(flask_app):
    def _client(*blueprints):
        for blueprint in blueprints:
            flask_app.register_blueprint(blueprint)
        return flask_app.test_client()

    return _client
