"""
Feed service, trending service, and push service — comprehensive tests.
"""
import pytest
from unittest.mock import MagicMock, patch
from bson import ObjectId
from datetime import datetime, timezone


# ═══════════════════════════════════════════════════════════════════════════════
# Feed service tests
# ═══════════════════════════════════════════════════════════════════════════════

def _fake_post_doc(post_id=None, author_id=None, crops=None, diseases=None, likes=5, comments=2):
    oid = post_id or ObjectId()
    return {
        "_id": oid,
        "author_id": ObjectId(author_id) if author_id else ObjectId(),
        "body": "Test post about farming",
        "content_type": "post",
        "media_url": "",
        "tags": {
            "crops": crops or [],
            "diseases": diseases or [],
            "content_type": "post",
        },
        "likes": [],
        "likes_count": likes,
        "comments_count": comments,
        "created_at": datetime.now(timezone.utc),
    }


# ── _get_user_crop_weights ─────────────────────────────────────────────────────

def test_get_user_crop_weights(monkeypatch):
    from app.services import feed_service as fs
    from app.models.db import scans_col

    mock_col = MagicMock()
    mock_col.return_value.aggregate.return_value = iter([
        {"_id": "tomato", "count": 5},
        {"_id": "wheat", "count": 3},
    ])
    monkeypatch.setattr("app.services.feed_service.scans_col", mock_col)

    result = fs._get_user_crop_weights(str(ObjectId()))
    assert result == {"tomato": 5, "wheat": 3}


def test_get_user_crop_weights_empty(monkeypatch):
    from app.services import feed_service as fs

    mock_col = MagicMock()
    mock_col.return_value.aggregate.return_value = iter([])
    monkeypatch.setattr("app.services.feed_service.scans_col", mock_col)

    result = fs._get_user_crop_weights(str(ObjectId()))
    assert result == {}


# ── _get_recent_diseases ───────────────────────────────────────────────────────

def test_get_recent_diseases(monkeypatch):
    from app.services import feed_service as fs

    mock_col = MagicMock()
    mock_col.return_value.aggregate.return_value = iter([
        {"disease": "Leaf Rust"},
        {"disease": "Blight"},
    ])
    monkeypatch.setattr("app.services.feed_service.scans_col", mock_col)

    result = fs._get_recent_diseases(str(ObjectId()))
    assert "leaf rust" in result
    assert "blight" in result


def test_get_recent_diseases_no_disease_field(monkeypatch):
    from app.services import feed_service as fs

    mock_col = MagicMock()
    mock_col.return_value.aggregate.return_value = iter([
        {"disease": None},
        {},
    ])
    monkeypatch.setattr("app.services.feed_service.scans_col", mock_col)

    result = fs._get_recent_diseases(str(ObjectId()))
    assert result == []


# ── _score_post ────────────────────────────────────────────────────────────────

def test_score_post_no_match():
    from app.services.feed_service import _score_post
    post = _fake_post_doc(crops=["corn"], diseases=[], likes=10, comments=5)
    score = _score_post(post, crop_weights={"tomato": 3}, disease_tags=[])
    assert score == min(10, 50) + min(5 * 2, 30)  # popularity only


def test_score_post_crop_match():
    from app.services.feed_service import _score_post
    post = _fake_post_doc(crops=["tomato"], likes=0, comments=0)
    score = _score_post(post, crop_weights={"tomato": 3}, disease_tags=[])
    assert score == 30  # 3 * 10


def test_score_post_disease_match():
    from app.services.feed_service import _score_post
    post = _fake_post_doc(diseases=["blight"], likes=0, comments=0)
    score = _score_post(post, crop_weights={}, disease_tags=["blight"])
    assert score == 20


def test_score_post_capped_likes():
    from app.services.feed_service import _score_post
    post = _fake_post_doc(likes=200, comments=0)
    score = _score_post(post, crop_weights={}, disease_tags=[])
    assert score == 50  # capped at 50


def test_score_post_capped_comments():
    from app.services.feed_service import _score_post
    post = _fake_post_doc(likes=0, comments=100)
    score = _score_post(post, crop_weights={}, disease_tags=[])
    assert score == 30  # capped at 30


# ── get_personalised_feed ──────────────────────────────────────────────────────

def test_get_personalised_feed_no_history(monkeypatch):
    from app.services import feed_service as fs
    import app.models.forum_post as pm

    mock_col = MagicMock()
    mock_col.return_value.aggregate.return_value = iter([])
    monkeypatch.setattr("app.services.feed_service.scans_col", mock_col)

    posts = [_fake_post_doc()]
    monkeypatch.setattr(pm, "get_recent_posts", lambda page, per_page: posts)
    monkeypatch.setattr(pm, "serialize_post",
                        lambda p, uid="": {"id": str(p["_id"])})

    result = fs.get_personalised_feed(str(ObjectId()), page=1, per_page=20)
    assert len(result) == 1


