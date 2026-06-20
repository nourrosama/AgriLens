"""
detection_proxy_service + report_controller (_build_pdf) coverage.
"""
import pytest
from unittest.mock import MagicMock, patch
from bson import ObjectId
import io


# ═══════════════════════════════════════════════════════════════════════════════
# detection_proxy_service — unit tests (no HTTP, no Flask app context needed)
# ═══════════════════════════════════════════════════════════════════════════════

import app.services.detection_proxy_service as dps


def test_normalize_crop_basic():
    assert dps._normalize_crop("Tomato") == "tomato"
    assert dps._normalize_crop("WHEAT") == "wheat"
    assert dps._normalize_crop("") == "tomato"


def test_normalize_crop_aliases():
    assert dps._normalize_crop("tomatoes") == "tomato"
    assert dps._normalize_crop("apples") == "apple"
    assert dps._normalize_crop("grapes") == "grape"
    assert dps._normalize_crop("potatoes") == "potato"
    assert dps._normalize_crop("sugarcanes") == "sugarcane"


def test_normalize_crop_spaces_underscores():
    assert dps._normalize_crop("corn ") == "corn"
    assert dps._normalize_crop("sugar_cane") == "sugarcane"


def test_unsupported_crop_payload():
    payload = dps._unsupported_crop_payload("banana")
    assert payload["error_code"] == "UNSUPPORTED_CROP"
    assert payload["valid"] is False
    assert "banana" in payload["selected_crop"]
    assert "supported_crops" in payload
    assert "tomato" in payload["supported_crops"]


def test_mock_detect_tomato():
    result = dps._mock_detect("scan_test.jpg", "tomato")
    assert result["crop_type"] == "tomato"
    assert "disease" in result
    assert "confidence" in result
    assert "is_healthy" in result
    assert "gradcam_overlay" in result
    assert 0.74 <= result["confidence"] <= 1.0


def test_mock_detect_wheat():
    result = dps._mock_detect("/path/to/image.png", "wheat")
    assert result["crop_type"] == "wheat"
    assert "severity" in result
    assert "recommendation" in result


def test_mock_detect_all_supported_crops():
    for crop in ["tomato", "apple", "potato", "corn", "wheat", "grape", "sugarcane", "cotton"]:
        result = dps._mock_detect("img.jpg", crop)
        assert result["crop_type"] == crop


def test_mock_detect_unsupported_crop_raises():
    with pytest.raises(dps.DetectionValidationError) as exc_info:
        dps._mock_detect("img.jpg", "banana")
    assert exc_info.value.payload["error_code"] == "UNSUPPORTED_CROP"
    assert exc_info.value.status_code == 422


def test_mock_gradcam_b64_returns_png():
    import base64
    result = dps._mock_gradcam_b64(12345)
    raw = base64.b64decode(result)
    assert raw[:8] == b'\x89PNG\r\n\x1a\n'


def test_mock_gradcam_b64_varies_by_seed():
    r1 = dps._mock_gradcam_b64(1)
    r2 = dps._mock_gradcam_b64(2)
    assert r1 != r2


def test_detection_validation_error_message():
    err = dps.DetectionValidationError({"message": "not a plant"}, 422)
    assert "not a plant" in str(err)
    assert err.status_code == 422


def test_detection_validation_error_fallback_message():
    err = dps.DetectionValidationError({"error": "crop mismatch"}, 422)
    assert "crop mismatch" in str(err)


def test_detection_validation_error_default_message():
    err = dps.DetectionValidationError({}, 422)
    assert "validation" in str(err).lower()


def test_content_type_for_png():
    assert dps._content_type_for("image.png") == "image/png"


def test_content_type_for_webp():
    assert dps._content_type_for("photo.webp") == "image/webp"


def test_content_type_for_jpeg():
    assert dps._content_type_for("photo.jpg") == "image/jpeg"
    assert dps._content_type_for("photo.PNG.jpg") == "image/jpeg"


def test_safe_json_valid():
    mock_resp = MagicMock()
    mock_resp.json.return_value = {"error": "oops"}
    assert dps._safe_json(mock_resp) == {"error": "oops"}


def test_safe_json_invalid_json():
    mock_resp = MagicMock()
    mock_resp.json.side_effect = ValueError("not json")
    assert dps._safe_json(mock_resp) == {}


def test_safe_json_non_dict():
    mock_resp = MagicMock()
    mock_resp.json.return_value = ["a", "b"]
    assert dps._safe_json(mock_resp) == {}


def test_parse_sagemaker_endpoints_empty():
    assert dps._parse_sagemaker_endpoints("") == {}


