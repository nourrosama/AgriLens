"""
Coverage boost — targeted tests for uncovered lines in:
  - scan_controller helpers (_allowed_file, _verify_magic_bytes, _update_field_health_from_detection)
  - subscription_service (build_scan_response professional tier, get_monthly_scan_count)
  - push_service (firebase init, send exception)
  - farm_controller (update_field endpoint, update_farm with location)
  - forum_controller (upload_media, _send_notification helper)
"""
import pytest
from io import BytesIO
from unittest.mock import MagicMock, patch
from bson import ObjectId


# ═══════════════════════════════════════════════════════════════════════════════
# scan_controller helper functions
# ═══════════════════════════════════════════════════════════════════════════════

from app.controllers.scan_controller import (
    _allowed_file, _verify_magic_bytes, _update_field_health_from_detection,
    ALLOWED_IMAGE_EXT, ALLOWED_VIDEO_EXT,
)


def test_allowed_file_jpg():
    assert _allowed_file("photo.jpg", {"jpg", "jpeg"}) is True


def test_allowed_file_no_dot():
    assert _allowed_file("photonoext") is False


def test_allowed_file_default_all_types():
    assert _allowed_file("clip.mp4") is True
    assert _allowed_file("img.png") is True
    assert _allowed_file("file.exe") is False


def test_allowed_file_empty_name():
    assert _allowed_file("") is False


def test_verify_magic_bytes_jpeg():
    f = BytesIO(b"\xff\xd8\xff\x00" + b"\x00" * 8)
    assert _verify_magic_bytes(f, {"jpg", "jpeg"}) is True
    assert f.read(1) != b""  # seek(0) was called


def test_verify_magic_bytes_png():
    f = BytesIO(b"\x89PNG" + b"\x00" * 8)
    assert _verify_magic_bytes(f, {"png"}) is True


def test_verify_magic_bytes_webp():
    f = BytesIO(b"RIFF" + b"\x00" * 4 + b"WEBP")
    assert _verify_magic_bytes(f, {"webp"}) is True


def test_verify_magic_bytes_mp4():
    f = BytesIO(b"\x00\x00\x00\x00ftyp" + b"\x00" * 4)
    assert _verify_magic_bytes(f, {"mp4", "mov"}) is True


def test_verify_magic_bytes_avi():
    f = BytesIO(b"RIFF" + b"\x00" * 4 + b"AVI ")
    assert _verify_magic_bytes(f, {"avi"}) is True


def test_verify_magic_bytes_mkv():
    f = BytesIO(b"\x1aE\xdf\xa3" + b"\x00" * 8)
    assert _verify_magic_bytes(f, {"mkv"}) is True


def test_verify_magic_bytes_wrong_type():
    f = BytesIO(b"\xff\xd8\xff\x00" + b"\x00" * 8)  # JPEG header
    assert _verify_magic_bytes(f, {"png"}) is False


def test_verify_magic_bytes_random_bytes():
    f = BytesIO(b"\xde\xad\xbe\xef" + b"\x00" * 8)
    assert _verify_magic_bytes(f, {"jpg", "mp4", "mkv"}) is False


def test_update_field_health_no_farm_id(flask_app):
    with flask_app.app_context():
        with patch("app.controllers.scan_controller.farm_model") as fm:
            _update_field_health_from_detection(None, "field123", {"is_healthy": False})
            fm.update_field.assert_not_called()


def test_update_field_health_no_field_id(flask_app):
    with flask_app.app_context():
        with patch("app.controllers.scan_controller.farm_model") as fm:
            _update_field_health_from_detection("farm123", None, {"is_healthy": False})
            fm.update_field.assert_not_called()


def test_update_field_health_no_detection(flask_app):
    with flask_app.app_context():
        with patch("app.controllers.scan_controller.farm_model") as fm:
            _update_field_health_from_detection("farm123", "field123", None)
            fm.update_field.assert_not_called()


def test_update_field_health_healthy(flask_app):
    with flask_app.app_context():
        with patch("app.controllers.scan_controller.farm_model") as fm:
            _update_field_health_from_detection("farm123", "field123",
                                                {"is_healthy": True, "severity": "none"})
            fm.update_field.assert_called_once()
            args = fm.update_field.call_args[0]
            assert args[2]["health_score"] == 100
            assert args[2]["risk_level"] == "low"