def test_get_personalised_feed_with_history(monkeypatch):
    from app.services import feed_service as fs
    import app.models.forum_post as pm

    mock_col = MagicMock()
    mock_col.return_value.aggregate.side_effect = [
        iter([{"_id": "tomato", "count": 3}]),
        iter([{"disease": "blight"}]),
    ]
    monkeypatch.setattr("app.services.feed_service.scans_col", mock_col)

    post1 = _fake_post_doc(crops=["tomato"], diseases=["blight"], likes=5)
    post2 = _fake_post_doc(crops=["corn"], likes=1)
    monkeypatch.setattr(pm, "get_recent_posts", lambda page, per_page: [post1, post2])
    monkeypatch.setattr(pm, "serialize_post",
                        lambda p, uid="": {"id": str(p["_id"])})

    result = fs.get_personalised_feed(str(ObjectId()), page=1, per_page=20)
    assert len(result) == 2
    # Tomato/blight post should rank higher
    assert result[0]["id"] == str(post1["_id"])


def test_get_personalised_feed_pagination(monkeypatch):
    from app.services import feed_service as fs
    import app.models.forum_post as pm

    mock_col = MagicMock()
    mock_col.return_value.aggregate.side_effect = [
        iter([{"_id": "tomato", "count": 3}]),
        iter([]),
    ]
    monkeypatch.setattr("app.services.feed_service.scans_col", mock_col)

    posts = [_fake_post_doc() for _ in range(5)]
    monkeypatch.setattr(pm, "get_recent_posts", lambda page, per_page: posts)
    monkeypatch.setattr(pm, "serialize_post", lambda p, uid="": {"id": str(p["_id"])})

    result = fs.get_personalised_feed(str(ObjectId()), page=2, per_page=2)
    assert len(result) == 2


# ── get_post_scan_suggestions ──────────────────────────────────────────────────

def test_get_post_scan_suggestions_enough_posts(monkeypatch):
    from app.services import feed_service as fs
    import app.models.forum_post as pm

    tagged_posts = [_fake_post_doc(crops=["tomato"]) for _ in range(3)]
    monkeypatch.setattr(pm, "get_posts_by_tags", lambda **kw: tagged_posts)
    monkeypatch.setattr(pm, "serialize_post", lambda p, uid="": {"id": str(p["_id"])})

    result = fs.get_post_scan_suggestions("tomato", "blight", limit=3)
    assert len(result) == 3


def test_get_post_scan_suggestions_pad_with_recent(monkeypatch):
    from app.services import feed_service as fs
    import app.models.forum_post as pm

    tagged_post = _fake_post_doc(crops=["tomato"])
    extra_posts = [_fake_post_doc() for _ in range(5)]
    monkeypatch.setattr(pm, "get_posts_by_tags", lambda **kw: [tagged_post])
    monkeypatch.setattr(pm, "get_recent_posts", lambda per_page: extra_posts)
    monkeypatch.setattr(pm, "serialize_post", lambda p, uid="": {"id": str(p["_id"])})

    result = fs.get_post_scan_suggestions("tomato", "blight", limit=3)
    assert len(result) == 3


def test_get_post_scan_suggestions_no_crop(monkeypatch):
    from app.services import feed_service as fs
    import app.models.forum_post as pm

    monkeypatch.setattr(pm, "get_posts_by_tags", lambda **kw: [])
    monkeypatch.setattr(pm, "get_recent_posts", lambda per_page: [])
    monkeypatch.setattr(pm, "serialize_post", lambda p, uid="": {"id": str(p["_id"])})

    result = fs.get_post_scan_suggestions("", "", limit=3)
    assert result == []


# ═══════════════════════════════════════════════════════════════════════════════
# Trending service tests
# ═══════════════════════════════════════════════════════════════════════════════

def test_get_trending_cached(monkeypatch):
    from app.services import trending_service as ts

    # Prime cache
    ts._cache["data"] = {"top_crops": [], "top_diseases": [], "trending_posts": []}
    ts._cache["computed_at"] = float("inf")  # never expires

    result = ts.get_trending()
    assert "top_crops" in result


def test_get_trending_force_refresh(monkeypatch):
    from app.services import trending_service as ts

    mock_scans = MagicMock()
    mock_scans.return_value.aggregate.return_value = iter([])
    monkeypatch.setattr("app.services.trending_service.scans_col", mock_scans)

    mock_db = MagicMock()
    mock_posts_col = MagicMock()
    mock_posts_col.aggregate.return_value = iter([])
    mock_db.__getitem__.return_value = mock_posts_col
    monkeypatch.setattr("app.services.trending_service.get_db", lambda: mock_db)

    result = ts.get_trending(force_refresh=True)
    assert "top_crops" in result
    assert "top_diseases" in result
    assert "trending_posts" in result


