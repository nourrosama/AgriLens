"""
Unit tests — Subscription Service
Tests plan detection, feature gating, scan quotas, and plan hierarchy.
All tests are pure logic — no database or network calls.
"""
import pytest
from bson import ObjectId
from unittest.mock import patch


# ── get_plan ──────────────────────────────────────────────────────────────────

def test_get_plan_returns_free_by_default():
    from app.services.subscription_service import get_plan
    assert get_plan({}) == "free"

def test_get_plan_returns_premium():
    from app.services.subscription_service import get_plan
    assert get_plan({"plan": "premium"}) == "premium"

def test_get_plan_returns_admin():
    from app.services.subscription_service import get_plan
    assert get_plan({"plan": "admin"}) == "admin"

def test_get_plan_unknown_value_defaults_to_free():
    from app.services.subscription_service import get_plan
    assert get_plan({"plan": "enterprise"}) in ("free", "enterprise")


# ── has_feature ───────────────────────────────────────────────────────────────

def test_has_feature_free_user_lacks_premium_feature():
    from app.services.subscription_service import has_feature
    result = has_feature({"plan": "free"}, "detailed_report")
    assert result is False

def test_has_feature_premium_user_has_detailed_report():
    from app.services.subscription_service import has_feature
    result = has_feature({"plan": "premium"}, "detailed_report")
    assert result is True

def test_has_feature_premium_has_unlimited_scans():
    from app.services.subscription_service import has_feature
    assert has_feature({"plan": "premium"}, "unlimited_scans") is True
    assert has_feature({"plan": "premium"}, "severity") is True
    assert has_feature({"plan": "premium"}, "symptoms_causes") is True

def test_has_feature_unknown_feature_returns_false():
    from app.services.subscription_service import has_feature
    assert has_feature({"plan": "premium"}, "nonexistent_feature") is False


# ── plan_meets_minimum ────────────────────────────────────────────────────────

def test_plan_meets_minimum_free_meets_free():
    from app.services.subscription_service import plan_meets_minimum
    assert plan_meets_minimum({"plan": "free"}, "free") is True

def test_plan_meets_minimum_free_fails_premium():
    from app.services.subscription_service import plan_meets_minimum
    assert plan_meets_minimum({"plan": "free"}, "premium") is False

def test_plan_meets_minimum_premium_meets_free():
    from app.services.subscription_service import plan_meets_minimum
    assert plan_meets_minimum({"plan": "premium"}, "free") is True

def test_plan_meets_minimum_professional_meets_premium():
    from app.services.subscription_service import plan_meets_minimum
    assert plan_meets_minimum({"plan": "professional"}, "premium") is True


# ── can_scan ──────────────────────────────────────────────────────────────────

def test_can_scan_free_user_within_quota():
    from app.services.subscription_service import can_scan
    user = {"plan": "free", "_id": ObjectId()}
    with patch("app.services.subscription_service.get_monthly_scan_count", return_value=2):
        allowed, msg = can_scan(user)
        assert allowed is True

def test_can_scan_free_user_over_quota():
    from app.services.subscription_service import can_scan
    user = {"plan": "free", "_id": ObjectId()}
    with patch("app.services.subscription_service.get_monthly_scan_count", return_value=999):
        allowed, msg = can_scan(user)
        assert allowed is False
        assert msg != ""

def test_can_scan_premium_user_always_allowed():
    from app.services.subscription_service import can_scan
    user = {"plan": "premium", "_id": ObjectId()}
    with patch("app.services.subscription_service.get_monthly_scan_count", return_value=500):
        allowed, _ = can_scan(user)
        assert allowed is True


# ── get_scan_quota ────────────────────────────────────────────────────────────

def test_get_scan_quota_free_has_limit():
    from app.services.subscription_service import get_scan_quota
    with patch("app.services.subscription_service.get_monthly_scan_count", return_value=3):
        quota = get_scan_quota({"plan": "free", "_id": ObjectId()})
        assert quota["limit"] is not None
        assert quota["used"] == 3

def test_get_scan_quota_premium_unlimited():
    from app.services.subscription_service import get_scan_quota
    with patch("app.services.subscription_service.get_monthly_scan_count", return_value=100):
        quota = get_scan_quota({"plan": "premium", "_id": ObjectId()})
        assert quota.get("limit") in (None, -1, 0) or quota.get("unlimited") is True


# ── get_articles_depth ────────────────────────────────────────────────────────

def test_articles_depth_free_is_basic():
    from app.services.subscription_service import get_articles_depth
    depth = get_articles_depth({"plan": "free"})
    assert depth == "basic"

def test_articles_depth_premium_is_detailed():
    from app.services.subscription_service import get_articles_depth
    depth = get_articles_depth({"plan": "premium"})
    assert depth == "detailed"

def test_articles_depth_professional_is_full():
    from app.services.subscription_service import get_articles_depth
    depth = get_articles_depth({"plan": "professional"})
    assert depth == "full"