def test_update_field_health_high_severity(flask_app):
    with flask_app.app_context():
        with patch("app.controllers.scan_controller.farm_model") as fm:
            _update_field_health_from_detection("farm123", "field123",
                                                {"is_healthy": False, "severity": "high",
                                                 "risk_level": "high"})
            args = fm.update_field.call_args[0]
            assert args[2]["health_score"] == 45


def test_update_field_health_medium_severity(flask_app):
    with flask_app.app_context():
        with patch("app.controllers.scan_controller.farm_model") as fm:
            _update_field_health_from_detection("farm123", "field123",
                                                {"is_healthy": False, "severity": "medium",
                                                 "risk_level": "medium"})
            args = fm.update_field.call_args[0]
            assert args[2]["health_score"] == 65


def test_update_field_health_low_severity(flask_app):
    with flask_app.app_context():
        with patch("app.controllers.scan_controller.farm_model") as fm:
            _update_field_health_from_detection("farm123", "field123",
                                                {"is_healthy": False, "severity": "low",
                                                 "risk_level": "low"})
            args = fm.update_field.call_args[0]
            assert args[2]["health_score"] == 78


def test_update_field_health_exception_logged(flask_app):
    with flask_app.app_context():
        with patch("app.controllers.scan_controller.farm_model") as fm:
            fm.update_field.side_effect = Exception("DB error")
            # Should not raise
            _update_field_health_from_detection("farm123", "field123",
                                                {"is_healthy": False, "severity": "high",
                                                 "risk_level": "high"})


def test_update_field_health_critical_severity(flask_app):
    with flask_app.app_context():
        with patch("app.controllers.scan_controller.farm_model") as fm:
            _update_field_health_from_detection("farm123", "field123",
                                                {"is_healthy": False, "severity": "critical",
                                                 "risk_level": "high"})
            args = fm.update_field.call_args[0]
            assert args[2]["health_score"] == 45


# ═══════════════════════════════════════════════════════════════════════════════
# subscription_service — build_scan_response professional tier
# ═══════════════════════════════════════════════════════════════════════════════

def test_build_scan_response_professional():
    from app.services.subscription_service import build_scan_response
    detection = {
        "disease": "Wheat Rust",
        "scientific_name": "Puccinia triticina",
        "confidence": 0.87,
        "is_healthy": False,
        "severity": "medium",
    }
    report = {
        "what_is_it": "Fungal disease",
        "immediate_actions": ["Remove infected leaves", "Apply fungicide"],
        "symptoms": ["Yellow spots", "Rust lesions"],
        "how_spreads": "Wind-borne spores",
        "favorable_conditions": "High humidity",
        "pathogen_type": "Fungal",
        "treatment_chemical": ["Propiconazole"],
        "treatment_organic": ["Neem oil"],
        "when_to_apply": "Early morning",
        "prevention": ["Crop rotation"],
        "scan_again_recommended": True,
        "look_alike_diseases": [],
        "confidence_note": "High confidence",
        "urgency_label": "Act within 48 hours",
        "urgency_level": "high",
        "estimated_impact": "20-30% yield loss",
        "economic_threshold": "5 lesions per leaf",
    }
    user = {"_id": ObjectId(), "plan": "professional", "subscription_plan": "professional"}
    result = build_scan_response(detection, report, user)
    assert result["plan"] == "professional"
    assert "yield_impact" in result
    assert "cost_estimation" in result
    assert "farm_insights" in result
    assert result["economic_threshold"] == "5 lesions per leaf"
    assert "treatment_plan" in result


def test_build_scan_response_premium():
    from app.services.subscription_service import build_scan_response
    detection = {
        "disease": "Blight", "confidence": 0.9,
        "is_healthy": False, "severity": "high",
        "recommendation": "Apply copper fungicide",
    }
    user = {"_id": ObjectId(), "plan": "premium", "subscription_plan": "premium"}
    result = build_scan_response(detection, None, user)
    assert result["plan"] == "premium"
    assert "treatment_plan" in result
    assert "yield_impact" not in result


def test_build_scan_response_free_with_recommendation():
    from app.services.subscription_service import build_scan_response
    detection = {
        "disease": "Rust", "confidence": 0.75,
        "is_healthy": False, "severity": "low",
        "recommendation": "Monitor weekly",
    }
    user = {"_id": ObjectId(), "plan": "free", "subscription_plan": "free"}
    result = build_scan_response(detection, None, user)
    assert result["plan"] == "free"
    assert "upgrade_hint" in result
    assert "Monitor weekly" in result["basic_treatment"]


