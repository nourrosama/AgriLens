"""
Forum controller — comprehensive tests.
Covers: feed, posts, comments, Q&A, media upload.
"""
import pytest
from unittest.mock import MagicMock
from bson import ObjectId
from datetime import datetime, timezone
import app.controllers.forum_controller as fc


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def forum_client(client_for, monkeypatch, current_user):
    from app.controllers.forum_controller import forum_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(forum_bp)


@pytest.fixture
def headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def _fake_post(author_id):
    oid = ObjectId()
    return {
        "_id": oid,
        "author_id": ObjectId(author_id),
        "body": "Test post body",
        "content_type": "post",
        "media_url": "",
        "tags": {"crops": [], "diseases": [], "content_type": "post"},
        "likes": [],
        "likes_count": 0,
        "comments_count": 0,
        "created_at": datetime.now(timezone.utc),
    }


def _fake_question(author_id, qid=None):
    return {
        "_id": qid or ObjectId(),
        "author_id": ObjectId(author_id),
        "title": "How to treat blight?",
        "body": "My tomatoes have blight",
        "crop_tags": ["tomato"],
        "disease_tags": ["blight"],
        "answers": [],
        "created_at": datetime.now(timezone.utc),
    }


# ── GET /api/feed ─────────────────────────────────────────────────────────────