def test_compute_with_data(monkeypatch):
    from app.services import trending_service as ts

    mock_scans = MagicMock()
    mock_scans.return_value.aggregate.side_effect = [
        iter([{"_id": "tomato", "count": 10}]),
        iter([{"_id": "Leaf Rust", "count": 5}]),
    ]
    monkeypatch.setattr("app.services.trending_service.scans_col", mock_scans)

    bson_id = ObjectId()
    mock_db = MagicMock()
    mock_posts_col = MagicMock()
    mock_posts_col.aggregate.return_value = iter([{
        "_id": bson_id,
        "body": "Tomato disease discussion",
        "content_type": "post",
        "likes_count": 15,
        "comments_count": 3,
        "tags": {"crops": ["tomato"]},
    }])
    mock_db.__getitem__.return_value = mock_posts_col
    monkeypatch.setattr("app.services.trending_service.get_db", lambda: mock_db)

    result = ts._compute()
    assert result["top_crops"][0]["crop"] == "tomato"
    assert result["top_diseases"][0]["disease"] == "Leaf Rust"
    assert len(result["trending_posts"]) == 1


def test_compute_filters_none_ids(monkeypatch):
    from app.services import trending_service as ts

    mock_scans = MagicMock()
    mock_scans.return_value.aggregate.side_effect = [
        iter([{"_id": None, "count": 5}, {"_id": "corn", "count": 3}]),
        iter([{"_id": None, "count": 2}]),
    ]
    monkeypatch.setattr("app.services.trending_service.scans_col", mock_scans)

    mock_db = MagicMock()
    mock_posts_col = MagicMock()
    mock_posts_col.aggregate.return_value = iter([])
    mock_db.__getitem__.return_value = mock_posts_col
    monkeypatch.setattr("app.services.trending_service.get_db", lambda: mock_db)

    result = ts._compute()
    assert len(result["top_crops"]) == 1  # "corn" only, None filtered
    assert result["top_diseases"] == []  # None filtered


# ═══════════════════════════════════════════════════════════════════════════════
# Push service tests
# ═══════════════════════════════════════════════════════════════════════════════

def test_send_push_no_tokens():
    from app.services import push_service as ps
    user = {"_id": ObjectId(), "fcm_tokens": []}
    # Should be silent no-op
    ps.send_push_to_user(user=user, title="Alert", body="Danger", data={})


def test_send_push_firebase_not_enabled():
    from app.services import push_service as ps
    old = ps._firebase_enabled
    ps._firebase_enabled = False
    user = {"_id": ObjectId(), "fcm_tokens": ["token123"]}
    ps.send_push_to_user(user=user, title="Alert", body="Test")
    ps._firebase_enabled = old


def test_send_push_firebase_enabled(monkeypatch):
    from app.services import push_service as ps

    mock_response = MagicMock()
    mock_response.success_count = 1
    mock_response.failure_count = 0

    mock_messaging = MagicMock()
    mock_messaging.Message = MagicMock(return_value=MagicMock())
    mock_messaging.Notification = MagicMock(return_value=MagicMock())
    mock_messaging.send_each.return_value = mock_response

    old_enabled = ps._firebase_enabled
    old_app = ps._firebase_app
    ps._firebase_enabled = True
    ps._firebase_app = MagicMock()

    with patch.dict("sys.modules", {"firebase_admin": MagicMock(),
                                    "firebase_admin.messaging": mock_messaging}):
        import importlib
        user = {"_id": ObjectId(), "fcm_tokens": ["fcm_token_abc"]}
        ps.send_push_to_user(user=user, title="Scan complete",
                             body="Disease detected", data={"scan_id": "123"})

    ps._firebase_enabled = old_enabled
    ps._firebase_app = old_app


def test_send_push_firebase_exception(monkeypatch):
    from app.services import push_service as ps

    old_enabled = ps._firebase_enabled
    old_app = ps._firebase_app
    ps._firebase_enabled = True
    ps._firebase_app = MagicMock()

    mock_messaging = MagicMock()
    mock_messaging.Message = MagicMock(return_value=MagicMock())
    mock_messaging.Notification = MagicMock(return_value=MagicMock())
    mock_messaging.send_each.side_effect = Exception("FCM error")

    with patch.dict("sys.modules", {"firebase_admin": MagicMock(),
                                    "firebase_admin.messaging": mock_messaging}):
        user = {"_id": ObjectId(), "fcm_tokens": ["bad_token"]}
        ps.send_push_to_user(user=user, title="Alert", body="Warn")

    ps._firebase_enabled = old_enabled
    ps._firebase_app = old_app


def test_init_push_service_no_creds():
    from flask import Flask
    import app.services.push_service as ps
    app = Flask(__name__)
    app.config["FIREBASE_CREDENTIALS_PATH"] = ""
    ps.init_push_service(app)
    assert ps._firebase_enabled is False


def test_init_push_service_invalid_path():
    from flask import Flask
    import app.services.push_service as ps
    app = Flask(__name__)
    app.config["FIREBASE_CREDENTIALS_PATH"] = "/nonexistent/path/credentials.json"
    ps.init_push_service(app)
    assert ps._firebase_enabled is False
