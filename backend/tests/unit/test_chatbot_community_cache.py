"""
Chatbot controller, community controller, cache service, and disease report service tests.
"""
import pytest
from unittest.mock import MagicMock, patch
from bson import ObjectId
from datetime import datetime, timezone
import app.controllers.chatbot_controller as cc
import app.controllers.community_controller as comc


# ═══════════════════════════════════════════════════════════════════════════════
# Chatbot controller
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def chatbot_client(client_for, monkeypatch, current_user):
    from app.controllers.chatbot_controller import chatbot_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(chatbot_bp)


@pytest.fixture
def chatbot_headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


# ── POST /api/chatbot-test ────────────────────────────────────────────────────

def test_chatbot_test_endpoint(chatbot_client, monkeypatch):
    import app.services.chatbot_service as cs
    monkeypatch.setattr(cs, "get_ai_response", lambda msg, lang: "AI says hello")
    r = chatbot_client.post("/api/chatbot-test", json={"message": "Hello"})
    assert r.status_code == 200
    assert r.get_json()["data"]["message"] == "AI says hello"


def test_chatbot_test_empty_message(chatbot_client):
    r = chatbot_client.post("/api/chatbot-test", json={"message": ""})
    assert r.status_code == 400


def test_chatbot_test_no_body(chatbot_client):
    r = chatbot_client.post("/api/chatbot-test", json={})
    assert r.status_code == 400


def test_chatbot_test_arabic(chatbot_client, monkeypatch):
    import app.services.chatbot_service as cs
    monkeypatch.setattr(cs, "get_ai_response", lambda msg, lang: "مرحبا")
    r = chatbot_client.post("/api/chatbot-test", json={"message": "مرحبا", "lang": "ar"})
    assert r.status_code == 200


# ── POST /api/chatbot (authenticated) ────────────────────────────────────────

def test_chatbot_auth_success(chatbot_client, chatbot_headers, monkeypatch, current_user):
    import app.services.chatbot_service as cs
    import app.middleware.subscription_middleware as sub_mw
    session_id = ObjectId()
    response_dict = {"reply": "Disease detected", "suggestions": []}

    monkeypatch.setattr(cs, "get_ai_response", lambda msg, lang: response_dict)
    monkeypatch.setattr(sub_mw, "plan_meets_minimum", lambda user, plan: True)
    monkeypatch.setattr(cc, "chat_sessions_col", lambda: MagicMock(
        find_one=lambda q: None,
        insert_one=MagicMock(return_value=MagicMock(inserted_id=session_id)),
        update_one=lambda *a: None,
    ))
    monkeypatch.setattr(cc, "chat_messages_col", lambda: MagicMock(
        insert_many=lambda docs: None,
    ))

    r = chatbot_client.post("/api/chatbot", json={"message": "Help with blight"},
                            headers=chatbot_headers)
    assert r.status_code == 200
    body = r.get_json()["data"]
    assert "message" in body


def test_chatbot_auth_empty_message(chatbot_client, chatbot_headers, monkeypatch):
    import app.middleware.subscription_middleware as sub_mw
    monkeypatch.setattr(sub_mw, "plan_meets_minimum", lambda user, plan: True)
    r = chatbot_client.post("/api/chatbot", json={"message": ""},
                            headers=chatbot_headers)
    assert r.status_code == 400


def test_chatbot_auth_free_plan_blocked(chatbot_client, chatbot_headers, monkeypatch):
    import app.middleware.subscription_middleware as sub_mw
    monkeypatch.setattr(sub_mw, "plan_meets_minimum", lambda user, plan: False)
    r = chatbot_client.post("/api/chatbot", json={"message": "Hello"},
                            headers=chatbot_headers)
    assert r.status_code == 403


def test_chatbot_auth_unauthenticated(chatbot_client):
    r = chatbot_client.post("/api/chatbot", json={"message": "Hi"})
    assert r.status_code == 401


