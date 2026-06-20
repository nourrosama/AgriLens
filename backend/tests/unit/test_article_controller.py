"""
Unit tests — Article Controller
Tests list and detail endpoints for free and premium users.
"""
import pytest
from bson import ObjectId


def _article(depth="full"):
    return {
        "_id": ObjectId(),
        "title": "Tomato Blight Guide",
        "body": "Full content here..." * 10,
        "summary": "Short summary",
        "tags": ["tomato", "blight"],
        "depth": depth,
        "published": True,
    }


@pytest.fixture
def article_client(client_for, monkeypatch, current_user):
    from app.controllers.article_controller import article_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(article_bp)


def _patch_articles(monkeypatch, articles):
    from app.controllers import article_controller as ac
    monkeypatch.setattr(ac.article_model, "get_published_articles",
                        lambda page, per_page, category: articles)
    monkeypatch.setattr(ac.article_model, "count_articles",
                        lambda published_only=True: len(articles))
    monkeypatch.setattr(ac.article_model, "serialize",
                        lambda a: {**a, "_id": str(a["_id"])})


# ── list_articles ─────────────────────────────────────────────────────────────

def test_list_articles_free_user(article_client, auth_headers, monkeypatch, current_user):
    current_user["plan"] = "free"
    _patch_articles(monkeypatch, [_article("shallow")])
    r = article_client.get("/api/articles", headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert "articles" in body.get("data", body)

def test_list_articles_premium_user(article_client, auth_headers, monkeypatch, current_user):
    current_user["plan"] = "premium"
    _patch_articles(monkeypatch, [_article("full")])
    r = article_client.get("/api/articles", headers=auth_headers)
    assert r.status_code == 200

def test_list_articles_empty_returns_empty_list(article_client, auth_headers, monkeypatch):
    _patch_articles(monkeypatch, [])
    r = article_client.get("/api/articles", headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    data = body.get("data", body)
    assert data.get("articles", []) == [] or data.get("total", 0) == 0

def test_list_articles_pagination(article_client, auth_headers, monkeypatch):
    _patch_articles(monkeypatch, [_article()])
    r = article_client.get("/api/articles?page=2&per_page=10", headers=auth_headers)
    assert r.status_code == 200

def test_list_articles_unauthenticated(article_client):
    r = article_client.get("/api/articles")
    assert r.status_code == 401

def test_list_articles_filter_by_tag(article_client, auth_headers, monkeypatch):
    _patch_articles(monkeypatch, [_article()])
    r = article_client.get("/api/articles?category=tomato", headers=auth_headers)
    assert r.status_code == 200


# ── get_article ───────────────────────────────────────────────────────────────

def test_get_article_found(article_client, auth_headers, monkeypatch):
    from app.controllers import article_controller
    article = _article()
    monkeypatch.setattr(article_controller.article_model, "get_article_by_id",
                        lambda aid: article)
    monkeypatch.setattr(article_controller.article_model, "serialize",
                        lambda a: {**a, "_id": str(a["_id"])})
    r = article_client.get(f"/api/articles/{article['_id']}", headers=auth_headers)
    assert r.status_code == 200
    body = r.get_json()
    assert "title" in str(body)

def test_get_article_not_found(article_client, auth_headers, monkeypatch):
    from app.controllers import article_controller
    monkeypatch.setattr(article_controller.article_model, "get_article_by_id",
                        lambda aid: None)
    r = article_client.get(f"/api/articles/{ObjectId()}", headers=auth_headers)
    assert r.status_code == 404

def test_get_article_invalid_id(article_client, auth_headers, monkeypatch):
    from app.controllers import article_controller
    # Controller doesn't validate ObjectId — it calls get_article_by_id with raw string
    monkeypatch.setattr(article_controller.article_model, "get_article_by_id",
                        lambda aid: None)
    r = article_client.get("/api/articles/not-an-id", headers=auth_headers)
    assert r.status_code in (400, 404, 422)
