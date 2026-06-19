import json
from datetime import datetime, timezone
from io import BytesIO

import jwt
from bson import ObjectId

from conftest import make_token


class FakeResult:
    def __init__(self, inserted_id=None, modified_count=1, deleted_count=1):
        self.inserted_id = inserted_id or ObjectId()
        self.modified_count = modified_count
        self.deleted_count = deleted_count


class FakeCursor:
    def __init__(self, docs):
        self.docs = list(docs)

    def sort(self, *args):
        return self

    def skip(self, count):
        self.docs = self.docs[count:]
        return self

    def limit(self, count):
        self.docs = self.docs[:count]
        return self

    def __iter__(self):
        return iter(self.docs)


class FakeCollection:
    def __init__(self, docs=None):
        self.docs = list(docs or [])
        self.inserted = []
        self.updated = []
        self.deleted = []

    def insert_one(self, doc):
        inserted_id = doc.get("_id", ObjectId())
        self.inserted.append(doc)
        return FakeResult(inserted_id=inserted_id)

    def find_one(self, query):
        for doc in self.docs:
            if all(doc.get(key) == value for key, value in query.items()):
                return doc
        return None

    def find(self, query):
        return FakeCursor(
            doc for doc in self.docs if all(doc.get(key) == value for key, value in query.items())
        )

    def update_one(self, query, update, upsert=False):
        self.updated.append((query, update, upsert))
        return FakeResult(modified_count=1)

    def update_many(self, query, update):
        self.updated.append((query, update, False))
        return FakeResult(modified_count=3)

    def delete_one(self, query):
        self.deleted.append(query)
        return FakeResult(deleted_count=1)

    def count_documents(self, query):
        return 2


def test_create_app_registers_blueprints_and_error_handlers(monkeypatch):
    from app import main
    from app.models import db
    from app.observers import event_publisher
    from app.services import auth_service, cache, storage_service

    monkeypatch.setattr(db, "init_db", lambda app: None)
    monkeypatch.setattr(auth_service, "init_auth_service", lambda app: None)
    monkeypatch.setattr(storage_service, "init_storage", lambda app: None)
    monkeypatch.setattr(storage_service, "uses_local_storage", lambda: False)
    monkeypatch.setattr(cache, "init_cache", lambda app: None)
    monkeypatch.setattr(event_publisher, "init_publisher", lambda app: None)
    monkeypatch.setattr(main, "Swagger", lambda *args, **kwargs: None)

    app = main.create_app()

    response = app.test_client().get("/missing")

    assert "auth.send_otp" in app.view_functions
    assert "scans.upload_scan" in app.view_functions
    assert response.status_code == 404
    assert response.get_json()["message"] == "Resource not found"


def test_auth_profile_get_and_update_paths(client_for, auth_headers, current_user, monkeypatch):
    from app.controllers.auth_controller import auth_bp
    from app.controllers import auth_controller

    updated_user = dict(current_user, name="Updated", language="ar", profile_completed=True)
    calls = []
    monkeypatch.setattr(auth_controller.user_model, "update_user", lambda user_id, updates: calls.append(updates) or True)
    monkeypatch.setattr(auth_controller.user_model, "find_by_id", lambda user_id: updated_user)

    client = client_for(auth_bp)

    profile = client.get("/api/auth/me", headers=auth_headers)
    update = client.put(
        "/api/auth/me",
        json={"name": " Updated ", "language": "ar", "role": "admin", "profile_completed": "yes"},
        headers=auth_headers,
    )

    assert profile.status_code == 200
    assert update.status_code == 200
    assert calls[0]["name"] == "Updated"
    assert calls[0]["language"] == "ar"
    assert "role" not in calls[0]
    assert update.get_json()["data"]["user"]["profile_completed"] is True


