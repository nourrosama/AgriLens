"""
Admin controller — comprehensive endpoint tests.
All routes need role='admin'. DB collections are patched in admin_controller namespace.
"""
import pytest
from unittest.mock import MagicMock
from bson import ObjectId
from datetime import datetime, timezone
import app.controllers.admin_controller as ac


# ── Admin user fixture ────────────────────────────────────────────────────────

@pytest.fixture
def admin_user(user_id):
    return {
        "_id": ObjectId(user_id),
        "phone": "+201000000001",
        "name": "Admin User",
        "role": "admin",
        "language": "en",
        "farms": [],
    }


@pytest.fixture
def admin_client(client_for, monkeypatch, admin_user):
    from app.controllers.admin_controller import admin_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: admin_user)
    return client_for(admin_bp)


@pytest.fixture
def admin_headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def _make_col(count=0, docs=None, agg=None):
    """Create a callable that returns a mock MongoDB collection."""
    col = MagicMock()
    col.return_value.count_documents.return_value = count
    col.return_value.aggregate.return_value = iter(agg or [])
    chain = MagicMock()
    chain.sort.return_value = chain
    chain.skip.return_value = chain
    chain.limit.return_value = docs or []
    col.return_value.find.return_value = chain
    col.return_value.insert_many.return_value = None
    return col


# ── /api/admin/stats ──────────────────────────────────────────────────────────

