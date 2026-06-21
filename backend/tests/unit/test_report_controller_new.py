"""
Report controller — comprehensive tests.
Covers: export_report (all plans), export_pdf (professional plan).
"""
import pytest
from unittest.mock import MagicMock, patch
from bson import ObjectId


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def report_client(client_for, monkeypatch, current_user):
    from app.controllers.report_controller import reports_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(reports_bp)


@pytest.fixture
def headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def _to_str_ids(d):
    """Recursively convert ObjectId to str for JSON safety."""
    if isinstance(d, dict):
        return {k: _to_str_ids(v) for k, v in d.items()}
    if isinstance(d, list):
        return [_to_str_ids(i) for i in d]
    if isinstance(d, ObjectId):
        return str(d)
    return d


def _fake_farm():
    return {
        "_id": str(ObjectId()), "name": "Farm A", "crop_type": "wheat",
        "area_hectares": 5, "fields": [], "owner_id": str(ObjectId()),
    }


def _fake_scan(healthy=True):
    return {
        "_id": str(ObjectId()), "crop_type": "wheat",
        "status": "completed",
        "detection_result": {
            "disease": "" if healthy else "Leaf Rust",
            "is_healthy": healthy,
            "severity": "none" if healthy else "moderate",
            "confidence": 0.9,
        },
        "created_at": "2025-01-01T00:00:00",
    }


def _fake_notif():
    return {"_id": str(ObjectId()), "title": "Alert", "is_read": False}


def _mock_deps(monkeypatch, plan="free", farms=None, scans=None, notifs=None, summary=None):
    from app.models import farm_model as fm, scan_model as sm, notification_model as nm
    from app.services import insights_service as ins

    farms = [_fake_farm()] if farms is None else farms
    scans = [_fake_scan()] if scans is None else scans
    notifs = [_fake_notif()] if notifs is None else notifs
    summary = summary if summary is not None else {"total_farms": 1, "total_scans": 1}

    monkeypatch.setattr(fm, "get_farms_by_owner", lambda uid: farms)
    monkeypatch.setattr(fm, "serialize", lambda f: _to_str_ids(f))
    monkeypatch.setattr(sm, "get_scans_by_user", lambda uid, p, per: scans)
    monkeypatch.setattr(sm, "serialize", lambda s: _to_str_ids(s))
    monkeypatch.setattr(nm, "list_notifications", lambda uid, n: notifs)
    monkeypatch.setattr(nm, "serialize", lambda n: _to_str_ids(n))
    monkeypatch.setattr(ins, "build_dashboard_summary", lambda uid: summary)

    import app.controllers.report_controller as rc
    monkeypatch.setattr(rc, "get_plan", lambda user: plan)


# ── GET /api/reports/export ───────────────────────────────────────────────────

def test_export_report_free_plan(report_client, headers, monkeypatch):
    _mock_deps(monkeypatch, plan="free")
    r = report_client.get("/api/reports/export", headers=headers)
    assert r.status_code == 200
    body = r.get_json()["data"]
    assert body["plan"] == "free"
    assert "report" in body
    assert "disease_trends" not in body["report"]


def test_export_report_professional_plan(report_client, headers, monkeypatch):
    diseased_scan = _fake_scan(healthy=False)
    _mock_deps(monkeypatch, plan="professional", scans=[diseased_scan])
    r = report_client.get("/api/reports/export", headers=headers)
    assert r.status_code == 200
    body = r.get_json()["data"]
    assert body["plan"] == "professional"
    assert "disease_trends" in body["report"]


def test_export_report_with_period(report_client, headers, monkeypatch):
    _mock_deps(monkeypatch, plan="basic")
    r = report_client.get("/api/reports/export?period=monthly", headers=headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["report"]["period"] == "monthly"


def test_export_report_unauthenticated(report_client):
    r = report_client.get("/api/reports/export")
    assert r.status_code == 401


def test_export_report_no_farms_no_scans(report_client, headers, monkeypatch):
    _mock_deps(monkeypatch, plan="free", farms=[], scans=[], notifs=[])
    r = report_client.get("/api/reports/export", headers=headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["report"]["farms"] == []


def test_export_report_professional_no_diseases(report_client, headers, monkeypatch):
    _mock_deps(monkeypatch, plan="professional", scans=[_fake_scan(healthy=True)])
    r = report_client.get("/api/reports/export", headers=headers)
    assert r.status_code == 200
    body = r.get_json()["data"]
    assert body["report"]["disease_trends"] == {}


# ── GET /api/reports/pdf ──────────────────────────────────────────────────────

def test_export_pdf_professional(report_client, headers, monkeypatch):
    import app.controllers.report_controller as rc
    import app.middleware.subscription_middleware as sub_mw
    _mock_deps(monkeypatch, plan="professional")
    monkeypatch.setattr(sub_mw, "plan_meets_minimum", lambda user, plan: True)
    monkeypatch.setattr(rc, "_build_pdf", lambda user, period, farms, scans, summary: b"%PDF-fake")
    r = report_client.get("/api/reports/pdf", headers=headers)
    assert r.status_code == 200
    assert r.content_type == "application/pdf"


def test_export_pdf_non_professional_blocked(report_client, headers, monkeypatch):
    import app.middleware.subscription_middleware as sub_mw
    _mock_deps(monkeypatch, plan="free")
    monkeypatch.setattr(sub_mw, "plan_meets_minimum", lambda user, plan: False)
    r = report_client.get("/api/reports/pdf", headers=headers)
    assert r.status_code == 403


def test_export_pdf_build_error(report_client, headers, monkeypatch):
    import app.controllers.report_controller as rc
    import app.middleware.subscription_middleware as sub_mw
    _mock_deps(monkeypatch, plan="professional")
    monkeypatch.setattr(sub_mw, "plan_meets_minimum", lambda user, plan: True)
    monkeypatch.setattr(rc, "_build_pdf",
                        lambda *a, **kw: (_ for _ in ()).throw(Exception("pdf error")))
    r = report_client.get("/api/reports/pdf", headers=headers)
    assert r.status_code == 500