def test_auth_middleware_rejects_missing_expired_invalid_and_unknown_user(flask_app, monkeypatch):
    from app.middleware.auth_middleware import require_auth, user_model

    @flask_app.route("/protected")
    @require_auth
    def protected():
        return {"ok": True}

    expired = jwt.encode(
        {
            "sub": str(ObjectId()),
            "iat": datetime(2020, 1, 1, tzinfo=timezone.utc),
            "exp": datetime(2020, 1, 2, tzinfo=timezone.utc),
        },
        flask_app.config["JWT_SECRET"],
        algorithm="HS256",
    )
    valid_unknown = make_token(str(ObjectId()))
    monkeypatch.setattr(user_model, "find_by_id", lambda user_id: None)

    client = flask_app.test_client()

    assert client.get("/protected").status_code == 401
    assert client.get("/protected", headers={"Authorization": "Bearer bad"}).get_json()["message"] == "Invalid token"
    assert client.get("/protected", headers={"Authorization": f"Bearer {expired}"}).get_json()["message"] == "Token expired"
    assert client.get("/protected", headers={"Authorization": f"Bearer {valid_unknown}"}).get_json()["message"] == "User not found"


def test_farm_list_get_update_delete_and_field_routes(client_for, auth_headers, current_user, monkeypatch):
    from app.controllers.farm_controller import farm_bp
    from app.controllers import farm_controller

    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    farm = {
        "_id": ObjectId(farm_id),
        "owner_id": current_user["_id"],
        "name": "Main",
        "location": {},
        "fields": [{"field_id": ObjectId(field_id), "name": "Field A", "location": {}}],
    }
    cache_state = {}
    monkeypatch.setattr(farm_controller.cache, "get", lambda key: cache_state.get(key))
    monkeypatch.setattr(farm_controller.cache, "set", lambda key, value, ttl=300: cache_state.update({key: value}))
    monkeypatch.setattr(farm_controller.cache, "delete", lambda key: cache_state.pop(key, None))
    monkeypatch.setattr(farm_controller.farm_model, "get_farms_by_owner", lambda user_id: [farm])
    monkeypatch.setattr(farm_controller.farm_model, "get_farm_by_id", lambda _id: farm)
    monkeypatch.setattr(farm_controller.farm_model, "update_farm", lambda *args, **kwargs: True)
    monkeypatch.setattr(farm_controller.farm_model, "delete_farm", lambda *args, **kwargs: True)
    monkeypatch.setattr(farm_controller.farm_model, "add_field", lambda *args, **kwargs: farm["fields"][0])
    monkeypatch.setattr(farm_controller.farm_model, "get_field", lambda *args, **kwargs: farm["fields"][0])
    monkeypatch.setattr(farm_controller.farm_model, "update_field", lambda *args, **kwargs: True)
    monkeypatch.setattr(farm_controller.farm_model, "remove_field", lambda *args, **kwargs: True)
    monkeypatch.setattr(farm_controller.user_model, "remove_farm_ref", lambda *args, **kwargs: True)
    monkeypatch.setattr(farm_controller.audit_model, "log_action", lambda *args, **kwargs: None)
    monkeypatch.setattr(farm_controller.insights_service, "build_weather", lambda location: {"source": "test"})

    client = client_for(farm_bp)

    assert client.get("/api/farms", headers=auth_headers).status_code == 200
    assert client.get(f"/api/farms/{farm_id}", headers=auth_headers).status_code == 200
    assert client.put(f"/api/farms/{farm_id}", json={"name": "Renamed"}, headers=auth_headers).status_code == 200
    assert client.post(f"/api/farms/{farm_id}/fields", json={"name": "Field A"}, headers=auth_headers).status_code == 201
    assert client.put(f"/api/farms/{farm_id}/fields/{field_id}", json={"crop_type": "tomato"}, headers=auth_headers).status_code == 200
    assert client.delete(f"/api/farms/{farm_id}/fields/{field_id}", headers=auth_headers).status_code == 200
    assert client.delete(f"/api/farms/{farm_id}", headers=auth_headers).status_code == 200
    assert client.get("/api/farms/not-valid", headers=auth_headers).status_code == 400


def test_forbidden_farm_access_is_rejected(client_for, auth_headers, monkeypatch):
    from app.controllers.farm_controller import farm_bp
    from app.controllers import farm_controller

    farm_id = str(ObjectId())
    monkeypatch.setattr(
        farm_controller.farm_model,
        "get_farm_by_id",
        lambda _id: {"_id": ObjectId(farm_id), "owner_id": ObjectId(), "fields": []},
    )

    response = client_for(farm_bp).get(f"/api/farms/{farm_id}", headers=auth_headers)

    assert response.status_code == 403