def test_get_monthly_scan_count(flask_app):
    from app.services import subscription_service as ss
    mock_col = MagicMock()
    mock_col.count_documents.return_value = 3
    with flask_app.app_context():
        with patch.object(ss, "scans_col", return_value=mock_col):
            count = ss.get_monthly_scan_count(str(ObjectId()))
    assert count == 3


# ═══════════════════════════════════════════════════════════════════════════════
# push_service — firebase init and send exception
# ═══════════════════════════════════════════════════════════════════════════════

def test_init_push_service_with_creds(flask_app):
    import app.services.push_service as ps
    old_app = ps._firebase_app
    old_enabled = ps._firebase_enabled
    try:
        with flask_app.app_context():
            flask_app.config["FIREBASE_CREDENTIALS_PATH"] = "/fake/creds.json"
            mock_cred = MagicMock()
            mock_app = MagicMock()

            with patch("os.path.exists", return_value=True):
                with patch.dict("sys.modules", {
                    "firebase_admin": MagicMock(initialize_app=MagicMock(return_value=mock_app)),
                    "firebase_admin.credentials": MagicMock(Certificate=MagicMock(return_value=mock_cred)),
                }):
                    ps.init_push_service(flask_app)

        assert ps._firebase_enabled is True
    finally:
        ps._firebase_app = old_app
        ps._firebase_enabled = old_enabled


def test_init_push_service_import_error(flask_app):
    import app.services.push_service as ps
    old_enabled = ps._firebase_enabled
    try:
        with flask_app.app_context():
            flask_app.config["FIREBASE_CREDENTIALS_PATH"] = "/fake/creds.json"
            with patch("os.path.exists", return_value=True):
                # Make firebase_admin import fail
                import builtins
                original_import = builtins.__import__
                def mock_import(name, *args, **kwargs):
                    if name == "firebase_admin":
                        raise ImportError("no module")
                    return original_import(name, *args, **kwargs)
                with patch("builtins.__import__", side_effect=mock_import):
                    ps.init_push_service(flask_app)
        # Should not raise
    finally:
        ps._firebase_enabled = old_enabled


def test_init_push_service_exception(flask_app):
    import app.services.push_service as ps
    old_enabled = ps._firebase_enabled
    try:
        with flask_app.app_context():
            flask_app.config["FIREBASE_CREDENTIALS_PATH"] = "/fake/creds.json"
            with patch("os.path.exists", return_value=True):
                with patch.dict("sys.modules", {
                    "firebase_admin": MagicMock(
                        initialize_app=MagicMock(side_effect=Exception("init failed"))
                    ),
                    "firebase_admin.credentials": MagicMock(),
                }):
                    ps.init_push_service(flask_app)
        # Should not raise
    finally:
        ps._firebase_enabled = old_enabled


def test_send_push_firebase_send_exception():
    import app.services.push_service as ps
    old_enabled = ps._firebase_enabled
    old_app = ps._firebase_app
    try:
        ps._firebase_enabled = True
        ps._firebase_app = MagicMock()
        user = {"_id": "user1", "fcm_tokens": ["token1"]}
        with patch.dict("sys.modules", {
            "firebase_admin.messaging": MagicMock(
                Message=MagicMock(),
                Notification=MagicMock(),
                send_each=MagicMock(side_effect=Exception("FCM failed")),
            ),
        }):
            ps.send_push_to_user(user, "Test", "Body")
        # Should not raise
    finally:
        ps._firebase_enabled = old_enabled
        ps._firebase_app = old_app


# ═══════════════════════════════════════════════════════════════════════════════
# farm_controller — update_field and update_farm with location
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def farm_client2(client_for, monkeypatch, current_user):
    from app.controllers.farm_controller import farm_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(farm_bp)


@pytest.fixture
def farm_headers2(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def test_update_farm_with_location(farm_client2, farm_headers2, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.models import audit_model as am
    from app.services import cache, insights_service as ins
    farm_id = str(ObjectId())
    fake = {"_id": ObjectId(farm_id), "owner_id": ObjectId(user_id), "name": "Farm X"}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake)
    monkeypatch.setattr(fm, "update_farm", lambda fid, data: None)
    monkeypatch.setattr(fm, "serialize", lambda f: {"id": str(f["_id"])})
    monkeypatch.setattr(am, "log_action", lambda *a, **kw: None)
    monkeypatch.setattr(cache, "delete", lambda key: None)
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: {"temp": 28})
    r = farm_client2.put(f"/api/farms/{farm_id}",
                         json={"location": {"lat": 30.0, "lng": 31.0}},
                         headers=farm_headers2)
    assert r.status_code == 200