def test_parse_sagemaker_endpoints_json():
    raw = '{"tomato": "endpoint-tomato-v1", "wheat": "endpoint-wheat-v2"}'
    result = dps._parse_sagemaker_endpoints(raw)
    assert result["tomato"] == "endpoint-tomato-v1"
    assert result["wheat"] == "endpoint-wheat-v2"


def test_parse_sagemaker_endpoints_csv():
    raw = "tomato=endpoint-tomato,wheat=endpoint-wheat"
    result = dps._parse_sagemaker_endpoints(raw)
    assert result["tomato"] == "endpoint-tomato"
    assert result["wheat"] == "endpoint-wheat"


def test_parse_sagemaker_endpoints_invalid_json_falls_to_csv():
    raw = "tomato=endpoint-A,corn=endpoint-B"
    result = dps._parse_sagemaker_endpoints(raw)
    assert result["tomato"] == "endpoint-A"
    assert result["corn"] == "endpoint-B"


def test_parse_sagemaker_endpoints_csv_no_equals():
    raw = "no-equals-sign"
    result = dps._parse_sagemaker_endpoints(raw)
    assert result == {}


def test_parse_sagemaker_endpoints_csv_empty_endpoint():
    raw = "tomato="  # empty endpoint
    result = dps._parse_sagemaker_endpoints(raw)
    assert "tomato" not in result


# ── detect() with Flask app context ───────────────────────────────────────────

