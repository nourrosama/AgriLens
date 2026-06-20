"""
Storage service + event publisher — comprehensive tests.
"""
import pytest
from unittest.mock import MagicMock, patch
from io import BytesIO
import app.services.storage_service as ss
import app.observers.event_publisher as ep


# ═══════════════════════════════════════════════════════════════════════════════
# Storage service
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def app_ctx(flask_app):
    with flask_app.app_context():
        yield flask_app


def test_uses_local_storage_default():
    old = ss._provider
    ss._provider = "local"
    assert ss.uses_local_storage() is True
    ss._provider = old


def test_get_storage_backend():
    old = ss._provider
    ss._provider = "cloudinary"
    assert ss.get_storage_backend() == "cloudinary"
    ss._provider = old


def test_is_cloudinary_ready_false():
    old_p = ss._provider
    old_r = ss._cloudinary_ready
    ss._provider = "local"
    ss._cloudinary_ready = False
    assert ss.is_cloudinary_ready() is False
    ss._provider = old_p
    ss._cloudinary_ready = old_r


def test_is_cloudinary_ready_true():
    old_p = ss._provider
    old_r = ss._cloudinary_ready
    ss._provider = "cloudinary"
    ss._cloudinary_ready = True
    assert ss.is_cloudinary_ready() is True
    ss._provider = old_p
    ss._cloudinary_ready = old_r


def test_get_storage_status_local():
    old_p = ss._provider
    old_r = ss._cloudinary_ready
    ss._provider = "local"
    ss._cloudinary_ready = False
    status = ss.get_storage_status()
    assert status["provider"] == "local"
    assert status["ready"] is True
    assert status["local_storage_enabled"] is True
    ss._provider = old_p
    ss._cloudinary_ready = old_r


def test_get_storage_status_cloudinary_ready():
    old_p = ss._provider
    old_r = ss._cloudinary_ready
    ss._provider = "cloudinary"
    ss._cloudinary_ready = True
    status = ss.get_storage_status()
    assert status["provider"] == "cloudinary"
    assert status["ready"] is True
    ss._provider = old_p
    ss._cloudinary_ready = old_r


def test_init_storage_local(flask_app):
    flask_app.config["MEDIA_STORAGE_PROVIDER"] = "local"
    flask_app.config["UPLOAD_FOLDER"] = "uploads"
    with flask_app.app_context():
        with patch("os.makedirs") as mock_mkdir:
            ss.init_storage(flask_app)
    assert ss._provider == "local"


def test_init_storage_cloudinary_missing_creds(flask_app):
    flask_app.config["MEDIA_STORAGE_PROVIDER"] = "cloudinary"
    flask_app.config["CLOUDINARY_CLOUD_NAME"] = ""
    flask_app.config["CLOUDINARY_API_KEY"] = ""
    flask_app.config["CLOUDINARY_API_SECRET"] = ""
    with flask_app.app_context():
        ss.init_storage(flask_app)
    assert ss._cloudinary_ready is False
    flask_app.config["MEDIA_STORAGE_PROVIDER"] = "local"


def test_init_storage_cloudinary_with_creds(flask_app):
    flask_app.config["MEDIA_STORAGE_PROVIDER"] = "cloudinary"
    flask_app.config["CLOUDINARY_CLOUD_NAME"] = "test-cloud"
    flask_app.config["CLOUDINARY_API_KEY"] = "key123"
    flask_app.config["CLOUDINARY_API_SECRET"] = "secret456"
    with flask_app.app_context():
        with patch("cloudinary.config") as mock_config:
            ss.init_storage(flask_app)
    assert ss._cloudinary_ready is True
    flask_app.config["MEDIA_STORAGE_PROVIDER"] = "local"
    flask_app.config["CLOUDINARY_CLOUD_NAME"] = ""
    flask_app.config["CLOUDINARY_API_KEY"] = ""
    flask_app.config["CLOUDINARY_API_SECRET"] = ""
    ss._cloudinary_ready = False


# ── Local upload path ─────────────────────────────────────────────────────────

def test_upload_image_local(app_ctx, flask_app):
    flask_app.config["MEDIA_STORAGE_PROVIDER"] = "local"
    flask_app.config["UPLOAD_FOLDER"] = "/tmp/uploads_test"
    old_p = ss._provider
    ss._provider = "local"

    file_obj = MagicMock()
    file_obj.filename = "photo.jpg"
    file_obj.read.return_value = b"fake-image-data"
    file_obj.seek.return_value = None

    with flask_app.app_context():
        with patch("os.makedirs"):
            with patch("builtins.open", MagicMock()):
                url = ss.upload_image(file_obj)
    ss._provider = old_p
    assert url.startswith("/uploads/")