def test_update_field_success(farm_client2, farm_headers2, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import cache
    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    fake_farm = {"_id": ObjectId(farm_id), "owner_id": ObjectId(user_id), "fields": []}
    fake_field = {"field_id": ObjectId(field_id), "name": "Field A"}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake_farm)
    monkeypatch.setattr(fm, "update_field", lambda fid, fiid, data: None)
    monkeypatch.setattr(fm, "get_field", lambda fid, fiid: fake_field)
    monkeypatch.setattr(fm, "serialize_field", lambda f: {"id": str(f["field_id"])})
    monkeypatch.setattr(cache, "delete", lambda key: None)
    r = farm_client2.put(f"/api/farms/{farm_id}/fields/{field_id}",
                         json={"name": "Updated Field"},
                         headers=farm_headers2)
    assert r.status_code == 200


def test_update_field_invalid_id(farm_client2, farm_headers2):
    r = farm_client2.put("/api/farms/bad-farm/fields/bad-field",
                         json={"name": "X"}, headers=farm_headers2)
    assert r.status_code == 400


def test_update_field_farm_not_found(farm_client2, farm_headers2, monkeypatch):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: None)
    r = farm_client2.put(f"/api/farms/{farm_id}/fields/{field_id}",
                         json={"name": "X"}, headers=farm_headers2)
    assert r.status_code == 404


def test_update_field_field_not_found(farm_client2, farm_headers2, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import cache
    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    fake_farm = {"_id": ObjectId(farm_id), "owner_id": ObjectId(user_id), "fields": []}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake_farm)
    monkeypatch.setattr(fm, "update_field", lambda fid, fiid, data: None)
    monkeypatch.setattr(fm, "get_field", lambda fid, fiid: None)
    monkeypatch.setattr(cache, "delete", lambda key: None)
    r = farm_client2.put(f"/api/farms/{farm_id}/fields/{field_id}",
                         json={"name": "X"}, headers=farm_headers2)
    assert r.status_code == 404


def test_update_field_with_location(farm_client2, farm_headers2, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import cache, insights_service as ins
    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    fake_farm = {"_id": ObjectId(farm_id), "owner_id": ObjectId(user_id), "fields": []}
    fake_field = {"field_id": ObjectId(field_id), "name": "Field A"}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake_farm)
    monkeypatch.setattr(fm, "update_field", lambda fid, fiid, data: None)
    monkeypatch.setattr(fm, "get_field", lambda fid, fiid: fake_field)
    monkeypatch.setattr(fm, "serialize_field", lambda f: {"id": str(f["field_id"])})
    monkeypatch.setattr(cache, "delete", lambda key: None)
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: {"temp": 28})
    r = farm_client2.put(f"/api/farms/{farm_id}/fields/{field_id}",
                         json={"location": {"lat": 30.0, "lng": 31.0}},
                         headers=farm_headers2)
    assert r.status_code == 200


def test_remove_field_invalid_id(farm_client2, farm_headers2):
    r = farm_client2.delete("/api/farms/bad-farm/fields/bad-field",
                            headers=farm_headers2)
    assert r.status_code == 400


def test_remove_field_farm_not_found(farm_client2, farm_headers2, monkeypatch):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: None)
    r = farm_client2.delete(f"/api/farms/{farm_id}/fields/{field_id}",
                            headers=farm_headers2)
    assert r.status_code == 404


# ═══════════════════════════════════════════════════════════════════════════════
# forum_controller — upload_media endpoint
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def forum_upload_client(client_for, monkeypatch, current_user):
    from app.controllers.forum_controller import forum_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(forum_bp)


@pytest.fixture
def forum_upload_headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def test_upload_media_no_file(forum_upload_client, forum_upload_headers):
    r = forum_upload_client.post("/api/forum/upload", headers=forum_upload_headers)
    assert r.status_code == 400