def test_scan_video_list_get_and_callback_routes(client_for, auth_headers, current_user, monkeypatch):
    from app.controllers.scan_controller import scan_bp
    from app.controllers import scan_controller

    scan_id = str(ObjectId())
    stored = {
        "_id": ObjectId(scan_id),
        "user_id": current_user["_id"],
        "media_url": "/uploads/clip.mp4",
        "image_url": "/uploads/clip.mp4",
        "status": "completed",
        "media_type": "video",
        "scan_type": "video",
    }
    monkeypatch.setattr(scan_controller, "can_scan", lambda user: (True, ""))
    monkeypatch.setattr(scan_controller.storage_service, "upload_video", lambda file_obj: "/uploads/clip.mp4")
    monkeypatch.setattr(scan_controller.storage_service, "get_storage_backend", lambda: "local")
    monkeypatch.setattr(scan_controller.storage_service, "resolve_local_path", lambda url: None)
    monkeypatch.setattr(scan_controller.scan_model, "create_scan", lambda **kwargs: stored)
    monkeypatch.setattr(scan_controller.scan_model, "update_status", lambda _id, status: stored.update(status=status) or True)
    monkeypatch.setattr(scan_controller.scan_model, "update_scan", lambda _id, updates: stored.update(updates) or True)
    monkeypatch.setattr(scan_controller.scan_model, "get_scan_by_id", lambda _id: stored)
    monkeypatch.setattr(scan_controller.scan_model, "get_scans_by_user", lambda *args, **kwargs: [stored])
    monkeypatch.setattr(scan_controller.scan_model, "get_scans_filtered", lambda *args, **kwargs: [stored])
    monkeypatch.setattr(scan_controller.scan_model, "update_detection_result", lambda _id, detection: stored.update(detection_result=detection) or True)
    monkeypatch.setattr(scan_controller.video_service, "analyze_video", lambda *args, **kwargs: {"disease": "Healthy", "severity": "none", "is_healthy": True, "risk_level": "low", "confidence": 0.9})
    monkeypatch.setattr(scan_controller.audit_model, "log_action", lambda *args, **kwargs: None)
    monkeypatch.setattr(scan_controller.event_publisher, "scan_created", lambda *args: None)
    monkeypatch.setattr(scan_controller.event_publisher, "scan_completed", lambda *args, **kwargs: None)
    monkeypatch.setattr(scan_controller.event_publisher, "disease_detected", lambda *args: None)
    monkeypatch.setattr(scan_controller.event_publisher, "risk_high", lambda *args: None)

    client = client_for(scan_bp)
    upload = client.post(
        "/api/scans",
        data={"video": (BytesIO(b"video"), "clip.mp4")},
        content_type="multipart/form-data",
        headers=auth_headers,
    )
    listed = client.get("/api/scans?per_page=150", headers=auth_headers)
    detail = client.get(f"/api/scans/{scan_id}", headers=auth_headers)
    callback = client.post(f"/api/scans/{scan_id}/result", json={"risk_level": "critical", "is_healthy": False})

    assert upload.status_code == 202
    assert listed.get_json()["data"]["per_page"] == 100
    assert detail.status_code == 200
    assert callback.status_code == 200