def test_upload_profile_image_local(app_ctx, flask_app):
    flask_app.config["MEDIA_STORAGE_PROVIDER"] = "local"
    flask_app.config["UPLOAD_FOLDER"] = "/tmp/uploads_test"
    old_p = ss._provider
    ss._provider = "local"

    file_obj = MagicMock()
    file_obj.filename = "profile.png"
    file_obj.read.return_value = b"fake-image"
    file_obj.seek.return_value = None

    with flask_app.app_context():
        with patch("os.makedirs"):
            with patch("builtins.open", MagicMock()):
                url = ss.upload_profile_image(file_obj)
    ss._provider = old_p
    assert url.startswith("/uploads/")


def test_upload_video_local(app_ctx, flask_app):
    flask_app.config["MEDIA_STORAGE_PROVIDER"] = "local"
    flask_app.config["UPLOAD_FOLDER"] = "/tmp/uploads_test"
    old_p = ss._provider
    ss._provider = "local"

    file_obj = MagicMock()
    file_obj.filename = "video.mp4"
    file_obj.read.return_value = b"fake-video"
    file_obj.seek.return_value = None

    with flask_app.app_context():
        with patch("os.makedirs"):
            with patch("builtins.open", MagicMock()):
                url = ss.upload_video(file_obj)
    ss._provider = old_p
    assert url.startswith("/uploads/")


# ── Cloudinary upload path ────────────────────────────────────────────────────

def test_upload_image_cloudinary(app_ctx, flask_app):
    old_p = ss._provider
    old_r = ss._cloudinary_ready
    ss._provider = "cloudinary"
    ss._cloudinary_ready = True

    file_obj = MagicMock()
    file_obj.filename = "photo.jpg"
    file_obj.read.return_value = b"fake-image"
    file_obj.seek.return_value = None

    with flask_app.app_context():
        with patch("cloudinary.uploader.upload",
                   return_value={"secure_url": "https://cloudinary.com/img.jpg"}):
            url = ss.upload_image(file_obj)
    ss._provider = old_p
    ss._cloudinary_ready = old_r
    assert url == "https://cloudinary.com/img.jpg"


def test_upload_scan_frame_bytes_local(app_ctx, flask_app):
    flask_app.config["UPLOAD_FOLDER"] = "/tmp/uploads_test"
    old_p = ss._provider
    ss._provider = "local"
    with flask_app.app_context():
        with patch("os.makedirs"):
            with patch("builtins.open", MagicMock()):
                url = ss.upload_scan_frame_bytes(b"fake-frame", "scan123", 0)
    ss._provider = old_p
    assert url.startswith("/uploads/")
    assert url.endswith(".jpg")


def test_upload_scan_gradcam_bytes_local(app_ctx, flask_app):
    flask_app.config["UPLOAD_FOLDER"] = "/tmp/uploads_test"
    old_p = ss._provider
    ss._provider = "local"
    with flask_app.app_context():
        with patch("os.makedirs"):
            with patch("builtins.open", MagicMock()):
                url = ss.upload_scan_gradcam_bytes(b"fake-gradcam", "scan123", 1)
    ss._provider = old_p
    assert url.startswith("/uploads/")
    assert url.endswith(".jpg")


# ── delete_image ──────────────────────────────────────────────────────────────

def test_delete_image_empty_url(app_ctx, flask_app):
    with flask_app.app_context():
        assert ss.delete_image("") is False


def test_delete_image_local_not_exists(app_ctx, flask_app):
    flask_app.config["UPLOAD_FOLDER"] = "/tmp/uploads_test"
    with flask_app.app_context():
        result = ss.delete_image("/uploads/nonexistent_file_xyz.jpg")
    assert result is False


def test_delete_image_local_file(tmp_path, flask_app):
    test_file = tmp_path / "test_img.jpg"
    test_file.write_bytes(b"fake")
    with flask_app.app_context():
        with patch("app.services.storage_service.resolve_local_path",
                   return_value=str(test_file)):
            result = ss.delete_image("/uploads/test_img.jpg")
    assert result is True


def test_delete_image_not_cloudinary(app_ctx, flask_app):
    old_p = ss._provider
    ss._provider = "local"
    with flask_app.app_context():
        result = ss.delete_image("https://cloudinary.com/img.jpg")
    ss._provider = old_p
    assert result is False


# ═══════════════════════════════════════════════════════════════════════════════
# Event publisher tests
# ═══════════════════════════════════════════════════════════════════════════════

def test_publish_no_channel():
    old_ch = ep._channel
    old_conn = ep._connection
    ep._channel = None
    ep._connection = None
    ep.publish("test.event", {"key": "val"})
    ep._channel = old_ch
    ep._connection = old_conn