def test_upload_media_invalid_ext(forum_upload_client, forum_upload_headers):
    data = {"file": (BytesIO(b"executable"), "virus.exe")}
    r = forum_upload_client.post("/api/forum/upload",
                                 content_type="multipart/form-data",
                                 data=data,
                                 headers=forum_upload_headers)
    assert r.status_code == 400


def test_upload_media_image_success(forum_upload_client, forum_upload_headers, monkeypatch):
    from app.services import storage_service as stor
    monkeypatch.setattr(stor, "upload_image", lambda f: "/uploads/img.jpg")
    # Valid JPEG magic bytes
    jpeg_bytes = b"\xff\xd8\xff\xe0" + b"\x00" * 8
    data = {"file": (BytesIO(jpeg_bytes), "photo.jpg")}
    r = forum_upload_client.post("/api/forum/upload",
                                 content_type="multipart/form-data",
                                 data=data,
                                 headers=forum_upload_headers)
    assert r.status_code == 200
    assert "media_url" in r.get_json()["data"]


def test_upload_media_upload_exception(forum_upload_client, forum_upload_headers, monkeypatch):
    from app.services import storage_service as stor
    monkeypatch.setattr(stor, "upload_image", lambda f: (_ for _ in ()).throw(Exception("upload failed")))
    jpeg_bytes = b"\xff\xd8\xff\xe0" + b"\x00" * 8
    data = {"file": (BytesIO(jpeg_bytes), "photo.jpg")}
    r = forum_upload_client.post("/api/forum/upload",
                                 content_type="multipart/form-data",
                                 data=data,
                                 headers=forum_upload_headers)
    assert r.status_code == 503


def test_upload_media_bad_image_magic(forum_upload_client, forum_upload_headers):
    # .jpg extension but not actually JPEG content
    data = {"file": (BytesIO(b"\xde\xad\xbe\xef" + b"\x00" * 8), "photo.jpg")}
    r = forum_upload_client.post("/api/forum/upload",
                                 content_type="multipart/form-data",
                                 data=data,
                                 headers=forum_upload_headers)
    assert r.status_code == 400


# ═══════════════════════════════════════════════════════════════════════════════
# farm_controller — ownership checks and add_field with location
# ═══════════════════════════════════════════════════════════════════════════════

def test_update_farm_forbidden(farm_client2, farm_headers2, monkeypatch, user_id):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    other_id = str(ObjectId())  # different owner
    fake = {"_id": ObjectId(farm_id), "owner_id": ObjectId(other_id), "name": "Farm X"}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake)
    r = farm_client2.put(f"/api/farms/{farm_id}",
                         json={"name": "Hacked"}, headers=farm_headers2)
    assert r.status_code == 403


def test_delete_farm_forbidden(farm_client2, farm_headers2, monkeypatch, user_id):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    other_id = str(ObjectId())
    fake = {"_id": ObjectId(farm_id), "owner_id": ObjectId(other_id), "name": "Farm X"}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake)
    r = farm_client2.delete(f"/api/farms/{farm_id}", headers=farm_headers2)
    assert r.status_code == 403


def test_add_field_invalid_farm_id(farm_client2, farm_headers2):
    r = farm_client2.post("/api/farms/not-valid/fields",
                          json={"name": "North"}, headers=farm_headers2)
    assert r.status_code == 400


def test_add_field_farm_not_found(farm_client2, farm_headers2, monkeypatch):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: None)
    r = farm_client2.post(f"/api/farms/{farm_id}/fields",
                          json={"name": "North"}, headers=farm_headers2)
    assert r.status_code == 404


def test_add_field_forbidden(farm_client2, farm_headers2, monkeypatch, user_id):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    other_id = str(ObjectId())
    fake = {"_id": ObjectId(farm_id), "owner_id": ObjectId(other_id)}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake)
    r = farm_client2.post(f"/api/farms/{farm_id}/fields",
                          json={"name": "North"}, headers=farm_headers2)
    assert r.status_code == 403