def test_scan_upload_handles_storage_and_detection_failures(client_for, auth_headers, current_user, monkeypatch):
    from app.controllers.scan_controller import scan_bp
    from app.controllers import scan_controller

    scan_id = str(ObjectId())
    stored = {"_id": ObjectId(scan_id), "user_id": current_user["_id"], "media_url": "/uploads/leaf.jpg", "status": "pending"}

    client = client_for(scan_bp)
    monkeypatch.setattr(scan_controller, "can_scan", lambda user: (True, ""))
    monkeypatch.setattr(
        scan_controller.storage_service,
        "upload_image",
        lambda file_obj: (_ for _ in ()).throw(RuntimeError("disk full")),
    )
    storage_error = client.post(
        "/api/scans",
        data={"image": (BytesIO(b"image"), "leaf.jpg")},
        content_type="multipart/form-data",
        headers=auth_headers,
    )

    monkeypatch.setattr(scan_controller.storage_service, "upload_image", lambda file_obj: "/uploads/leaf.jpg")
    monkeypatch.setattr(scan_controller.storage_service, "get_storage_backend", lambda: "local")
    monkeypatch.setattr(scan_controller.storage_service, "resolve_local_path", lambda url: None)
    monkeypatch.setattr(scan_controller.scan_model, "create_scan", lambda **kwargs: stored)
    monkeypatch.setattr(scan_controller.scan_model, "update_status", lambda *args: True)
    monkeypatch.setattr(scan_controller.scan_model, "update_scan", lambda _id, updates: stored.update(updates) or True)
    monkeypatch.setattr(scan_controller.scan_model, "get_scan_by_id", lambda _id: stored)
    monkeypatch.setattr(scan_controller.detection_proxy_service, "detect", lambda *args: None)
    monkeypatch.setattr(scan_controller.audit_model, "log_action", lambda *args, **kwargs: None)
    monkeypatch.setattr(scan_controller.event_publisher, "scan_created", lambda *args: None)
    detection_error = client.post(
        "/api/scans",
        data={"image": (BytesIO(b"image"), "leaf.jpg")},
        content_type="multipart/form-data",
        headers=auth_headers,
    )

    assert storage_error.status_code == 503
    assert detection_error.status_code == 201
    assert detection_error.get_json()["data"]["scan"]["status"] == "failed"


def test_weather_dashboard_report_and_health_routes(client_for, auth_headers, current_user, monkeypatch):
    from app.controllers.dashboard_controller import dashboard_bp
    from app.controllers.health_controller import health_bp
    from app.controllers.report_controller import reports_bp
    from app.controllers.weather_controller import weather_bp
    from app.controllers import dashboard_controller, report_controller, weather_controller
    import app.controllers.health_controller as health_controller

    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    farm = {
        "_id": ObjectId(farm_id),
        "owner_id": current_user["_id"],
        "location": {"lat": 30.1, "lng": 31.2},
        "fields": [{"field_id": ObjectId(field_id), "location": {"lat": 30.2, "lng": 31.3}}],
    }
    weather = {"source": "test", "forecast": []}

    monkeypatch.setattr(dashboard_controller.insights_service, "build_dashboard_summary", lambda user_id: {"total_farms": 1})
    monkeypatch.setattr(report_controller.farm_model, "get_farms_by_owner", lambda user_id: [farm])
    monkeypatch.setattr(report_controller.scan_model, "get_scans_by_user", lambda *args: [])
    monkeypatch.setattr(report_controller.notification_model, "list_notifications", lambda *args: [])
    monkeypatch.setattr(report_controller.insights_service, "build_dashboard_summary", lambda user_id: {"total_farms": 1})
    monkeypatch.setattr(weather_controller.farm_model, "get_farms_by_owner", lambda user_id: [farm])
    monkeypatch.setattr(weather_controller.farm_model, "get_farm_by_id", lambda _id: farm)
    monkeypatch.setattr(weather_controller.farm_model, "update_farm", lambda *args, **kwargs: True)
    monkeypatch.setattr(weather_controller.farm_model, "update_field", lambda *args, **kwargs: True)
    monkeypatch.setattr(weather_controller.insights_service, "build_weather", lambda location: weather)
    monkeypatch.setattr(health_controller, "get_db_status", lambda: {"mongo_ready": True, "database": "test"})
    monkeypatch.setattr(health_controller, "get_storage_status", lambda: {"provider": "local", "ready": True})

    client = client_for(dashboard_bp, reports_bp, weather_bp, health_bp)

    assert client.get("/api/dashboard/summary", headers=auth_headers).get_json()["data"]["summary"]["total_farms"] == 1
    assert client.get("/api/reports/export?period=daily&format=json", headers=auth_headers).get_json()["data"]["filename"] == "agrilens-daily-report.json"
    assert client.get("/api/weather?lat=30&lng=31", headers=auth_headers).get_json()["data"]["weather"]["source"] == "test"
    assert client.get(f"/api/weather?farm_id={farm_id}&field_id={field_id}", headers=auth_headers).status_code == 200
    assert client.get("/api/health").get_json()["integrations"]["mongo"]["mongo_ready"] is True