def test_detect_local_provider_success(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_PROVIDER"] = "local"
        flask_app.config["DETECTION_SERVICE_URL"] = "http://localhost:5001"
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {"disease": "Blight", "is_healthy": False}
        with patch("requests.post", return_value=mock_resp):
            result = dps.detect("http://example.com/img.jpg", "tomato")
        assert result["disease"] == "Blight"


def test_detect_local_provider_422_validation_error(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_PROVIDER"] = "local"
        mock_resp = MagicMock()
        mock_resp.status_code = 422
        mock_resp.json.return_value = {
            "error_code": "NOT_A_PLANT",
            "message": "Not a plant image",
        }
        with patch("requests.post", return_value=mock_resp):
            with pytest.raises(dps.DetectionValidationError):
                dps.detect("http://example.com/img.jpg", "tomato")


def test_detect_local_provider_connection_error(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_PROVIDER"] = "local"
        flask_app.config["DETECTION_MOCK_FALLBACK"] = False
        import requests
        with patch("requests.post", side_effect=requests.ConnectionError()):
            result = dps.detect("http://example.com/img.jpg", "tomato")
        assert result is None


def test_detect_local_provider_with_file_path(flask_app, tmp_path):
    img_path = tmp_path / "test.jpg"
    img_path.write_bytes(b"\xff\xd8\xff" + b"\x00" * 100)
    with flask_app.app_context():
        flask_app.config["DETECTION_PROVIDER"] = "local"
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {"disease": "Rust", "is_healthy": False}
        with patch("requests.post", return_value=mock_resp):
            result = dps.detect(str(img_path), "wheat")
        assert result is not None


def test_detect_falls_back_to_mock(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_PROVIDER"] = "local"
        flask_app.config["DETECTION_MOCK_FALLBACK"] = True
        import requests
        with patch("requests.post", side_effect=requests.ConnectionError()):
            result = dps.detect("http://example.com/img.jpg", "tomato")
        assert result is not None
        assert result["model_version"] == "mock-fallback-v1"


def test_detect_sagemaker_provider(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_PROVIDER"] = "sagemaker"
        flask_app.config["SAGEMAKER_ENDPOINT_NAME"] = "my-endpoint"
        flask_app.config["SAGEMAKER_ENDPOINTS"] = ""
        flask_app.config["DETECTION_MOCK_FALLBACK"] = False

        mock_client = MagicMock()
        mock_body = MagicMock()
        mock_body.read.return_value = b'{"disease": "Blight", "is_healthy": false}'
        mock_client.invoke_endpoint.return_value = {"Body": mock_body}

        with patch("app.services.detection_proxy_service._sagemaker_runtime_client",
                   return_value=mock_client):
            with patch("os.path.exists", return_value=False):
                with patch("requests.get") as mock_get:
                    mock_get.return_value.content = b"\xff\xd8\xff\x00"
                    mock_get.return_value.headers = {}
                    mock_get.return_value.raise_for_status = lambda: None
                    result = dps.detect("http://example.com/img.jpg", "tomato")
        assert result is not None


def test_detect_sagemaker_no_endpoint(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_PROVIDER"] = "sagemaker"
        flask_app.config["SAGEMAKER_ENDPOINT_NAME"] = ""
        flask_app.config["SAGEMAKER_ENDPOINTS"] = ""
        flask_app.config["DETECTION_MOCK_FALLBACK"] = False
        result = dps.detect("http://example.com/img.jpg", "tomato")
        assert result is None


def test_detect_sagemaker_exception(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_PROVIDER"] = "sagemaker"
        flask_app.config["SAGEMAKER_ENDPOINT_NAME"] = "my-endpoint"
        flask_app.config["SAGEMAKER_ENDPOINTS"] = ""
        flask_app.config["DETECTION_MOCK_FALLBACK"] = False

        with patch("app.services.detection_proxy_service._sagemaker_runtime_client",
                   side_effect=Exception("boto3 error")):
            result = dps.detect("http://example.com/img.jpg", "tomato")
        assert result is None


def test_detect_local_non_200_non_422(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_PROVIDER"] = "local"
        flask_app.config["DETECTION_MOCK_FALLBACK"] = False
        mock_resp = MagicMock()
        mock_resp.status_code = 500
        mock_resp.text = "Internal Server Error"
        with patch("requests.post", return_value=mock_resp):
            result = dps.detect("http://example.com/img.jpg", "tomato")
        assert result is None


def test_detect_local_generic_exception(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_PROVIDER"] = "local"
        flask_app.config["DETECTION_MOCK_FALLBACK"] = False
        with patch("requests.post", side_effect=Exception("socket timeout")):
            result = dps.detect("http://example.com/img.jpg", "tomato")
        assert result is None


def test_select_video_keyframes_file_not_found(flask_app):
    with flask_app.app_context():
        result = dps.select_video_keyframes("/nonexistent/path.mp4")
        assert result is None


def test_select_video_keyframes_success(flask_app, tmp_path):
    vid_path = tmp_path / "test.mp4"
    vid_path.write_bytes(b"fake-mp4-data")
    with flask_app.app_context():
        flask_app.config["DETECTION_SERVICE_URL"] = "http://localhost:5001"
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {"keyframes": [0, 5, 10]}
        with patch("requests.post", return_value=mock_resp):
            result = dps.select_video_keyframes(str(vid_path))
        assert result["keyframes"] == [0, 5, 10]


def test_select_video_keyframes_non_200(flask_app, tmp_path):
    vid_path = tmp_path / "test.mp4"
    vid_path.write_bytes(b"fake-mp4-data")
    with flask_app.app_context():
        flask_app.config["DETECTION_SERVICE_URL"] = "http://localhost:5001"
        mock_resp = MagicMock()
        mock_resp.status_code = 500
        mock_resp.text = "error"
        with patch("requests.post", return_value=mock_resp):
            result = dps.select_video_keyframes(str(vid_path))
        assert result is None


def test_select_video_keyframes_exception(flask_app, tmp_path):
    vid_path = tmp_path / "test.mp4"
    vid_path.write_bytes(b"fake-mp4-data")
    with flask_app.app_context():
        flask_app.config["DETECTION_SERVICE_URL"] = "http://localhost:5001"
        with patch("requests.post", side_effect=Exception("connection error")):
            result = dps.select_video_keyframes(str(vid_path))
        assert result is None


def test_image_bytes_for_sagemaker_local(tmp_path, flask_app):
    img = tmp_path / "img.jpg"
    img.write_bytes(b"\xff\xd8\xff\x00")
    with flask_app.app_context():
        data, ctype = dps._image_bytes_for_sagemaker(str(img))
    assert data == b"\xff\xd8\xff\x00"
    assert ctype == "image/jpeg"


def test_image_bytes_for_sagemaker_url(flask_app):
    with flask_app.app_context():
        mock_resp = MagicMock()
        mock_resp.content = b"\x89PNG\r\n\x1a\n"
        mock_resp.headers = {"Content-Type": "image/png"}
        mock_resp.raise_for_status = lambda: None
        with patch("os.path.exists", return_value=False):
            with patch("requests.get", return_value=mock_resp):
                data, ctype = dps._image_bytes_for_sagemaker("http://example.com/img.png")
    assert data == b"\x89PNG\r\n\x1a\n"
    assert ctype == "image/png"


def test_mock_fallback_enabled_true(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_MOCK_FALLBACK"] = True
        assert dps._mock_fallback_enabled() is True


def test_mock_fallback_enabled_false(flask_app):
    with flask_app.app_context():
        flask_app.config["DETECTION_MOCK_FALLBACK"] = False
        assert dps._mock_fallback_enabled() is False


def test_sagemaker_endpoint_for_crop(flask_app):
    with flask_app.app_context():
        flask_app.config["SAGEMAKER_ENDPOINTS"] = '{"tomato": "tomato-endpoint-v1"}'
        flask_app.config["SAGEMAKER_ENDPOINT_NAME"] = ""
        result = dps._sagemaker_endpoint_for("tomato")
        assert result == "tomato-endpoint-v1"


def test_sagemaker_endpoint_for_fallback(flask_app):
    with flask_app.app_context():
        flask_app.config["SAGEMAKER_ENDPOINTS"] = ""
        flask_app.config["SAGEMAKER_ENDPOINT_NAME"] = "default-endpoint"
        result = dps._sagemaker_endpoint_for("banana")  # not in catalog
        assert result == "default-endpoint"


# ═══════════════════════════════════════════════════════════════════════════════
# report_controller — _build_pdf direct tests
# ═══════════════════════════════════════════════════════════════════════════════

def test_build_pdf_basic(flask_app):
    from app.controllers.report_controller import _build_pdf
    user = {"name": "Ahmed", "_id": ObjectId(), "plan": "professional"}
    farms = [{"name": "Test Farm", "fields": [], "crop_type": "wheat", "area_hectares": 10}]
    scans = []
    summary = {"total_scans": 0, "disease_rate": 0}

    with flask_app.app_context():
        pdf = _build_pdf(user, "monthly", farms, scans, summary)
    assert isinstance(pdf, bytes)
    assert pdf[:4] == b'%PDF'


def test_build_pdf_with_scans(flask_app):
    from app.controllers.report_controller import _build_pdf
    user = {"name": "Farmer", "_id": ObjectId(), "plan": "professional"}
    farms = []
    scans = [
        {
            "crop_type": "wheat",
            "created_at": "2025-06-01T10:00:00",
            "detection_result": {
                "disease": "Wheat Rust",
                "is_healthy": False,
                "confidence": 0.85,
                "severity": "medium",
            }
        },
        {
            "crop_type": "tomato",
            "created_at": "2025-06-02T10:00:00",
            "detection_result": {
                "disease": "Leaf Blight",
                "is_healthy": False,
                "confidence": 0.9,
                "severity": "high",
            }
        },
    ]
    summary = {"total_scans": 2, "disease_rate": 100}

    with flask_app.app_context():
        pdf = _build_pdf(user, "weekly", farms, scans, summary)
    assert pdf[:4] == b'%PDF'


def test_build_pdf_healthy_scans(flask_app):
    from app.controllers.report_controller import _build_pdf
    user = {"name": "Farmer", "_id": ObjectId()}
    farms = [{"name": "Farm A", "fields": [1, 2], "crop_type": "corn", "area_hectares": 5}]
    scans = [
        {
            "crop_type": "corn",
            "created_at": "2025-06-01T10:00:00",
            "detection_result": {"is_healthy": True, "confidence": 0.95},
        }
    ]
    summary = {}
    with flask_app.app_context():
        pdf = _build_pdf(user, "yearly", farms, scans, summary)
    assert len(pdf) > 100


def test_build_pdf_many_scans(flask_app):
    from app.controllers.report_controller import _build_pdf
    user = {"name": "Mega Farmer"}
    farms = []
    # More than 10 scans to exercise the [:10] slice
    scans = [
        {
            "crop_type": f"crop{i}",
            "created_at": f"2025-06-{i+1:02d}T10:00:00",
            "detection_result": {"disease": f"Disease {i}", "is_healthy": i % 3 == 0,
                                 "confidence": 0.8, "severity": "medium"}
        }
        for i in range(15)
    ]
    summary = {}
    with flask_app.app_context():
        pdf = _build_pdf(user, "monthly", farms, scans, summary)
    assert pdf[:4] == b'%PDF'


def test_build_pdf_no_user_name(flask_app):
    from app.controllers.report_controller import _build_pdf
    user = {}  # no name key
    with flask_app.app_context():
        pdf = _build_pdf(user, "monthly", [], [], {})
    assert pdf[:4] == b'%PDF'


def test_build_pdf_no_disease_section_when_all_healthy(flask_app):
    from app.controllers.report_controller import _build_pdf
    user = {"name": "Farmer"}
    scans = [
        {"crop_type": "wheat", "created_at": "2025-06-01",
         "detection_result": {"is_healthy": True, "confidence": 0.99}}
    ]
    with flask_app.app_context():
        pdf = _build_pdf(user, "monthly", [], scans, {})
    assert pdf[:4] == b'%PDF'
