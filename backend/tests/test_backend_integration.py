from io import BytesIO

from bson import ObjectId


def test_auth_verify_otp_creates_user_and_returns_token(client_for, monkeypatch):
    from app.controllers.auth_controller import auth_bp
    from app.controllers import auth_controller

    created_id = ObjectId()
    created_user = {"_id": created_id, "phone": "+201001234567", "language": "ar"}

    monkeypatch.setattr(auth_controller.auth_service, "check_verify_rate_limit", lambda phone: True)
    monkeypatch.setattr(auth_controller.auth_service, "verify_otp", lambda phone, code: True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_phone", lambda phone: None)
    monkeypatch.setattr(auth_controller.user_model, "create_user", lambda **kwargs: created_user)
    monkeypatch.setattr(auth_controller.audit_model, "log_action", lambda *args, **kwargs: None)

    client = client_for(auth_bp)
    response = client.post(
        "/api/auth/verify-otp",
        json={
            "phone": "01001234567",
            "code": "123456",
            "name": "QA Farmer",
            "country": "egypt",
        },
    )

    assert response.status_code == 200
    body = response.get_json()
    assert body["status"] == "ok"
    assert body["data"]["user"]["id"] == str(created_id)
    assert body["data"]["token"]


def test_auth_send_otp_rejects_invalid_phone(client_for):
    from app.controllers.auth_controller import auth_bp

    client = client_for(auth_bp)
    response = client.post("/api/auth/send-otp", json={"phone": "+14155552671"})

    assert response.status_code == 400
    assert "Invalid Egyptian phone number" in response.get_json()["message"]


def test_farm_create_validates_name_and_persists_farm(client_for, auth_headers, current_user, monkeypatch):
    from app.controllers.farm_controller import farm_bp
    from app.controllers import farm_controller

    farm_id = ObjectId()
    created = {
        "_id": farm_id,
        "owner_id": current_user["_id"],
        "name": "Main Farm",
        "location": {"lat": 30.1, "lng": 31.2},
        "fields": [],
    }

    monkeypatch.setattr(farm_controller.farm_model, "create_farm", lambda *args, **kwargs: created)
    monkeypatch.setattr(farm_controller.farm_model, "update_farm", lambda *args, **kwargs: True)
    monkeypatch.setattr(farm_controller.farm_model, "get_farm_by_id", lambda _id: created)
    monkeypatch.setattr(farm_controller.user_model, "add_farm_ref", lambda *args, **kwargs: True)
    monkeypatch.setattr(farm_controller.insights_service, "build_weather", lambda location: {"source": "test"})
    monkeypatch.setattr(farm_controller.cache, "delete", lambda key: None)
    monkeypatch.setattr(farm_controller.audit_model, "log_action", lambda *args, **kwargs: None)

    client = client_for(farm_bp)

    bad = client.post("/api/farms", json={"name": "   "}, headers=auth_headers)
    good = client.post(
        "/api/farms",
        json={"name": "Main Farm", "location": {"lat": 30.1, "lng": 31.2}},
        headers=auth_headers,
    )

    assert bad.status_code == 400
    assert good.status_code == 201
    assert good.get_json()["data"]["farm"]["id"] == str(farm_id)


def test_scan_upload_processes_unhealthy_detection_and_alerts(
    client_for,
    auth_headers,
    current_user,
    monkeypatch,
):
    from app.controllers.scan_controller import scan_bp
    from app.controllers import scan_controller

    scan_id = ObjectId()
    stored = {
        "_id": scan_id,
        "user_id": current_user["_id"],
        "media_url": "/uploads/leaf.jpg",
        "image_url": "/uploads/leaf.jpg",
        "status": "pending",
        "crop_type": "tomato",
        "detection_result": None,
    }
    notifications = []
    events = []

    monkeypatch.setattr(scan_controller.storage_service, "upload_image", lambda file_obj: "/uploads/leaf.jpg")
    monkeypatch.setattr(scan_controller.storage_service, "get_storage_backend", lambda: "local")
    monkeypatch.setattr(scan_controller.storage_service, "resolve_local_path", lambda url: None)
    monkeypatch.setattr(scan_controller, "can_scan", lambda user: (True, ""))
    monkeypatch.setattr(scan_controller.scan_model, "create_scan", lambda **kwargs: stored)
    monkeypatch.setattr(scan_controller.scan_model, "update_status", lambda _id, status: stored.update(status=status) or True)
    monkeypatch.setattr(
        scan_controller.scan_model,
        "update_detection_result",
        lambda _id, detection: stored.update(status="completed", detection_result=detection) or True,
    )
    monkeypatch.setattr(scan_controller.scan_model, "update_scan", lambda _id, updates: stored.update(updates) or True)
    monkeypatch.setattr(scan_controller.scan_model, "get_scan_by_id", lambda _id: stored)
    monkeypatch.setattr(scan_controller.scan_model, "get_scans_by_user", lambda *args, **kwargs: [stored])
    monkeypatch.setattr(
        scan_controller.detection_proxy_service,
        "detect",
        lambda image, crop: {
            "disease": "Tomato Late Blight",
            "severity": "high",
            "is_healthy": False,
            "risk_level": "high",
        },
    )
    monkeypatch.setattr(scan_controller.notification_model, "create_notification", lambda *args, **kwargs: notifications.append(args) or {})
    monkeypatch.setattr(scan_controller.audit_model, "log_action", lambda *args, **kwargs: None)
    monkeypatch.setattr(scan_controller.event_publisher, "scan_created", lambda *args: events.append(("created", args)))
    monkeypatch.setattr(scan_controller.event_publisher, "scan_completed", lambda *args, **kwargs: events.append(("completed", args)))
    monkeypatch.setattr(scan_controller.event_publisher, "disease_detected", lambda *args: events.append(("disease", args)))
    monkeypatch.setattr(scan_controller.event_publisher, "risk_high", lambda *args: events.append(("risk", args)))

    client = client_for(scan_bp)
    response = client.post(
        "/api/scans",
        data={"image": (BytesIO(b'\xff\xd8\xff\xe0' + b'\x00' * 100), "leaf.jpg"), "crop_type": "tomato"},
        content_type="multipart/form-data",
        headers=auth_headers,
    )

    assert response.status_code == 201
    body = response.get_json()
    assert body["data"]["scan"]["status"] == "completed"
    assert body["data"]["scan"]["detection_result"]["disease"] == "Tomato Late Blight"
    assert len(notifications) == 1
    assert {event[0] for event in events} >= {"created", "completed", "disease"}


def test_scan_upload_rejects_missing_and_invalid_files(client_for, auth_headers, monkeypatch):
    from app.controllers.scan_controller import scan_bp
    from app.controllers import scan_controller

    monkeypatch.setattr(scan_controller, "can_scan", lambda user: (True, ""))

    client = client_for(scan_bp)

    missing = client.post("/api/scans", data={}, headers=auth_headers)
    invalid = client.post(
        "/api/scans",
        data={"image": (BytesIO(b"bad"), "leaf.gif")},
        content_type="multipart/form-data",
        headers=auth_headers,
    )

    assert missing.status_code == 400
    assert invalid.status_code == 400


def test_scan_upload_returns_validation_failure(
    client_for,
    auth_headers,
    current_user,
    monkeypatch,
):
    from app.controllers.scan_controller import scan_bp
    from app.controllers import scan_controller

    scan_id = ObjectId()
    stored = {
        "_id": scan_id,
        "user_id": current_user["_id"],
        "media_url": "/uploads/leaf.jpg",
        "image_url": "/uploads/leaf.jpg",
        "status": "pending",
        "crop_type": "potato",
        "detection_result": None,
    }
    validation = {
        "error_code": "CROP_MISMATCH",
        "selected_crop": "potato",
        "detected_crop": "tomato",
        "message": "This appears to be Tomato, not Potato.",
    }

    monkeypatch.setattr(scan_controller.storage_service, "upload_image", lambda file_obj: "/uploads/leaf.jpg")
    monkeypatch.setattr(scan_controller.storage_service, "get_storage_backend", lambda: "local")
    monkeypatch.setattr(scan_controller.storage_service, "resolve_local_path", lambda url: None)
    monkeypatch.setattr(scan_controller, "can_scan", lambda user: (True, ""))
    monkeypatch.setattr(scan_controller.scan_model, "create_scan", lambda **kwargs: stored)
    monkeypatch.setattr(scan_controller.scan_model, "update_status", lambda _id, status: stored.update(status=status) or True)
    monkeypatch.setattr(scan_controller.scan_model, "update_scan", lambda _id, updates: stored.update(updates) or True)
    monkeypatch.setattr(scan_controller.scan_model, "get_scan_by_id", lambda _id: stored)
    monkeypatch.setattr(
        scan_controller.detection_proxy_service,
        "detect",
        lambda *args: (_ for _ in ()).throw(
            scan_controller.detection_proxy_service.DetectionValidationError(validation)
        ),
    )
    monkeypatch.setattr(scan_controller.audit_model, "log_action", lambda *args, **kwargs: None)
    monkeypatch.setattr(scan_controller.event_publisher, "scan_created", lambda *args: None)

    response = client_for(scan_bp).post(
        "/api/scans",
        data={"image": (BytesIO(b'\xff\xd8\xff\xe0' + b'\x00' * 100), "leaf.jpg"), "crop_type": "potato"},
        content_type="multipart/form-data",
        headers=auth_headers,
    )

    body = response.get_json()
    assert response.status_code == 422
    assert body["error_code"] == "CROP_MISMATCH"
    assert body["data"]["scan"]["status"] == "validation_failed"
    assert body["data"]["validation"]["detected_crop"] == "tomato"


def test_notifications_device_token_validation_and_registration(
    client_for,
    auth_headers,
    current_user,
    monkeypatch,
):
    from app.controllers.notification_controller import notifications_bp
    from app.controllers import notification_controller

    current_user["fcm_tokens"] = ["abc"]
    monkeypatch.setattr(notification_controller.user_model, "add_fcm_token", lambda user_id, token: current_user["fcm_tokens"].append(token) or True)
    monkeypatch.setattr(notification_controller.user_model, "find_by_id", lambda user_id: current_user)

    client = client_for(notifications_bp)
    bad = client.post("/api/notifications/device-token", json={"token": " "}, headers=auth_headers)
    good = client.post("/api/notifications/device-token", json={"token": "xyz"}, headers=auth_headers)

    assert bad.status_code == 400
    assert good.status_code == 200
    assert good.get_json()["data"]["fcm_token_count"] == 2


def test_public_chatbot_rejects_empty_message_and_answers_crop_question(client_for):
    from app.controllers.chatbot_controller import chatbot_bp

    client = client_for(chatbot_bp)
    bad = client.post("/api/chatbot-test", json={"message": " "})
    good = client.post("/api/chatbot-test", json={"message": "tomato disease"})

    assert bad.status_code == 400
    assert good.status_code == 200
    assert "Tomatoes are commonly affected" in good.get_json()["data"]["message"]["reply"]