def test_weather_rejects_invalid_and_missing_farm_scope(client_for, auth_headers, monkeypatch):
    from app.controllers.weather_controller import weather_bp
    from app.controllers import weather_controller

    monkeypatch.setattr(weather_controller.farm_model, "get_farm_by_id", lambda _id: None)
    client = client_for(weather_bp)

    assert client.get("/api/weather?farm_id=bad", headers=auth_headers).status_code == 400
    assert client.get(f"/api/weather?farm_id={ObjectId()}", headers=auth_headers).status_code == 404


def test_notifications_list_mark_read_mark_all_and_unregister(client_for, auth_headers, current_user, monkeypatch):
    from app.controllers.notification_controller import notifications_bp
    from app.controllers import notification_controller

    notification_id = str(ObjectId())
    notification = {"_id": ObjectId(notification_id), "user_id": current_user["_id"], "title": "T", "message": "M"}
    current_user["fcm_tokens"] = []
    monkeypatch.setattr(notification_controller.notification_model, "list_notifications", lambda *args: [notification])
    monkeypatch.setattr(notification_controller.notification_model, "unread_count", lambda user_id: 1)
    monkeypatch.setattr(notification_controller.notification_model, "mark_as_read", lambda *args: True)
    monkeypatch.setattr(notification_controller.notification_model, "get_notification", lambda _id: dict(notification, is_read=True))
    monkeypatch.setattr(notification_controller.notification_model, "mark_all_as_read", lambda user_id: 3)
    monkeypatch.setattr(notification_controller.user_model, "remove_fcm_token", lambda *args: True)
    monkeypatch.setattr(notification_controller.user_model, "find_by_id", lambda user_id: current_user)

    client = client_for(notifications_bp)

    assert client.get("/api/notifications", headers=auth_headers).get_json()["data"]["unread_count"] == 1
    assert client.put(f"/api/notifications/{notification_id}/read", headers=auth_headers).status_code == 200
    assert client.put("/api/notifications/read-all", headers=auth_headers).get_json()["data"]["updated_count"] == 3
    assert client.delete("/api/notifications/device-token", json={"token": "abc"}, headers=auth_headers).get_json()["data"]["removed"] is True
    assert client.put("/api/notifications/bad/read", headers=auth_headers).status_code == 400