def test_add_field_with_location_weather(farm_client2, farm_headers2, monkeypatch, user_id):
    from app.models import farm_model as fm
    from app.services import cache, insights_service as ins
    farm_id = str(ObjectId())
    field_id = ObjectId()
    fake_farm = {"_id": ObjectId(farm_id), "owner_id": ObjectId(user_id)}
    fake_field = {"field_id": field_id, "name": "South", "crop_type": "wheat"}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake_farm)
    monkeypatch.setattr(fm, "add_field", lambda *a, **kw: fake_field)
    monkeypatch.setattr(fm, "update_field", lambda fid, fiid, data: None)
    monkeypatch.setattr(fm, "get_field", lambda fid, fiid: fake_field)
    monkeypatch.setattr(fm, "serialize_field", lambda f: {"id": str(f["field_id"])})
    monkeypatch.setattr(ins, "build_weather", lambda loc, **kw: {"temp": 28})
    monkeypatch.setattr(cache, "delete", lambda key: None)
    r = farm_client2.post(f"/api/farms/{farm_id}/fields",
                          json={"name": "South", "location": {"lat": 30.0, "lng": 31.0}},
                          headers=farm_headers2)
    assert r.status_code == 201


def test_update_field_forbidden(farm_client2, farm_headers2, monkeypatch, user_id):
    from app.models import farm_model as fm
    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    other_id = str(ObjectId())
    fake_farm = {"_id": ObjectId(farm_id), "owner_id": ObjectId(other_id)}
    monkeypatch.setattr(fm, "get_farm_by_id", lambda fid: fake_farm)
    r = farm_client2.put(f"/api/farms/{farm_id}/fields/{field_id}",
                         json={"name": "X"}, headers=farm_headers2)
    assert r.status_code == 403


# ═══════════════════════════════════════════════════════════════════════════════
# scan_controller — upload_scan validation paths
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def scan_upload_client(client_for, monkeypatch, current_user):
    import app.controllers.scan_controller as scc
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    monkeypatch.setattr(scc, "can_scan", lambda user: (True, ""))
    return client_for(scc.scan_bp)


@pytest.fixture
def scan_headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def test_upload_scan_bad_magic_image(scan_upload_client, scan_headers):
    """Image with wrong magic bytes returns 400."""
    # .jpg extension but random content
    data = {"image": (BytesIO(b"\xde\xad\xbe\xef" + b"\x00" * 8), "photo.jpg")}
    r = scan_upload_client.post("/api/scans",
                                content_type="multipart/form-data",
                                data=data, headers=scan_headers)
    assert r.status_code == 400


def test_upload_scan_bad_ext_image(scan_upload_client, scan_headers):
    """Image with disallowed extension returns 400."""
    data = {"image": (BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 8), "photo.bmp")}
    r = scan_upload_client.post("/api/scans",
                                content_type="multipart/form-data",
                                data=data, headers=scan_headers)
    assert r.status_code == 400


def test_upload_scan_bad_magic_video(scan_upload_client, scan_headers):
    """Video with wrong magic bytes returns 400."""
    data = {"video": (BytesIO(b"\xde\xad\xbe\xef" + b"\x00" * 8), "clip.mp4")}
    r = scan_upload_client.post("/api/scans",
                                content_type="multipart/form-data",
                                data=data, headers=scan_headers)
    assert r.status_code == 400


def test_upload_scan_bad_ext_video(scan_upload_client, scan_headers):
    """Video with disallowed extension returns 400."""
    data = {"video": (BytesIO(b"\x00\x00\x00\x00ftyp" + b"\x00" * 4), "clip.flv")}
    r = scan_upload_client.post("/api/scans",
                                content_type="multipart/form-data",
                                data=data, headers=scan_headers)
    assert r.status_code == 400


def test_upload_scan_invalid_farm_id(scan_upload_client, scan_headers):
    """Invalid farm_id in form returns 400."""
    jpeg_bytes = b"\xff\xd8\xff\xe0" + b"\x00" * 8
    data = {
        "image": (BytesIO(jpeg_bytes), "photo.jpg"),
        "farm_id": "not-a-valid-id",
    }
    r = scan_upload_client.post("/api/scans",
                                content_type="multipart/form-data",
                                data=data, headers=scan_headers)
    assert r.status_code == 400


def test_upload_scan_invalid_field_id(scan_upload_client, scan_headers):
    """Invalid field_id in form returns 400."""
    jpeg_bytes = b"\xff\xd8\xff\xe0" + b"\x00" * 8
    data = {
        "image": (BytesIO(jpeg_bytes), "photo.jpg"),
        "field_id": "not-a-valid-id",
    }
    r = scan_upload_client.post("/api/scans",
                                content_type="multipart/form-data",
                                data=data, headers=scan_headers)
    assert r.status_code == 400