def test_publish_connection_closed():
    old_ch = ep._channel
    old_conn = ep._connection
    old_url = ep._rabbitmq_url

    mock_conn = MagicMock()
    mock_conn.is_open = False
    mock_ch = MagicMock()
    ep._channel = mock_ch
    ep._connection = mock_conn
    ep._rabbitmq_url = None  # prevent reconnect attempt

    ep.publish("test.event", {"key": "val"})
    ep._channel = old_ch
    ep._connection = old_conn
    ep._rabbitmq_url = old_url


def test_publish_success():
    old_ch = ep._channel
    old_conn = ep._connection
    mock_conn = MagicMock()
    mock_conn.is_open = True
    mock_ch = MagicMock()
    mock_ch.basic_publish.return_value = None
    ep._channel = mock_ch
    ep._connection = mock_conn
    ep.publish("scan.created", {"scan_id": "abc"})
    ep._channel = old_ch
    ep._connection = old_conn
    mock_ch.basic_publish.assert_called_once()


def test_publish_retries_on_failure():
    old_ch = ep._channel
    old_conn = ep._connection
    old_url = ep._rabbitmq_url

    mock_conn = MagicMock()
    mock_conn.is_open = True
    mock_ch = MagicMock()
    mock_ch.basic_publish.side_effect = Exception("publish error")
    ep._channel = mock_ch
    ep._connection = mock_conn
    ep._rabbitmq_url = None  # prevent reconnect from succeeding

    ep.publish("scan.created", {"scan_id": "xyz"})  # should log only, no raise
    ep._channel = old_ch
    ep._connection = old_conn
    ep._rabbitmq_url = old_url


def test_reconnect_no_url():
    old_url = ep._rabbitmq_url
    ep._rabbitmq_url = None
    result = ep._reconnect()
    ep._rabbitmq_url = old_url
    assert result is False


def test_reconnect_failure():
    old_url = ep._rabbitmq_url
    old_ch = ep._channel
    old_conn = ep._connection
    ep._rabbitmq_url = "amqp://bad:bad@127.0.0.1:19999/"

    with patch("pika.BlockingConnection", side_effect=Exception("conn refused")):
        result = ep._reconnect()

    ep._rabbitmq_url = old_url
    ep._channel = old_ch
    ep._connection = old_conn
    assert result is False


def test_scan_created_event():
    with patch.object(ep, "publish") as mock_pub:
        ep.scan_created("scan_001", "https://img.com/scan.jpg")
    mock_pub.assert_called_once()
    args = mock_pub.call_args[0]
    assert args[0] == "scan.created"
    assert args[1]["scan_id"] == "scan_001"


def test_scan_completed_event():
    with patch.object(ep, "publish") as mock_pub:
        ep.scan_completed("scan_001", {"disease": "Blight", "is_healthy": False,
                                       "severity": "high"}, "user123")
    mock_pub.assert_called_once()
    args = mock_pub.call_args[0]
    assert args[0] == "scan.completed"
    assert args[1]["user_id"] == "user123"


def test_disease_detected_event():
    with patch.object(ep, "publish") as mock_pub:
        ep.disease_detected("scan_002", "Late Blight", "severe", "user456")
    mock_pub.assert_called_once()
    args = mock_pub.call_args[0]
    assert args[0] == "disease.detected"
    assert args[1]["disease"] == "Late Blight"


def test_risk_high_event():
    with patch.object(ep, "publish") as mock_pub:
        ep.risk_high("scan_003", "high", "user789")
    mock_pub.assert_called_once()
    args = mock_pub.call_args[0]
    assert args[0] == "risk.high"
    assert args[1]["risk_level"] == "high"


def test_init_publisher_no_rabbitmq():
    from flask import Flask
    app = Flask(__name__)
    app.config["RABBITMQ_URL"] = "amqp://guest:guest@127.0.0.1:19999/"
    with patch("pika.BlockingConnection", side_effect=Exception("conn refused")):
        with patch("time.sleep"):  # skip actual sleeps
            ep.init_publisher(app)
    # Should not raise — just logs warning


def test_publish_reconnect_success():
    old_ch = ep._channel
    old_conn = ep._connection
    old_url = ep._rabbitmq_url

    mock_conn = MagicMock()
    mock_conn.is_open = True
    mock_ch = MagicMock()
    mock_ch.basic_publish.side_effect = [Exception("fail"), None]

    ep._channel = mock_ch
    ep._connection = mock_conn
    ep._rabbitmq_url = "amqp://localhost/"

    # Mock reconnect to succeed
    new_conn = MagicMock()
    new_conn.is_open = True
    new_ch = MagicMock()
    new_ch.basic_publish.return_value = None

    with patch("pika.BlockingConnection", return_value=new_conn):
        ep.publish("test.event", {"data": "x"})

    ep._channel = old_ch
    ep._connection = old_conn
    ep._rabbitmq_url = old_url
