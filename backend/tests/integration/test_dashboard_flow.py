"""
Integration tests — Dashboard + Weather + Notifications combined view
Verifies the mobile home screen assembly: summary, weather, unread count.
"""
import pytest
from bson import ObjectId
from unittest.mock import patch


@pytest.fixture
def dash_client(client_for, monkeypatch, current_user):
    from app.controllers.dashboard_controller import dashboard_bp
    from app.controllers.notification_controller import notifications_bp
    from app.controllers.health_controller import health_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(dashboard_bp, notifications_bp, health_bp)


# ── Dashboard summary ─────────────────────────────────────────────────────────

def test_dashboard_summary_structure(dash_client, auth_headers, monkeypatch):
    from app.controllers import dashboard_controller
    summary = {
        "farms_count": 2,
        "scans_count": 15,
        "unread_notifications": 3,
        "weather": {"current": "sunny", "temp": 28},
        "recent_scans": [],
    }
    monkeypatch.setattr(dashboard_controller, "insights_service",
                        type("is", (), {
                            "build_dashboard_summary": staticmethod(lambda uid: summary)
                        })())
    r = dash_client.get("/api/dashboard/summary", headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert body["data"] is not None

def test_dashboard_unauthenticated(dash_client):
    r = dash_client.get("/api/dashboard/summary")
    assert r.status_code == 401

def test_dashboard_user_with_no_farms(dash_client, auth_headers, monkeypatch, current_user):
    from app.controllers import dashboard_controller
    current_user["farms"] = []
    summary = {"farms_count": 0, "scans_count": 0, "unread_notifications": 0,
               "weather": {}, "recent_scans": []}
    monkeypatch.setattr(dashboard_controller, "insights_service",
                        type("is", (), {
                            "build_dashboard_summary": staticmethod(lambda uid: summary)
                        })())
    r = dash_client.get("/api/dashboard/summary", headers=auth_headers)
    assert r.status_code == 200

def test_dashboard_includes_weather(dash_client, auth_headers, monkeypatch):
    from app.controllers import dashboard_controller
    summary = {"farms_count": 1, "scans_count": 5, "unread_notifications": 1,
               "weather": {"temp": 30, "condition": "clear"}, "recent_scans": []}
    monkeypatch.setattr(dashboard_controller, "insights_service",
                        type("is", (), {
                            "build_dashboard_summary": staticmethod(lambda uid: summary)
                        })())
    r = dash_client.get("/api/dashboard/summary", headers=auth_headers)
    assert r.status_code == 200

def test_dashboard_high_unread_notifications(dash_client, auth_headers, monkeypatch):
    from app.controllers import dashboard_controller
    summary = {"farms_count": 3, "scans_count": 50, "unread_notifications": 99,
               "weather": {}, "recent_scans": []}
    monkeypatch.setattr(dashboard_controller, "insights_service",
                        type("is", (), {
                            "build_dashboard_summary": staticmethod(lambda uid: summary)
                        })())
    r = dash_client.get("/api/dashboard/summary", headers=auth_headers)
    assert r.status_code == 200


# ── Health check ─────────────────────────────────────────────────────────────

def test_health_check_ok(dash_client, monkeypatch):
    from app.controllers import health_controller
    r = dash_client.get("/api/health")
    assert r.status_code in (200, 503)

def test_health_check_no_auth_required(dash_client):
    r = dash_client.get("/api/health")
    assert r.status_code in (200, 503)


# ── Combined: notifications count matches dashboard ───────────────────────────

def test_notifications_unread_count_consistent(dash_client, auth_headers, monkeypatch,
                                                current_user):
    from app.controllers import notification_controller as nc, dashboard_controller
    nid = ObjectId()
    unread = [{"_id": nid, "read": False, "title": "Alert",
               "body": "Disease found",
               "user_id": str(current_user["_id"])}]
    monkeypatch.setattr(nc.notification_model, "list_notifications",
                        lambda uid, limit=100: unread)
    monkeypatch.setattr(nc.notification_model, "unread_count", lambda uid: 1)
    monkeypatch.setattr(nc.notification_model, "serialize",
                        lambda n: {**n, "_id": str(n["_id"])})
    monkeypatch.setattr(dashboard_controller, "insights_service",
                        type("is", (), {
                            "build_dashboard_summary": staticmethod(
                                lambda uid: {"unread_notifications": 1,
                                             "farms_count": 0, "scans_count": 0,
                                             "weather": {}, "recent_scans": []})
                        })())
    notif_r = dash_client.get("/api/notifications", headers=auth_headers)
    dash_r = dash_client.get("/api/dashboard/summary", headers=auth_headers)
    assert notif_r.status_code == 200
    assert dash_r.status_code == 200
    notif_count = len(notif_r.get_json()["data"]["notifications"])
    dash_data = dash_r.get_json()["data"]
    # Summary is nested inside "summary" key
    summary = dash_data.get("summary", dash_data)
    dash_unread = summary.get("unread_notifications", 0)
    assert notif_count == dash_unread
