"""
Unit tests — Forum Controller
Tests: feed, posts CRUD, likes, comments, Q&A, XSS escaping, pagination.
"""
import pytest
from bson import ObjectId
from datetime import datetime, timezone


@pytest.fixture
def forum_client(client_for, monkeypatch, current_user):
    from app.controllers.forum_controller import forum_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(forum_bp)


def _post(oid=None, author_id=None):
    oid = oid or ObjectId()
    return {
        "_id": oid,
        "author_id": author_id or ObjectId(),
        "body": "Test post",
        "likes": [],
        "like_count": 0,
        "comment_count": 0,
        "content_type": "post",
        "created_at": datetime.now(timezone.utc),
    }


def _serialized_post(post):
    return {**post, "_id": str(post["_id"]), "author_id": str(post["author_id"])}


def _comment(post_id=None):
    return {
        "_id": ObjectId(),
        "post_id": str(post_id or ObjectId()),
        "author_id": str(ObjectId()),
        "body": "Great post!",
        "created_at": datetime.now(timezone.utc),
    }


def _serialized_comment(c):
    return {**c, "_id": str(c["_id"])}


# ── Feed ─────────────────────────────────────────────────────────────────────

def test_get_feed_returns_list(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    monkeypatch.setattr(forum_controller.feed_service, "get_personalised_feed",
                        lambda uid, page=1, per_page=20: [])
    r = forum_client.get("/api/feed", headers=auth_headers)
    assert r.status_code == 200

def test_get_feed_unauthenticated(forum_client):
    r = forum_client.get("/api/feed")
    assert r.status_code == 401

def test_get_feed_pagination(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    monkeypatch.setattr(forum_controller.feed_service, "get_personalised_feed",
                        lambda uid, page=1, per_page=20: [])
    r = forum_client.get("/api/feed?page=2&per_page=5", headers=auth_headers)
    assert r.status_code == 200


# ── Posts ─────────────────────────────────────────────────────────────────────

def test_list_posts_returns_paginated(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    post = _post()
    monkeypatch.setattr(forum_controller.post_model, "get_posts_by_tags",
                        lambda **kw: [post])
    monkeypatch.setattr(forum_controller.post_model, "serialize_post",
                        lambda p, uid: _serialized_post(p))
    r = forum_client.get("/api/posts", headers=auth_headers)
    assert r.status_code == 200

def test_create_post_valid(forum_client, auth_headers, monkeypatch, current_user):
    from app.controllers import forum_controller
    post = _post(author_id=current_user["_id"])
    monkeypatch.setattr(forum_controller.post_model, "create_post",
                        lambda **kw: post)
    monkeypatch.setattr(forum_controller.post_model, "serialize_post",
                        lambda p, uid: _serialized_post(p))
    monkeypatch.setattr(forum_controller.community_model, "auto_subscribe",
                        lambda uid, crop: None)
    r = forum_client.post("/api/posts", json={"body": "My crop is sick"},
                          headers=auth_headers)
    assert r.status_code in (200, 201)

def test_create_post_escapes_html(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    captured = {}
    def fake_create(**kw):
        captured["body"] = kw.get("body", "")
        return _post()
    monkeypatch.setattr(forum_controller.post_model, "create_post", fake_create)
    monkeypatch.setattr(forum_controller.post_model, "serialize_post",
                        lambda p, uid: _serialized_post(p))
    monkeypatch.setattr(forum_controller.community_model, "auto_subscribe",
                        lambda uid, crop: None)
    r = forum_client.post("/api/posts",
                          json={"body": "<script>alert(1)</script>"},
                          headers=auth_headers)
    if r.status_code in (200, 201):
        assert "<script>" not in captured.get("body", "")

def test_create_post_missing_body(forum_client, auth_headers):
    r = forum_client.post("/api/posts", json={}, headers=auth_headers)
    assert r.status_code == 400

def test_delete_post_own(forum_client, auth_headers, monkeypatch, current_user):
    from unittest.mock import MagicMock
    from app.controllers import forum_controller
    post_id = ObjectId()
    post = {"_id": post_id, "author_id": current_user["_id"], "body": "test"}
    fake_col = MagicMock()
    fake_col.return_value.find_one.return_value = post
    fake_col.return_value.delete_one.return_value = MagicMock(deleted_count=1)
    monkeypatch.setattr(forum_controller, "forum_posts_col", fake_col)
    monkeypatch.setattr(forum_controller, "forum_comments_col", fake_col)
    r = forum_client.delete(f"/api/posts/{post_id}", headers=auth_headers)
    assert r.status_code in (200, 204)

def test_delete_post_not_found(forum_client, auth_headers, monkeypatch):
    from unittest.mock import MagicMock
    from app.controllers import forum_controller
    fake_col = MagicMock()
    fake_col.return_value.find_one.return_value = None
    monkeypatch.setattr(forum_controller, "forum_posts_col", fake_col)
    r = forum_client.delete(f"/api/posts/{ObjectId()}", headers=auth_headers)
    assert r.status_code == 404

def test_delete_post_unauthorized(forum_client, auth_headers, monkeypatch):
    from unittest.mock import MagicMock
    from app.controllers import forum_controller
    post = {"_id": ObjectId(), "author_id": ObjectId(), "body": "test"}  # different owner
    fake_col = MagicMock()
    fake_col.return_value.find_one.return_value = post
    monkeypatch.setattr(forum_controller, "forum_posts_col", fake_col)
    r = forum_client.delete(f"/api/posts/{post['_id']}", headers=auth_headers)
    assert r.status_code in (403, 401)


# ── Likes ─────────────────────────────────────────────────────────────────────

def test_toggle_like_adds_like(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    monkeypatch.setattr(forum_controller.post_model, "toggle_like",
                        lambda pid, uid: {"liked": True, "like_count": 1})
    r = forum_client.post(f"/api/posts/{ObjectId()}/like", headers=auth_headers)
    assert r.status_code == 200

def test_toggle_like_not_found(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    monkeypatch.setattr(forum_controller.post_model, "toggle_like",
                        lambda pid, uid: None)
    r = forum_client.post(f"/api/posts/{ObjectId()}/like", headers=auth_headers)
    assert r.status_code == 404


# ── Comments ──────────────────────────────────────────────────────────────────

def test_get_comments_returns_list(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    c = _comment()
    monkeypatch.setattr(forum_controller.post_model, "get_comments",
                        lambda pid, page=1, per_page=20: [c])
    monkeypatch.setattr(forum_controller.post_model, "serialize_comment",
                        lambda c: _serialized_comment(c))
    r = forum_client.get(f"/api/posts/{ObjectId()}/comments", headers=auth_headers)
    assert r.status_code == 200

def test_add_comment_valid(forum_client, auth_headers, monkeypatch, current_user):
    from app.controllers import forum_controller
    post = _post(author_id=current_user["_id"])
    comment = _comment(post["_id"])
    monkeypatch.setattr(forum_controller.post_model, "add_comment",
                        lambda pid, uid, body: comment)
    monkeypatch.setattr(forum_controller.post_model, "get_post_by_id",
                        lambda pid: post)
    monkeypatch.setattr(forum_controller.post_model, "serialize_comment",
                        lambda c: _serialized_comment(c))
    monkeypatch.setattr(forum_controller, "_notify_forum_interaction",
                        lambda **kw: None)
    r = forum_client.post(f"/api/posts/{post['_id']}/comments",
                          json={"body": "Great post"}, headers=auth_headers)
    assert r.status_code in (200, 201)

def test_add_comment_escapes_xss(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    captured = {}
    post = _post()
    def fake_add(pid, uid, body):
        captured["body"] = body
        c = _comment(pid)
        c["body"] = body
        return c
    monkeypatch.setattr(forum_controller.post_model, "add_comment", fake_add)
    monkeypatch.setattr(forum_controller.post_model, "get_post_by_id",
                        lambda pid: post)
    monkeypatch.setattr(forum_controller.post_model, "serialize_comment",
                        lambda c: _serialized_comment(c))
    monkeypatch.setattr(forum_controller, "_notify_forum_interaction",
                        lambda **kw: None)
    r = forum_client.post(f"/api/posts/{post['_id']}/comments",
                          json={"body": "<img src=x onerror=alert(1)>"},
                          headers=auth_headers)
    if r.status_code in (200, 201):
        assert "<img" not in captured.get("body", "")

def test_add_comment_missing_body(forum_client, auth_headers):
    r = forum_client.post(f"/api/posts/{ObjectId()}/comments", json={},
                          headers=auth_headers)
    assert r.status_code == 400


# ── Q&A ───────────────────────────────────────────────────────────────────────

def _question():
    return {
        "_id": ObjectId(),
        "author_id": str(ObjectId()),
        "title": "Help my tomatoes!",
        "body": "Why are leaves yellow?",
        "crop_tags": [],
        "disease_tags": [],
        "created_at": datetime.now(timezone.utc),
    }

def _serialized_q(q):
    return {**q, "_id": str(q["_id"])}


def test_list_questions_returns_paginated(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    q = _question()
    monkeypatch.setattr(forum_controller.question_model, "get_questions",
                        lambda **kw: [q])
    monkeypatch.setattr(forum_controller.question_model, "serialize_question",
                        lambda q: _serialized_q(q))
    r = forum_client.get("/api/forum/questions", headers=auth_headers)
    assert r.status_code == 200

def test_ask_question_valid(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    q = _question()
    monkeypatch.setattr(forum_controller.question_model, "create_question",
                        lambda **kw: q)
    monkeypatch.setattr(forum_controller.question_model, "serialize_question",
                        lambda q: _serialized_q(q))
    r = forum_client.post("/api/forum/questions",
                          json={"title": "Help!", "body": "Why are leaves yellow?"},
                          headers=auth_headers)
    assert r.status_code in (200, 201)

def test_ask_question_missing_title(forum_client, auth_headers):
    r = forum_client.post("/api/forum/questions", json={"body": "Some body"},
                          headers=auth_headers)
    assert r.status_code == 400

def test_ask_question_escapes_xss(forum_client, auth_headers, monkeypatch):
    from app.controllers import forum_controller
    captured = {}
    def fake_create(**kw):
        captured.update(kw)
        q = _question()
        q.update(kw)
        return q
    monkeypatch.setattr(forum_controller.question_model, "create_question", fake_create)
    monkeypatch.setattr(forum_controller.question_model, "serialize_question",
                        lambda q: _serialized_q(q))
    r = forum_client.post("/api/forum/questions",
                          json={"title": "<b>bold</b>", "body": "<script>hack()</script>"},
                          headers=auth_headers)
    if r.status_code in (200, 201):
        assert "<script>" not in captured.get("body", "")