def test_chatbot_auth_with_existing_session(chatbot_client, chatbot_headers, monkeypatch):
    import app.services.chatbot_service as cs
    import app.middleware.subscription_middleware as sub_mw

    session_id = str(ObjectId())
    existing_session = {"_id": ObjectId(session_id), "user_id": "test"}
    response_dict = {"reply": "Sure!", "suggestions": []}

    monkeypatch.setattr(cs, "get_ai_response", lambda msg, lang: response_dict)
    monkeypatch.setattr(sub_mw, "plan_meets_minimum", lambda user, plan: True)
    monkeypatch.setattr(cc, "chat_sessions_col", lambda: MagicMock(
        find_one=lambda q: existing_session,
        update_one=lambda *a, **kw: None,
    ))
    monkeypatch.setattr(cc, "chat_messages_col", lambda: MagicMock(
        insert_many=lambda docs: None,
    ))

    r = chatbot_client.post("/api/chatbot",
                            json={"message": "Continue", "session_id": session_id},
                            headers=chatbot_headers)
    assert r.status_code == 200


def test_chatbot_auth_db_failure_graceful(chatbot_client, chatbot_headers, monkeypatch):
    import app.services.chatbot_service as cs
    import app.middleware.subscription_middleware as sub_mw

    response_dict = {"reply": "AI response", "suggestions": []}
    monkeypatch.setattr(cs, "get_ai_response", lambda msg, lang: response_dict)
    monkeypatch.setattr(sub_mw, "plan_meets_minimum", lambda user, plan: True)
    # DB raises exception - should gracefully handle
    monkeypatch.setattr(cc, "chat_sessions_col", lambda: (_ for _ in ()).throw(Exception("DB down")))

    r = chatbot_client.post("/api/chatbot", json={"message": "Hi there"},
                            headers=chatbot_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["session_id"] is None


# ── GET /api/chatbot/sessions ────────────────────────────────────────────────

def test_list_sessions(chatbot_client, chatbot_headers, monkeypatch):
    now = datetime.now(timezone.utc)
    session = {"_id": ObjectId(), "title": "Tomato Q", "created_at": now, "updated_at": now}
    mock_col = MagicMock()
    mock_col.return_value.find.return_value = [session]
    monkeypatch.setattr(cc, "chat_sessions_col", mock_col)
    r = chatbot_client.get("/api/chatbot/sessions", headers=chatbot_headers)
    assert r.status_code == 200
    assert len(r.get_json()["data"]["sessions"]) == 1


def test_list_sessions_empty(chatbot_client, chatbot_headers, monkeypatch):
    mock_col = MagicMock()
    mock_col.return_value.find.return_value = []
    monkeypatch.setattr(cc, "chat_sessions_col", mock_col)
    r = chatbot_client.get("/api/chatbot/sessions", headers=chatbot_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["sessions"] == []


# ── DELETE /api/chatbot/sessions/<id> ────────────────────────────────────────

def test_delete_session_success(chatbot_client, chatbot_headers, monkeypatch):
    session_id = str(ObjectId())
    mock_sessions = MagicMock()
    mock_sessions.return_value.delete_one.return_value = MagicMock(deleted_count=1)
    mock_messages = MagicMock()
    mock_messages.return_value.delete_many.return_value = None
    monkeypatch.setattr(cc, "chat_sessions_col", mock_sessions)
    monkeypatch.setattr(cc, "chat_messages_col", mock_messages)
    r = chatbot_client.delete(f"/api/chatbot/sessions/{session_id}", headers=chatbot_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["deleted"] is True


def test_delete_session_not_found(chatbot_client, chatbot_headers, monkeypatch):
    session_id = str(ObjectId())
    mock_sessions = MagicMock()
    mock_sessions.return_value.delete_one.return_value = MagicMock(deleted_count=0)
    monkeypatch.setattr(cc, "chat_sessions_col", mock_sessions)
    r = chatbot_client.delete(f"/api/chatbot/sessions/{session_id}", headers=chatbot_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["deleted"] is False


def test_delete_session_invalid_id(chatbot_client, chatbot_headers):
    r = chatbot_client.delete("/api/chatbot/sessions/bad-id", headers=chatbot_headers)
    assert r.status_code == 400


# ── GET /api/chatbot/sessions/<id>/messages ──────────────────────────────────

def test_get_messages_success(chatbot_client, chatbot_headers, monkeypatch):
    now = datetime.now(timezone.utc)
    session_id = ObjectId()
    session = {"_id": session_id, "title": "Q&A", "created_at": now, "updated_at": now}
    msg = {"_id": ObjectId(), "text": "Hello", "is_user": True, "created_at": now}

    mock_sessions = MagicMock()
    mock_sessions.return_value.find_one.return_value = session
    mock_messages = MagicMock()
    mock_messages.return_value.find.return_value = [msg]
    monkeypatch.setattr(cc, "chat_sessions_col", mock_sessions)
    monkeypatch.setattr(cc, "chat_messages_col", mock_messages)

    r = chatbot_client.get(f"/api/chatbot/sessions/{session_id}/messages",
                           headers=chatbot_headers)
    assert r.status_code == 200
    messages = r.get_json()["data"]["messages"]
    assert len(messages) == 1
    assert messages[0]["text"] == "Hello"


def test_get_messages_session_not_found(chatbot_client, chatbot_headers, monkeypatch):
    session_id = ObjectId()
    mock_sessions = MagicMock()
    mock_sessions.return_value.find_one.return_value = None
    monkeypatch.setattr(cc, "chat_sessions_col", mock_sessions)
    r = chatbot_client.get(f"/api/chatbot/sessions/{session_id}/messages",
                           headers=chatbot_headers)
    assert r.status_code == 404


def test_get_messages_invalid_session_id(chatbot_client, chatbot_headers):
    r = chatbot_client.get("/api/chatbot/sessions/not-an-id/messages",
                           headers=chatbot_headers)
    assert r.status_code == 400


# ── POST /api/disease-report ──────────────────────────────────────────────────

def test_disease_report_success(chatbot_client, monkeypatch):
    import app.services.disease_report_service as drs
    fake_report = {
        "what_is_it": "Late Blight is a fungal disease.",
        "urgency_label": "High", "urgency_level": 3,
        "symptoms": ["yellowing leaves"], "immediate_actions": ["remove infected"],
        "treatment_chemical": ["copper"], "treatment_organic": ["neem"],
        "prevention": ["crop rotation"], "scan_again_recommended": True,
    }
    monkeypatch.setattr(drs, "generate_disease_report", lambda **kw: fake_report)
    r = chatbot_client.post("/api/disease-report",
                            json={"disease": "Late Blight", "crop_type": "tomato",
                                  "severity": "high", "confidence": 0.9})
    assert r.status_code == 200
    body = r.get_json()["data"]["report"]
    assert body["urgency_label"] == "High"


def test_disease_report_missing_disease(chatbot_client):
    r = chatbot_client.post("/api/disease-report", json={"crop_type": "tomato"})
    assert r.status_code == 400


def test_disease_report_arabic(chatbot_client, monkeypatch):
    import app.services.disease_report_service as drs
    monkeypatch.setattr(drs, "generate_disease_report",
                        lambda **kw: {"what_is_it": "اللفحة المتأخرة", "urgency_label": "عالية"})
    r = chatbot_client.post("/api/disease-report",
                            json={"disease": "Late Blight", "lang": "ar"})
    assert r.status_code == 200


# ═══════════════════════════════════════════════════════════════════════════════
# Community controller tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def community_client(client_for, monkeypatch, current_user):
    from app.controllers.community_controller import community_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(community_bp)


@pytest.fixture
def community_headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def test_list_communities(community_client, community_headers, monkeypatch):
    import app.models.community as cm
    community = {
        "_id": ObjectId(), "crop_slug": "tomato", "display_name": "Tomato",
        "member_count": 10, "trending_diseases": [], "pinned_post_ids": [],
        "created_at": datetime.now(timezone.utc),
    }
    monkeypatch.setattr(cm, "get_all_communities", lambda: [community])
    monkeypatch.setattr(cm, "serialize", lambda c: {"crop_slug": c["crop_slug"]})
    r = community_client.get("/api/communities", headers=community_headers)
    assert r.status_code == 200
    assert len(r.get_json()["data"]["communities"]) == 1


def test_list_communities_unauthenticated(community_client):
    r = community_client.get("/api/communities")
    assert r.status_code == 401


def test_get_community_found(community_client, community_headers, monkeypatch):
    import app.models.community as cm
    doc = {"_id": ObjectId(), "crop_slug": "wheat"}
    monkeypatch.setattr(cm, "get_community", lambda slug: doc)
    monkeypatch.setattr(cm, "serialize", lambda c: {"crop_slug": c["crop_slug"]})
    r = community_client.get("/api/communities/wheat", headers=community_headers)
    assert r.status_code == 200
    assert r.get_json()["data"]["community"]["crop_slug"] == "wheat"


def test_get_community_not_found(community_client, community_headers, monkeypatch):
    import app.models.community as cm
    monkeypatch.setattr(cm, "get_community", lambda slug: None)
    r = community_client.get("/api/communities/nonexistent", headers=community_headers)
    assert r.status_code == 404


def test_join_community(community_client, community_headers, monkeypatch):
    import app.models.community as cm
    monkeypatch.setattr(cm, "auto_subscribe", lambda uid, slug: None)
    r = community_client.post("/api/communities/wheat/join", headers=community_headers)
    assert r.status_code == 200


# ═══════════════════════════════════════════════════════════════════════════════
# Cache service tests
# ═══════════════════════════════════════════════════════════════════════════════

import app.services.cache as cache_svc


def test_cache_get_no_redis():
    old = cache_svc._redis
    cache_svc._redis = None
    result = cache_svc.get("some_key")
    cache_svc._redis = old
    assert result is None


def test_cache_set_no_redis():
    old = cache_svc._redis
    cache_svc._redis = None
    cache_svc.set("some_key", {"data": 1})  # Should be no-op
    cache_svc._redis = old


def test_cache_delete_no_redis():
    old = cache_svc._redis
    cache_svc._redis = None
    cache_svc.delete("some_key")  # Should be no-op
    cache_svc._redis = old


def test_cache_invalidate_no_redis():
    old = cache_svc._redis
    cache_svc._redis = None
    cache_svc.invalidate_pattern("prefix:*")  # Should be no-op
    cache_svc._redis = old


def test_cache_get_with_redis():
    mock_redis = MagicMock()
    mock_redis.get.return_value = b'{"key": "value"}'
    old = cache_svc._redis
    cache_svc._redis = mock_redis
    result = cache_svc.get("test_key")
    cache_svc._redis = old
    assert result == {"key": "value"}


def test_cache_get_miss():
    mock_redis = MagicMock()
    mock_redis.get.return_value = None
    old = cache_svc._redis
    cache_svc._redis = mock_redis
    result = cache_svc.get("missing_key")
    cache_svc._redis = old
    assert result is None


def test_cache_get_exception():
    mock_redis = MagicMock()
    mock_redis.get.side_effect = Exception("Redis error")
    old = cache_svc._redis
    cache_svc._redis = mock_redis
    result = cache_svc.get("bad_key")  # Should return None on exception
    cache_svc._redis = old
    assert result is None


def test_cache_set_with_redis():
    mock_redis = MagicMock()
    old = cache_svc._redis
    cache_svc._redis = mock_redis
    cache_svc.set("key", {"value": 1}, ttl=60)
    cache_svc._redis = old
    mock_redis.setex.assert_called_once()


def test_cache_set_exception():
    mock_redis = MagicMock()
    mock_redis.setex.side_effect = Exception("Connection failed")
    old = cache_svc._redis
    cache_svc._redis = mock_redis
    cache_svc.set("key", {"val": 1})  # Should not raise
    cache_svc._redis = old


def test_cache_delete_with_redis():
    mock_redis = MagicMock()
    old = cache_svc._redis
    cache_svc._redis = mock_redis
    cache_svc.delete("key_to_delete")
    cache_svc._redis = old
    mock_redis.delete.assert_called_once_with("key_to_delete")


def test_cache_invalidate_pattern():
    mock_redis = MagicMock()
    mock_redis.scan_iter.return_value = ["prefix:1", "prefix:2"]
    old = cache_svc._redis
    cache_svc._redis = mock_redis
    cache_svc.invalidate_pattern("prefix:*")
    cache_svc._redis = old
    assert mock_redis.delete.call_count == 2


def test_cache_invalidate_exception():
    mock_redis = MagicMock()
    mock_redis.scan_iter.side_effect = Exception("Scan error")
    old = cache_svc._redis
    cache_svc._redis = mock_redis
    cache_svc.invalidate_pattern("bad:*")  # Should not raise
    cache_svc._redis = old


def test_init_cache_unreachable(flask_app):
    from flask import Flask
    test_app = Flask(__name__)
    test_app.config["REDIS_URL"] = "redis://127.0.0.1:19999/"
    with patch("redis.from_url") as mock_redis:
        mock_redis.return_value.ping.side_effect = Exception("connection refused")
        cache_svc.init_cache(test_app)
    assert cache_svc._redis is None


# ═══════════════════════════════════════════════════════════════════════════════
# Disease report service tests
# ═══════════════════════════════════════════════════════════════════════════════

import app.services.disease_report_service as drs


def test_disease_report_fallback_no_api_key(monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "")
    drs._client = None  # reset client
    result = drs.generate_disease_report(
        disease="Late Blight", crop_type="tomato",
        severity="high", confidence=0.9,
    )
    assert "what_is_it" in result
    assert "urgency_label" in result
    assert "symptoms" in result
    assert isinstance(result["symptoms"], list)


def test_disease_report_fallback_arabic(monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "")
    drs._client = None
    result = drs.generate_disease_report(
        disease="اللفحة المتأخرة", crop_type="طماطم",
        severity="high", confidence=0.8, lang="ar",
    )
    assert "what_is_it" in result
    assert "urgency_label" in result


def test_disease_report_with_groq_success(monkeypatch):
    import json
    fake_report = {
        "what_is_it": "A fungal disease", "urgency_label": "High",
        "urgency_level": 3, "estimated_impact": "50%", "how_spreads": "Wind",
        "symptoms": ["yellowing"], "immediate_actions": ["remove"],
        "treatment_chemical": ["copper spray"], "treatment_organic": ["neem"],
        "prevention": ["rotation"], "scan_again_recommended": True,
        "confidence_note": "90% confident",
    }
    mock_client = MagicMock()
    mock_completion = MagicMock()
    mock_completion.choices[0].message.content = json.dumps(fake_report)
    mock_client.chat.completions.create.return_value = mock_completion

    # Patch _get_client directly so the real Groq class is never instantiated
    monkeypatch.setattr(drs, "_get_client", lambda: mock_client)
    result = drs.generate_disease_report(
        disease="Late Blight", crop_type="tomato",
        severity="high", confidence=0.9,
    )
    assert result["urgency_label"] == "High"


def test_disease_report_groq_fallback_on_error(monkeypatch):
    mock_client = MagicMock()
    mock_client.chat.completions.create.side_effect = Exception("Groq API error")
    monkeypatch.setattr(drs, "_get_client", lambda: mock_client)
    result = drs.generate_disease_report(
        disease="Blight", crop_type="tomato",
        severity="medium", confidence=0.75,
    )
    assert "what_is_it" in result  # fallback