def test_get_feed(forum_client, headers, monkeypatch, user_id):
    from app.services import feed_service
    monkeypatch.setattr(feed_service, "get_personalised_feed",
                        lambda uid, page, per_page: [])
    r = forum_client.get("/api/feed", headers=headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["posts"] == []


def test_get_feed_pagination(forum_client, headers, monkeypatch):
    from app.services import feed_service
    monkeypatch.setattr(feed_service, "get_personalised_feed",
                        lambda uid, page, per_page: [])
    r = forum_client.get("/api/feed?page=2&per_page=5", headers=headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["page"] == 2


def test_get_feed_unauthenticated(forum_client):
    r = forum_client.get("/api/feed")
    assert r.status_code == 401


# ── GET /api/feed/trending ────────────────────────────────────────────────────

def test_get_trending(forum_client, headers, monkeypatch):
    from app.services import trending_service
    monkeypatch.setattr(trending_service, "get_trending",
                        lambda: {"crops": [], "diseases": [], "posts": []})
    r = forum_client.get("/api/feed/trending", headers=headers)
    assert r.status_code == 200
    data = r.get_json()["data"]
    assert "crops" in data


# ── GET /api/feed/post-scan ───────────────────────────────────────────────────

def test_get_post_scan_suggestions(forum_client, headers, monkeypatch):
    from app.services import feed_service
    monkeypatch.setattr(feed_service, "get_post_scan_suggestions",
                        lambda c, d: [])
    r = forum_client.get("/api/feed/post-scan?crop_type=tomato&disease=blight",
                         headers=headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["posts"] == []


# ── GET /api/posts ────────────────────────────────────────────────────────────

def test_list_posts(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_post as pm
    post = _fake_post(user_id)
    monkeypatch.setattr(pm, "get_posts_by_tags",
                        lambda **kw: [post])
    monkeypatch.setattr(pm, "serialize_post",
                        lambda p, uid="": {"id": str(p["_id"]), "body": p["body"]})
    r = forum_client.get("/api/posts", headers=headers)
    assert r.status_code == 200
    assert len(r.get_json()["data"]["posts"]) == 1


def test_list_posts_with_filters(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_post as pm
    monkeypatch.setattr(pm, "get_posts_by_tags", lambda **kw: [])
    monkeypatch.setattr(pm, "serialize_post", lambda p, uid="": {})
    r = forum_client.get("/api/posts?crop=tomato&disease=blight&content_type=post",
                         headers=headers)
    assert r.status_code == 200


# ── POST /api/posts ───────────────────────────────────────────────────────────

def test_create_post_success(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_post as pm
    import app.models.community as cm
    post = _fake_post(user_id)
    monkeypatch.setattr(pm, "create_post", lambda **kw: post)
    monkeypatch.setattr(pm, "serialize_post", lambda p, uid="": {"id": str(p["_id"])})
    monkeypatch.setattr(cm, "auto_subscribe", lambda uid, crop: None)
    r = forum_client.post("/api/posts",
                          json={"body": "Hello world", "crop_tags": ["wheat"]},
                          headers=headers)
    assert r.status_code == 201


def test_create_post_empty_body(forum_client, headers):
    r = forum_client.post("/api/posts", json={"body": ""}, headers=headers)
    assert r.status_code == 400


def test_create_post_missing_body(forum_client, headers):
    r = forum_client.post("/api/posts", json={}, headers=headers)
    assert r.status_code == 400


def test_create_post_unauthenticated(forum_client):
    r = forum_client.post("/api/posts", json={"body": "Hi"})
    assert r.status_code == 401


# ── DELETE /api/posts/<id> ────────────────────────────────────────────────────

def test_delete_post_success(forum_client, headers, monkeypatch, user_id):
    post_id = ObjectId()
    post = _fake_post(user_id)
    post["_id"] = post_id

    mock_posts = MagicMock()
    mock_posts.return_value.find_one.return_value = post
    mock_posts.return_value.delete_one.return_value = None
    mock_comments = MagicMock()
    mock_comments.return_value.delete_many.return_value = None

    monkeypatch.setattr(fc, "forum_posts_col", mock_posts)
    monkeypatch.setattr(fc, "forum_comments_col", mock_comments)

    r = forum_client.delete(f"/api/posts/{post_id}", headers=headers)
    assert r.status_code == 200


def test_delete_post_invalid_id(forum_client, headers):
    r = forum_client.delete("/api/posts/invalid-id", headers=headers)
    assert r.status_code == 400


def test_delete_post_not_found(forum_client, headers, monkeypatch):
    mock_posts = MagicMock()
    mock_posts.return_value.find_one.return_value = None
    monkeypatch.setattr(fc, "forum_posts_col", mock_posts)
    r = forum_client.delete(f"/api/posts/{ObjectId()}", headers=headers)
    assert r.status_code == 404


def test_delete_post_forbidden(forum_client, headers, monkeypatch, user_id):
    post_id = ObjectId()
    other_post = _fake_post(str(ObjectId()))  # different author
    other_post["_id"] = post_id
    mock_posts = MagicMock()
    mock_posts.return_value.find_one.return_value = other_post
    monkeypatch.setattr(fc, "forum_posts_col", mock_posts)
    r = forum_client.delete(f"/api/posts/{post_id}", headers=headers)
    assert r.status_code == 403


# ── POST /api/posts/<id>/like ─────────────────────────────────────────────────

def test_toggle_like_success(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_post as pm
    post_id = str(ObjectId())
    monkeypatch.setattr(pm, "toggle_like", lambda pid, uid: {"liked": True, "likes_count": 1})
    r = forum_client.post(f"/api/posts/{post_id}/like", headers=headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["liked"] is True


def test_toggle_like_invalid_id(forum_client, headers):
    r = forum_client.post("/api/posts/bad-id/like", headers=headers)
    assert r.status_code == 400


def test_toggle_like_not_found(forum_client, headers, monkeypatch):
    import app.models.forum_post as pm
    monkeypatch.setattr(pm, "toggle_like", lambda pid, uid: None)
    r = forum_client.post(f"/api/posts/{ObjectId()}/like", headers=headers)
    assert r.status_code == 404


# ── GET /api/posts/<id>/comments ─────────────────────────────────────────────

def test_get_comments(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_post as pm
    post_id = str(ObjectId())
    comment = {
        "_id": ObjectId(), "post_id": ObjectId(post_id),
        "author_id": ObjectId(user_id), "body": "Nice post",
        "created_at": datetime.now(timezone.utc),
    }
    monkeypatch.setattr(pm, "get_comments", lambda pid, page, per_page: [comment])
    monkeypatch.setattr(pm, "serialize_comment",
                        lambda c: {"id": str(c["_id"]), "body": c["body"]})
    r = forum_client.get(f"/api/posts/{post_id}/comments", headers=headers)
    assert r.status_code == 200
    assert len(r.get_json()["data"]["comments"]) == 1


def test_get_comments_invalid_id(forum_client, headers):
    r = forum_client.get("/api/posts/bad-id/comments", headers=headers)
    assert r.status_code == 400


# ── POST /api/posts/<id>/comments ────────────────────────────────────────────

def test_add_comment_success(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_post as pm
    from app.models import notification_model as nm, user_model as um
    import app.services.push_service as ps

    post_id = str(ObjectId())
    post = _fake_post(user_id)
    comment = {
        "_id": ObjectId(), "post_id": ObjectId(post_id),
        "author_id": ObjectId(user_id), "body": "Great!",
        "created_at": datetime.now(timezone.utc),
    }
    monkeypatch.setattr(pm, "add_comment", lambda pid, uid, body: comment)
    monkeypatch.setattr(pm, "get_post_by_id", lambda pid: post)
    monkeypatch.setattr(pm, "serialize_comment",
                        lambda c: {"id": str(c["_id"]), "body": c["body"]})
    monkeypatch.setattr(nm, "create_notification", lambda **kw: None)
    monkeypatch.setattr(ps, "send_push_to_user", lambda **kw: None)

    r = forum_client.post(f"/api/posts/{post_id}/comments",
                          json={"body": "Great!"}, headers=headers)
    assert r.status_code == 201


def test_add_comment_empty(forum_client, headers):
    r = forum_client.post(f"/api/posts/{ObjectId()}/comments",
                          json={"body": ""}, headers=headers)
    assert r.status_code == 400


def test_add_comment_invalid_post_id(forum_client, headers):
    r = forum_client.post("/api/posts/bad-id/comments",
                          json={"body": "Hi"}, headers=headers)
    assert r.status_code == 400


# ── GET /api/forum/questions ─────────────────────────────────────────────────

def test_list_questions(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_question as qm
    question = _fake_question(user_id)
    monkeypatch.setattr(qm, "get_questions",
                        lambda **kw: [question])
    monkeypatch.setattr(qm, "serialize_question",
                        lambda q: {"id": str(q["_id"]), "title": q["title"]})
    r = forum_client.get("/api/forum/questions", headers=headers)
    assert r.status_code == 200
    assert len(r.get_json()["data"]["questions"]) == 1


def test_list_questions_with_filters(forum_client, headers, monkeypatch):
    import app.models.forum_question as qm
    monkeypatch.setattr(qm, "get_questions", lambda **kw: [])
    monkeypatch.setattr(qm, "serialize_question", lambda q: {})
    r = forum_client.get("/api/forum/questions?crop=tomato&filter=my_questions",
                         headers=headers)
    assert r.status_code == 200


def test_list_questions_answered_by_me_filter(forum_client, headers, monkeypatch):
    import app.models.forum_question as qm
    monkeypatch.setattr(qm, "get_questions", lambda **kw: [])
    monkeypatch.setattr(qm, "serialize_question", lambda q: {})
    r = forum_client.get("/api/forum/questions?filter=answered_by_me", headers=headers)
    assert r.status_code == 200


# ── POST /api/forum/questions ─────────────────────────────────────────────────

def test_ask_question_success(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_question as qm
    question = _fake_question(user_id)
    monkeypatch.setattr(qm, "create_question", lambda **kw: question)
    monkeypatch.setattr(qm, "serialize_question",
                        lambda q: {"id": str(q["_id"]), "title": q["title"]})
    r = forum_client.post("/api/forum/questions",
                          json={"title": "How to treat blight?",
                                "body": "My tomatoes have blight",
                                "crop_tags": ["tomato"]},
                          headers=headers)
    assert r.status_code == 201


def test_ask_question_missing_title(forum_client, headers):
    r = forum_client.post("/api/forum/questions",
                          json={"body": "My question"}, headers=headers)
    assert r.status_code == 400


def test_ask_question_missing_body(forum_client, headers):
    r = forum_client.post("/api/forum/questions",
                          json={"title": "My question"}, headers=headers)
    assert r.status_code == 400


# ── GET /api/forum/questions/<id> ─────────────────────────────────────────────

def test_get_question_success(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_question as qm
    qid = ObjectId()
    question = _fake_question(user_id, qid)
    answer = {"_id": ObjectId(), "question_id": str(qid), "body": "Try fungicide",
              "author_id": ObjectId(user_id), "is_accepted": False,
              "created_at": datetime.now(timezone.utc)}
    monkeypatch.setattr(qm, "get_question_by_id", lambda qid: question)
    monkeypatch.setattr(qm, "get_answers", lambda qid: [answer])
    monkeypatch.setattr(qm, "serialize_question",
                        lambda q: {"id": str(q["_id"]), "title": q["title"]})
    monkeypatch.setattr(qm, "serialize_answer",
                        lambda a: {"id": str(a["_id"]), "body": a["body"]})
    r = forum_client.get(f"/api/forum/questions/{qid}", headers=headers)
    assert r.status_code == 200
    assert len(r.get_json()["data"]["answers"]) == 1


def test_get_question_invalid_id(forum_client, headers):
    r = forum_client.get("/api/forum/questions/bad-id", headers=headers)
    assert r.status_code == 400


def test_get_question_not_found(forum_client, headers, monkeypatch):
    import app.models.forum_question as qm
    monkeypatch.setattr(qm, "get_question_by_id", lambda qid: None)
    r = forum_client.get(f"/api/forum/questions/{ObjectId()}", headers=headers)
    assert r.status_code == 404


# ── POST /api/forum/questions/<id>/answers ────────────────────────────────────

def test_post_answer_success(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_question as qm
    from app.models import notification_model as nm, user_model as um
    import app.services.push_service as ps

    qid = ObjectId()
    question = _fake_question(user_id, qid)
    answer = {"_id": ObjectId(), "body": "Use copper fungicide",
              "author_id": ObjectId(user_id), "created_at": datetime.now(timezone.utc)}

    monkeypatch.setattr(qm, "get_question_by_id", lambda qid: question)
    monkeypatch.setattr(qm, "create_answer", lambda qid, uid, body: answer)
    monkeypatch.setattr(qm, "serialize_answer",
                        lambda a: {"id": str(a["_id"]), "body": a["body"]})
    monkeypatch.setattr(nm, "create_notification", lambda **kw: None)
    monkeypatch.setattr(ps, "send_push_to_user", lambda **kw: None)

    r = forum_client.post(f"/api/forum/questions/{qid}/answers",
                          json={"body": "Use copper fungicide"}, headers=headers)
    assert r.status_code == 201


def test_post_answer_question_not_found(forum_client, headers, monkeypatch):
    import app.models.forum_question as qm
    monkeypatch.setattr(qm, "get_question_by_id", lambda qid: None)
    r = forum_client.post(f"/api/forum/questions/{ObjectId()}/answers",
                          json={"body": "Answer"}, headers=headers)
    assert r.status_code == 404


def test_post_answer_empty_body(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_question as qm
    qid = ObjectId()
    monkeypatch.setattr(qm, "get_question_by_id", lambda qid: _fake_question(user_id, qid))
    r = forum_client.post(f"/api/forum/questions/{qid}/answers",
                          json={"body": ""}, headers=headers)
    assert r.status_code == 400


def test_post_answer_invalid_question_id(forum_client, headers):
    r = forum_client.post("/api/forum/questions/bad-id/answers",
                          json={"body": "Answer"}, headers=headers)
    assert r.status_code == 400


# ── PATCH /api/forum/answers/<id>/accept ──────────────────────────────────────

def test_accept_answer_success(forum_client, headers, monkeypatch, user_id):
    import app.models.forum_question as qm
    qid = ObjectId()
    answer_id = ObjectId()
    monkeypatch.setattr(qm, "accept_answer", lambda aid, qid, uid: True)
    r = forum_client.patch(f"/api/forum/answers/{answer_id}/accept",
                           json={"question_id": str(qid)}, headers=headers)
    assert r.status_code == 200


def test_accept_answer_not_authorised(forum_client, headers, monkeypatch):
    import app.models.forum_question as qm
    monkeypatch.setattr(qm, "accept_answer", lambda aid, qid, uid: False)
    r = forum_client.patch(f"/api/forum/answers/{ObjectId()}/accept",
                           json={"question_id": str(ObjectId())}, headers=headers)
    assert r.status_code == 403


def test_accept_answer_invalid_answer_id(forum_client, headers):
    r = forum_client.patch("/api/forum/answers/bad-id/accept",
                           json={"question_id": str(ObjectId())}, headers=headers)
    assert r.status_code == 400


def test_accept_answer_missing_question_id(forum_client, headers):
    r = forum_client.patch(f"/api/forum/answers/{ObjectId()}/accept",
                           json={}, headers=headers)
    assert r.status_code == 400


def test_accept_answer_invalid_question_id(forum_client, headers):
    r = forum_client.patch(f"/api/forum/answers/{ObjectId()}/accept",
                           json={"question_id": "bad-id"}, headers=headers)
    assert r.status_code == 400