def test_chatbot_authenticated_endpoint(client_for, auth_headers, current_user):
    from app.controllers.chatbot_controller import chatbot_bp

    current_user["plan"] = "premium"
    response = client_for(chatbot_bp).post(
        "/api/chatbot",
        json={"message": "watering schedule"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert "watering schedule" in response.get_json()["data"]["message"]["reply"].lower()


def test_cache_get_set_delete_and_pattern(monkeypatch):
    from app.services import cache

    class FakeRedis:
        def __init__(self):
            self.store = {}

        def get(self, key):
            return self.store.get(key)

        def setex(self, key, ttl, value):
            self.store[key] = value

        def delete(self, key):
            self.store.pop(key, None)

        def scan_iter(self, match):
            return [key for key in list(self.store) if key.startswith(match.rstrip("*"))]

    fake = FakeRedis()
    monkeypatch.setattr(cache, "_redis", fake)

    cache.set("farms:1", [{"id": "farm"}], ttl=10)
    assert cache.get("farms:1") == [{"id": "farm"}]
    cache.delete("farms:1")
    assert cache.get("farms:1") is None
    cache.set("farms:1", [{"id": "farm"}], ttl=10)
    cache.invalidate_pattern("farms:*")
    assert cache.get("farms:1") is None


def test_event_publisher_local_and_connected_paths(monkeypatch):
    from app.observers import event_publisher

    published = []

    class FakeConnection:
        is_open = True

    class FakeChannel:
        def basic_publish(self, **kwargs):
            published.append(kwargs)

    monkeypatch.setattr(event_publisher, "_connection", None)
    monkeypatch.setattr(event_publisher, "_channel", None)
    event_publisher.scan_created("scan-1", "/uploads/leaf.jpg")

    monkeypatch.setattr(event_publisher, "_connection", FakeConnection())
    monkeypatch.setattr(event_publisher, "_channel", FakeChannel())
    event_publisher.scan_completed("scan-1", {"disease": "Blight"})

    assert published[0]["routing_key"] == "scan.completed"
    assert json.loads(published[0]["body"])["scan_id"] == "scan-1"


def test_db_status_and_collection_helpers(monkeypatch):
    from app.models import db

    class FakeDb(dict):
        name = "agrilens"

        def __getitem__(self, item):
            return f"collection:{item}"

    monkeypatch.setattr(db, "_db", FakeDb())

    assert db.get_db_status() == {"mongo_ready": True, "database": "agrilens"}
    assert db.users_col() == "collection:users"
    assert db.scans_col() == "collection:scans"


def test_model_crud_functions_use_expected_collection_operations(monkeypatch):
    from app.models import audit_model, farm_model, notification_model, scan_model, user_model

    user_id = str(ObjectId())
    farm_id = str(ObjectId())
    field_id = str(ObjectId())
    scan_id = str(ObjectId())
    notification_id = str(ObjectId())
    user_col = FakeCollection([{"_id": ObjectId(user_id), "phone": "+201001234567"}])
    farm_col = FakeCollection([{"_id": ObjectId(farm_id), "owner_id": ObjectId(user_id), "fields": [{"field_id": ObjectId(field_id)}]}])
    scan_col = FakeCollection([{"_id": ObjectId(scan_id), "user_id": ObjectId(user_id), "farm_id": ObjectId(farm_id)}])
    notification_col = FakeCollection([{"_id": ObjectId(notification_id), "user_id": ObjectId(user_id), "is_read": False}])
    audit_col = FakeCollection()

    monkeypatch.setattr(user_model, "users_col", lambda: user_col)
    monkeypatch.setattr(farm_model, "farms_col", lambda: farm_col)
    monkeypatch.setattr(scan_model, "scans_col", lambda: scan_col)
    monkeypatch.setattr(notification_model, "notifications_col", lambda: notification_col)
    monkeypatch.setattr(audit_model, "audit_col", lambda: audit_col)

    assert user_model.create_user("+201001234567")["_id"]
    assert user_model.find_by_phone("+201001234567")["phone"] == "+201001234567"
    assert user_model.find_by_id(user_id)["_id"] == ObjectId(user_id)
    assert user_model.update_user(user_id, {"name": "A"}) is True
    assert user_model.add_farm_ref(user_id, farm_id) is True
    assert user_model.remove_farm_ref(user_id, farm_id) is True
    assert user_model.add_fcm_token(user_id, "token") is True
    assert user_model.remove_fcm_token(user_id, "token") is True

    assert farm_model.create_farm(user_id, "Farm")["_id"]
    assert farm_model.get_farms_by_owner(user_id)
    assert farm_model.get_farm_by_id(farm_id)["_id"] == ObjectId(farm_id)
    assert farm_model.update_farm(farm_id, {"name": "New"}) is True
    assert farm_model.delete_farm(farm_id) is True
    assert farm_model.add_field(farm_id, "Field")["name"] == "Field"
    assert farm_model.update_field(farm_id, field_id, {"name": "Field B"}) is True
    assert farm_model.get_field(farm_id, field_id)["field_id"] == ObjectId(field_id)
    assert farm_model.remove_field(farm_id, field_id) is True

    assert scan_model.create_scan(user_id, farm_id=farm_id)["_id"]
    assert scan_model.update_status(scan_id, "processing") is True
    assert scan_model.update_detection_result(scan_id, {"disease": "Blight"}) is True
    assert scan_model.update_scan(scan_id, {"status": "failed"}) is True
    assert scan_model.get_scan_by_id(scan_id)["_id"] == ObjectId(scan_id)
    assert scan_model.get_scans_by_user(user_id)
    assert scan_model.get_scans_by_farm(farm_id)
    assert scan_model.get_scans_by_crop(user_id, "tomato") == []

    assert notification_model.create_notification(user_id, "T", "M")["_id"]
    assert notification_model.list_notifications(user_id)
    assert notification_model.get_notification(notification_id)["_id"] == ObjectId(notification_id)
    assert notification_model.mark_as_read(notification_id, user_id) is True
    assert notification_model.mark_all_as_read(user_id) == 3
    assert notification_model.unread_count(user_id) == 2

    audit_model.log_action(user_id, "login", resource_id=scan_id, ip_address="127.0.0.1")
    assert audit_model.get_logs_for_user(user_id) == []