def test_get_stats(admin_client, admin_headers, monkeypatch):
    mock = _make_col(count=5)
    monkeypatch.setattr(ac, "users_col", mock)
    monkeypatch.setattr(ac, "scans_col", mock)
    monkeypatch.setattr(ac, "farms_col", mock)
    monkeypatch.setattr(ac, "articles_col", mock)
    r = admin_client.get("/api/admin/stats", headers=admin_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert "users" in body["data"]
    assert body["data"]["users"]["total"] == 5


def test_stats_forbidden_for_farmer(client_for, monkeypatch, current_user):
    from app.controllers.admin_controller import admin_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    client = client_for(admin_bp)
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    headers = {"Authorization": f"Bearer {make_token(str(current_user['_id']))}"}
    r = client.get("/api/admin/stats", headers=headers)
    assert r.status_code == 403


def test_stats_requires_auth(admin_client):
    r = admin_client.get("/api/admin/stats")
    assert r.status_code == 401


def test_stats_with_disease_data(admin_client, admin_headers, monkeypatch, admin_user):
    mock = _make_col(count=10, agg=[{"_id": "Blight", "count": 3}])
    monkeypatch.setattr(ac, "users_col", mock)
    monkeypatch.setattr(ac, "scans_col", mock)
    monkeypatch.setattr(ac, "farms_col", mock)
    monkeypatch.setattr(ac, "articles_col", mock)
    r = admin_client.get("/api/admin/stats", headers=admin_headers)
    assert r.status_code == 200


# ── /api/admin/users ──────────────────────────────────────────────────────────

def test_list_users(admin_client, admin_headers, monkeypatch, admin_user):
    from app.models import user_model as um

    mock_col = _make_col(count=1, docs=[admin_user])
    monkeypatch.setattr(ac, "users_col", mock_col)
    monkeypatch.setattr(um, "serialize", lambda u: {"id": str(u["_id"]), "name": u.get("name")})

    r = admin_client.get("/api/admin/users", headers=admin_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["total"] == 1


def test_list_users_with_search(admin_client, admin_headers, monkeypatch):
    from app.models import user_model as um
    mock_col = _make_col(count=0, docs=[])
    monkeypatch.setattr(ac, "users_col", mock_col)
    monkeypatch.setattr(um, "serialize", lambda u: {})
    r = admin_client.get("/api/admin/users?search=Ali&role=farmer", headers=admin_headers)
    assert r.status_code == 200


def test_get_user_found(admin_client, admin_headers, monkeypatch, admin_user, user_id):
    from app.models import user_model as um
    monkeypatch.setattr(um, "find_by_id", lambda _id: admin_user)
    monkeypatch.setattr(um, "serialize", lambda u: {"id": str(u["_id"])})
    mock_col = _make_col(count=2)
    monkeypatch.setattr(ac, "scans_col", mock_col)
    monkeypatch.setattr(ac, "farms_col", mock_col)
    r = admin_client.get(f"/api/admin/users/{user_id}", headers=admin_headers)
    assert r.status_code == 200
    assert "total_scans" in r.get_json()["data"]["user"]


def test_get_user_not_found(admin_client, admin_headers, monkeypatch, admin_user, user_id):
    from app.middleware import auth_middleware
    target_id = str(ObjectId())
    # One smart mock: return admin for JWT user, None for unknown target
    monkeypatch.setattr(
        auth_middleware.user_model, "find_by_id",
        lambda uid: admin_user if str(uid) == user_id else None,
    )
    r = admin_client.get(f"/api/admin/users/{target_id}", headers=admin_headers)
    assert r.status_code == 404


def test_update_user_role(admin_client, admin_headers, monkeypatch, admin_user, user_id):
    from app.models import user_model as um, audit_model as am
    monkeypatch.setattr(um, "update_user", lambda uid, d: None)
    monkeypatch.setattr(um, "find_by_id", lambda _id: admin_user)
    monkeypatch.setattr(um, "serialize", lambda u: {"id": str(u["_id"]), "role": u.get("role")})
    monkeypatch.setattr(am, "log_action", lambda *a, **kw: None)
    r = admin_client.put(f"/api/admin/users/{user_id}",
                         json={"role": "researcher"}, headers=admin_headers)
    assert r.status_code == 200


def test_update_user_invalid_role(admin_client, admin_headers, user_id):
    r = admin_client.put(f"/api/admin/users/{user_id}",
                         json={"role": "superuser"}, headers=admin_headers)
    assert r.status_code == 400


def test_update_user_nothing_to_update(admin_client, admin_headers, user_id):
    r = admin_client.put(f"/api/admin/users/{user_id}", json={}, headers=admin_headers)
    assert r.status_code == 400


def test_update_user_active_flag(admin_client, admin_headers, monkeypatch, admin_user, user_id):
    from app.models import user_model as um, audit_model as am
    monkeypatch.setattr(um, "update_user", lambda uid, d: None)
    monkeypatch.setattr(um, "find_by_id", lambda _id: admin_user)
    monkeypatch.setattr(um, "serialize", lambda u: {})
    monkeypatch.setattr(am, "log_action", lambda *a, **kw: None)
    r = admin_client.put(f"/api/admin/users/{user_id}",
                         json={"active": False}, headers=admin_headers)
    assert r.status_code == 200


# ── /api/admin/scans ──────────────────────────────────────────────────────────

def test_list_all_scans(admin_client, admin_headers, monkeypatch):
    mock_col = _make_col(count=0, docs=[])
    monkeypatch.setattr(ac, "scans_col", mock_col)
    monkeypatch.setattr(ac, "serialize_scan", lambda s: {})
    r = admin_client.get("/api/admin/scans", headers=admin_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["total"] == 0


def test_list_all_scans_with_status_filter(admin_client, admin_headers, monkeypatch):
    mock_col = _make_col(count=0, docs=[])
    monkeypatch.setattr(ac, "scans_col", mock_col)
    monkeypatch.setattr(ac, "serialize_scan", lambda s: {})
    r = admin_client.get("/api/admin/scans?status=completed", headers=admin_headers)
    assert r.status_code == 200


# ── /api/admin/articles ───────────────────────────────────────────────────────

def test_list_articles(admin_client, admin_headers, monkeypatch):
    from app.models import article_model as am
    monkeypatch.setattr(am, "get_all_articles", lambda page, per_page: [])
    monkeypatch.setattr(am, "count_articles", lambda: 0)
    monkeypatch.setattr(am, "serialize", lambda a: {})
    r = admin_client.get("/api/admin/articles", headers=admin_headers)
    assert r.status_code == 200


def test_create_article(admin_client, admin_headers, monkeypatch, admin_user):
    from app.models import article_model as am
    fake_article = {"_id": ObjectId(), "title": "T", "body": "B"}
    monkeypatch.setattr(am, "create_article", lambda **kw: fake_article)
    monkeypatch.setattr(am, "serialize", lambda a: {"id": str(a["_id"]), "title": a["title"]})
    r = admin_client.post("/api/admin/articles",
                          json={"title": "Test Article", "body": "Body text"},
                          headers=admin_headers)
    assert r.status_code == 201


def test_create_article_missing_fields(admin_client, admin_headers):
    r = admin_client.post("/api/admin/articles",
                          json={"title": "Only title"}, headers=admin_headers)
    assert r.status_code == 400


def test_update_article(admin_client, admin_headers, monkeypatch, user_id):
    from app.models import article_model as am
    fake_article = {"_id": ObjectId(), "title": "New Title", "body": "B"}
    monkeypatch.setattr(am, "update_article", lambda aid, d: None)
    monkeypatch.setattr(am, "get_article_by_id", lambda aid: fake_article)
    monkeypatch.setattr(am, "serialize", lambda a: {"title": a["title"]})
    r = admin_client.put(f"/api/admin/articles/{user_id}",
                         json={"title": "New Title"}, headers=admin_headers)
    assert r.status_code == 200


def test_update_article_nothing(admin_client, admin_headers, user_id):
    r = admin_client.put(f"/api/admin/articles/{user_id}",
                         json={}, headers=admin_headers)
    assert r.status_code == 400


def test_update_article_published(admin_client, admin_headers, monkeypatch, user_id):
    from app.models import article_model as am
    fake_article = {"_id": ObjectId(), "title": "T", "body": "B"}
    monkeypatch.setattr(am, "update_article", lambda aid, d: None)
    monkeypatch.setattr(am, "get_article_by_id", lambda aid: fake_article)
    monkeypatch.setattr(am, "serialize", lambda a: {})
    r = admin_client.put(f"/api/admin/articles/{user_id}",
                         json={"published": True}, headers=admin_headers)
    assert r.status_code == 200


def test_delete_article_found(admin_client, admin_headers, monkeypatch, user_id):
    from app.models import article_model as am
    monkeypatch.setattr(am, "delete_article", lambda aid: True)
    r = admin_client.delete(f"/api/admin/articles/{user_id}", headers=admin_headers)
    assert r.status_code == 200


def test_delete_article_not_found(admin_client, admin_headers, monkeypatch, user_id):
    from app.models import article_model as am
    monkeypatch.setattr(am, "delete_article", lambda aid: False)
    r = admin_client.delete(f"/api/admin/articles/{user_id}", headers=admin_headers)
    assert r.status_code == 404


# ── /api/admin/notifications/broadcast ────────────────────────────────────────

def test_broadcast_notification(admin_client, admin_headers, monkeypatch, admin_user):
    from app.models import audit_model as am
    mock_users_col = MagicMock()
    mock_users_col.return_value.find.return_value = [{"_id": ObjectId()}]
    mock_notifs_col = MagicMock()
    mock_notifs_col.return_value.insert_many.return_value = None
    monkeypatch.setattr(ac, "users_col", mock_users_col)
    monkeypatch.setattr(ac, "notifications_col", mock_notifs_col)
    monkeypatch.setattr(am, "log_action", lambda *a, **kw: None)
    r = admin_client.post("/api/admin/notifications/broadcast",
                          json={"title": "Alert", "message": "Rain incoming"},
                          headers=admin_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["recipients"] == 1


def test_broadcast_notification_with_role_filter(admin_client, admin_headers, monkeypatch):
    from app.models import audit_model as am
    mock_users_col = MagicMock()
    mock_users_col.return_value.find.return_value = []
    monkeypatch.setattr(ac, "users_col", mock_users_col)
    monkeypatch.setattr(ac, "notifications_col", MagicMock())
    monkeypatch.setattr(am, "log_action", lambda *a, **kw: None)
    r = admin_client.post("/api/admin/notifications/broadcast",
                          json={"title": "A", "message": "M", "role": "farmer"},
                          headers=admin_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["recipients"] == 0


def test_broadcast_missing_fields(admin_client, admin_headers):
    r = admin_client.post("/api/admin/notifications/broadcast",
                          json={"title": "Only"}, headers=admin_headers)
    assert r.status_code == 400


# ── /api/admin/audit-logs ─────────────────────────────────────────────────────

def test_list_audit_logs(admin_client, admin_headers, monkeypatch):
    now = datetime.now(timezone.utc)
    fake_log = {
        "_id": ObjectId(),
        "user_id": ObjectId(),
        "action": "login_success",
        "ip_address": "127.0.0.1",
        "details": {},
        "timestamp": now,
    }
    mock_col = _make_col(count=1, docs=[fake_log])
    monkeypatch.setattr(ac, "audit_col", mock_col)
    r = admin_client.get("/api/admin/audit-logs", headers=admin_headers)
    assert r.status_code == 200
    data = r.get_json()["data"]
    assert data["total"] == 1
    assert data["logs"][0]["action"] == "login_success"
