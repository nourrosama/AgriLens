"""
Subscription controller — full endpoint coverage.
"""
import pytest
from unittest.mock import MagicMock
import app.controllers.subscription_controller as sc


@pytest.fixture
def sub_client(client_for, monkeypatch, current_user):
    from app.controllers.subscription_controller import subscription_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(subscription_bp)


@pytest.fixture
def sub_headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


# ── GET /api/subscription/status ──────────────────────────────────────────────

def test_get_status_free(sub_client, sub_headers, monkeypatch):
    monkeypatch.setattr(sc, "get_plan", lambda user: "free")
    monkeypatch.setattr(sc, "get_scan_quota", lambda user: {"limit": 5, "used": 2, "remaining": 3})
    r = sub_client.get("/api/subscription/status", headers=sub_headers)
    assert r.status_code == 200
    data = r.get_json()["data"]
    assert data["plan"] == "free"
    assert "quota" in data
    assert "features" in data
    assert "plan_info" in data


def test_get_status_premium(sub_client, sub_headers, monkeypatch):
    monkeypatch.setattr(sc, "get_plan", lambda user: "premium")
    monkeypatch.setattr(sc, "get_scan_quota", lambda user: {"limit": -1, "used": 10, "remaining": -1})
    r = sub_client.get("/api/subscription/status", headers=sub_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["plan"] == "premium"


def test_get_status_professional(sub_client, sub_headers, monkeypatch):
    monkeypatch.setattr(sc, "get_plan", lambda user: "professional")
    monkeypatch.setattr(sc, "get_scan_quota", lambda user: {"limit": -1, "used": 0, "remaining": -1})
    r = sub_client.get("/api/subscription/status", headers=sub_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["plan"] == "professional"


def test_get_status_unauthenticated(sub_client):
    r = sub_client.get("/api/subscription/status")
    assert r.status_code == 401


# ── GET /api/subscription/plans ───────────────────────────────────────────────

def test_list_plans(sub_client):
    r = sub_client.get("/api/subscription/plans")
    assert r.status_code == 200
    plans = r.get_json()["data"]["plans"]
    assert len(plans) == 3
    plan_ids = [p["id"] for p in plans]
    assert "free" in plan_ids
    assert "premium" in plan_ids
    assert "professional" in plan_ids


def test_list_plans_has_features(sub_client):
    r = sub_client.get("/api/subscription/plans")
    plans = r.get_json()["data"]["plans"]
    for plan in plans:
        assert "features" in plan
        assert "info" in plan


# ── POST /api/subscription/upgrade ───────────────────────────────────────────

def test_upgrade_plan_success(sub_client, sub_headers, monkeypatch):
    from app.models import user_model as um
    monkeypatch.setattr(sc, "get_plan", lambda user: "free")
    monkeypatch.setattr(um, "update_user", lambda uid, data: None)
    r = sub_client.post("/api/subscription/upgrade",
                        json={"plan": "premium"}, headers=sub_headers)
    assert r.status_code == 200
    data = r.get_json()["data"]
    assert data["plan"] == "premium"
    assert data["previous_plan"] == "free"
    assert "upgraded" in r.get_json()["message"]


def test_downgrade_plan(sub_client, sub_headers, monkeypatch):
    from app.models import user_model as um
    monkeypatch.setattr(sc, "get_plan", lambda user: "professional")
    monkeypatch.setattr(um, "update_user", lambda uid, data: None)
    r = sub_client.post("/api/subscription/upgrade",
                        json={"plan": "free"}, headers=sub_headers)
    assert r.status_code == 200
    assert "downgraded" in r.get_json()["message"]


def test_upgrade_same_plan(sub_client, sub_headers, monkeypatch):
    monkeypatch.setattr(sc, "get_plan", lambda user: "premium")
    r = sub_client.post("/api/subscription/upgrade",
                        json={"plan": "premium"}, headers=sub_headers)
    assert r.status_code == 400
    assert "already" in r.get_json()["message"]


def test_upgrade_invalid_plan(sub_client, sub_headers):
    r = sub_client.post("/api/subscription/upgrade",
                        json={"plan": "enterprise"}, headers=sub_headers)
    assert r.status_code == 400


def test_upgrade_no_plan_field(sub_client, sub_headers):
    r = sub_client.post("/api/subscription/upgrade",
                        json={}, headers=sub_headers)
    assert r.status_code == 400


def test_upgrade_unauthenticated(sub_client):
    r = sub_client.post("/api/subscription/upgrade", json={"plan": "premium"})
    assert r.status_code == 401
