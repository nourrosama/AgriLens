"""
Support controller — comprehensive endpoint tests.
Tests user ticket CRUD + admin reply/status endpoints.
"""
import pytest
from unittest.mock import MagicMock, patch
from bson import ObjectId
from datetime import datetime, timezone


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def support_client(client_for, monkeypatch, current_user):
    from app.controllers.support_controller import support_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: current_user)
    return client_for(support_bp)


@pytest.fixture
def admin_user(user_id):
    return {
        "_id": ObjectId(user_id),
        "phone": "+201000000001",
        "name": "Admin",
        "role": "admin",
        "language": "en",
        "farms": [],
    }


@pytest.fixture
def admin_support_client(client_for, monkeypatch, admin_user):
    from app.controllers.support_controller import support_bp
    from app.middleware import auth_middleware
    monkeypatch.setattr(auth_middleware.user_model, "find_by_id", lambda _id: admin_user)
    return client_for(support_bp)


@pytest.fixture
def headers(user_id):
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from conftest import make_token
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def _fake_ticket(user_id, ticket_id=None):
    now = datetime.now(timezone.utc)
    return {
        "_id": ticket_id or ObjectId(),
        "user_id": ObjectId(user_id),
        "user_name": "QA Farmer",
        "user_email": "qa@example.com",
        "subject": "My plants are sick",
        "status": "open",
        "created_at": now,
        "updated_at": now,
        "messages": [],
    }


# ── POST /api/support/tickets ─────────────────────────────────────────────────

def test_create_ticket_success(support_client, headers, monkeypatch, user_id):
    from app.controllers import support_controller
    ticket_id = ObjectId()
    inserted_ticket = _fake_ticket(user_id, ticket_id)

    mock_col = MagicMock()
    mock_col.return_value.insert_one.return_value = MagicMock(inserted_id=ticket_id)
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)
    monkeypatch.setattr(support_controller, "_send_admin_email_notification",
                        lambda ticket, msg: None)

    r = support_client.post("/api/support/tickets",
                            json={"subject": "My plants are sick",
                                  "message": "Leaves are turning yellow"},
                            headers=headers)
    assert r.status_code == 201
    body = r.get_json()
    assert body["data"]["ticket"]["subject"] == "My plants are sick"


def test_create_ticket_missing_subject(support_client, headers):
    r = support_client.post("/api/support/tickets",
                            json={"message": "Hello"}, headers=headers)
    assert r.status_code == 400


def test_create_ticket_missing_message(support_client, headers):
    r = support_client.post("/api/support/tickets",
                            json={"subject": "Help"}, headers=headers)
    assert r.status_code == 400


def test_create_ticket_unauthenticated(support_client):
    r = support_client.post("/api/support/tickets",
                            json={"subject": "Help", "message": "Hello"})
    assert r.status_code == 401


# ── GET /api/support/tickets ──────────────────────────────────────────────────

def test_list_my_tickets(support_client, headers, monkeypatch, user_id):
    from app.controllers import support_controller
    ticket = _fake_ticket(user_id)

    mock_col = MagicMock()
    mock_col.return_value.find.return_value = MagicMock(
        sort=lambda *a: [ticket]
    )
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)

    r = support_client.get("/api/support/tickets", headers=headers)
    assert r.status_code == 200
    body = r.get_json()
    assert len(body["data"]["tickets"]) == 1


def test_list_tickets_unauthenticated(support_client):
    r = support_client.get("/api/support/tickets")
    assert r.status_code == 401


# ── POST /api/support/tickets/<id>/messages ───────────────────────────────────

def test_add_user_message_success(support_client, headers, monkeypatch, user_id):
    from app.controllers import support_controller
    ticket_id = ObjectId()
    ticket = _fake_ticket(user_id, ticket_id)

    mock_col = MagicMock()
    mock_col.return_value.find_one.side_effect = [ticket, ticket]
    mock_col.return_value.update_one.return_value = None
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)

    r = support_client.post(f"/api/support/tickets/{ticket_id}/messages",
                            json={"message": "Follow-up message"}, headers=headers)
    assert r.status_code == 200


def test_add_user_message_invalid_id(support_client, headers):
    r = support_client.post("/api/support/tickets/not-valid-id/messages",
                            json={"message": "Hi"}, headers=headers)
    assert r.status_code == 400


def test_add_user_message_ticket_not_found(support_client, headers, monkeypatch, user_id):
    from app.controllers import support_controller
    mock_col = MagicMock()
    mock_col.return_value.find_one.return_value = None
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)

    r = support_client.post(f"/api/support/tickets/{ObjectId()}/messages",
                            json={"message": "Hi"}, headers=headers)
    assert r.status_code == 404


def test_add_user_message_ticket_closed(support_client, headers, monkeypatch, user_id):
    from app.controllers import support_controller
    ticket_id = ObjectId()
    ticket = {**_fake_ticket(user_id, ticket_id), "status": "closed"}
    mock_col = MagicMock()
    mock_col.return_value.find_one.return_value = ticket
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)

    r = support_client.post(f"/api/support/tickets/{ticket_id}/messages",
                            json={"message": "Can I reopen?"}, headers=headers)
    assert r.status_code == 400


def test_add_user_message_empty_message(support_client, headers, monkeypatch, user_id):
    from app.controllers import support_controller
    ticket_id = ObjectId()
    ticket = _fake_ticket(user_id, ticket_id)
    mock_col = MagicMock()
    mock_col.return_value.find_one.return_value = ticket
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)

    r = support_client.post(f"/api/support/tickets/{ticket_id}/messages",
                            json={"message": ""}, headers=headers)
    assert r.status_code == 400


# ── GET /api/admin/support/tickets ────────────────────────────────────────────

def test_admin_list_tickets(admin_support_client, headers, monkeypatch):
    from app.controllers import support_controller
    mock_col = MagicMock()
    mock_col.return_value.find.return_value = MagicMock(
        sort=lambda *a: MagicMock(limit=lambda n: [])
    )
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)
    r = admin_support_client.get("/api/admin/support/tickets", headers=headers)
    assert r.status_code == 200


def test_admin_list_tickets_with_status_filter(admin_support_client, headers, monkeypatch):
    from app.controllers import support_controller
    mock_col = MagicMock()
    mock_col.return_value.find.return_value = MagicMock(
        sort=lambda *a: MagicMock(limit=lambda n: [])
    )
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)
    r = admin_support_client.get("/api/admin/support/tickets?status=open", headers=headers)
    assert r.status_code == 200


def test_admin_list_tickets_forbidden_for_farmer(support_client, headers):
    r = support_client.get("/api/admin/support/tickets", headers=headers)
    assert r.status_code == 403


# ── POST /api/admin/support/tickets/<id>/reply ────────────────────────────────

def test_admin_reply_success(admin_support_client, headers, monkeypatch, user_id, admin_user):
    from app.controllers import support_controller
    from app.models import notification_model as nm
    from app.middleware import auth_middleware
    import app.services.push_service as ps

    ticket_id = ObjectId()
    user_oid = ObjectId(user_id)
    ticket = _fake_ticket(user_id, ticket_id)
    ticket["user_id"] = user_oid

    mock_col = MagicMock()
    mock_col.return_value.find_one.side_effect = [ticket, {**ticket, "status": "replied"}]
    mock_col.return_value.update_one.return_value = None
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)

    fake_user = {"_id": user_oid, "name": "Farmer", "language": "en"}
    # Smart mock: auth check returns admin_user, ticket-owner lookup returns fake_user
    monkeypatch.setattr(
        auth_middleware.user_model, "find_by_id",
        lambda uid: admin_user if str(uid) == user_id else fake_user,
    )
    monkeypatch.setattr(nm, "create_notification", lambda **kw: None)
    monkeypatch.setattr(ps, "send_push_to_user", lambda **kw: None)

    r = admin_support_client.post(f"/api/admin/support/tickets/{ticket_id}/reply",
                                  json={"message": "We are looking into it"},
                                  headers=headers)
    assert r.status_code == 200


def test_admin_reply_invalid_id(admin_support_client, headers):
    r = admin_support_client.post("/api/admin/support/tickets/bad-id/reply",
                                  json={"message": "Hi"}, headers=headers)
    assert r.status_code == 400


def test_admin_reply_not_found(admin_support_client, headers, monkeypatch):
    from app.controllers import support_controller
    mock_col = MagicMock()
    mock_col.return_value.find_one.return_value = None
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)
    r = admin_support_client.post(f"/api/admin/support/tickets/{ObjectId()}/reply",
                                  json={"message": "Hi"}, headers=headers)
    assert r.status_code == 404


def test_admin_reply_empty_message(admin_support_client, headers, monkeypatch, user_id):
    from app.controllers import support_controller
    ticket_id = ObjectId()
    mock_col = MagicMock()
    mock_col.return_value.find_one.return_value = _fake_ticket(user_id, ticket_id)
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)
    r = admin_support_client.post(f"/api/admin/support/tickets/{ticket_id}/reply",
                                  json={"message": ""}, headers=headers)
    assert r.status_code == 400


def test_admin_reply_no_user_found(admin_support_client, headers, monkeypatch, user_id, admin_user):
    from app.controllers import support_controller
    from app.middleware import auth_middleware

    ticket_id = ObjectId()
    # Use a DIFFERENT user_id for the ticket owner (not the admin's JWT user_id)
    other_user_id = str(ObjectId())
    ticket = _fake_ticket(other_user_id, ticket_id)
    updated_ticket = {**ticket, "status": "replied"}
    mock_col = MagicMock()
    mock_col.return_value.find_one.side_effect = [ticket, updated_ticket]
    mock_col.return_value.update_one.return_value = None
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)

    # Auth check (JWT user_id) → admin_user; ticket-owner lookup (other_user_id) → None
    monkeypatch.setattr(
        auth_middleware.user_model, "find_by_id",
        lambda uid: admin_user if str(uid) == user_id else None,
    )
    r = admin_support_client.post(f"/api/admin/support/tickets/{ticket_id}/reply",
                                  json={"message": "Reply"}, headers=headers)
    assert r.status_code == 200


# ── PUT /api/admin/support/tickets/<id>/status ────────────────────────────────

def test_admin_update_status_success(admin_support_client, headers, monkeypatch, user_id):
    from app.controllers import support_controller
    ticket_id = ObjectId()
    ticket = {**_fake_ticket(user_id, ticket_id), "status": "closed"}
    mock_col = MagicMock()
    result = MagicMock()
    result.matched_count = 1
    mock_col.return_value.update_one.return_value = result
    mock_col.return_value.find_one.return_value = ticket
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)
    r = admin_support_client.put(f"/api/admin/support/tickets/{ticket_id}/status",
                                 json={"status": "closed"}, headers=headers)
    assert r.status_code == 200


def test_admin_update_status_invalid_status(admin_support_client, headers):
    r = admin_support_client.put(f"/api/admin/support/tickets/{ObjectId()}/status",
                                 json={"status": "pending"}, headers=headers)
    assert r.status_code == 400


def test_admin_update_status_invalid_id(admin_support_client, headers):
    r = admin_support_client.put("/api/admin/support/tickets/bad-id/status",
                                 json={"status": "closed"}, headers=headers)
    assert r.status_code == 400


def test_admin_update_status_not_found(admin_support_client, headers, monkeypatch):
    from app.controllers import support_controller
    mock_col = MagicMock()
    result = MagicMock()
    result.matched_count = 0
    mock_col.return_value.update_one.return_value = result
    monkeypatch.setattr(support_controller, "_tickets_col", mock_col)
    r = admin_support_client.put(f"/api/admin/support/tickets/{ObjectId()}/status",
                                 json={"status": "closed"}, headers=headers)
    assert r.status_code == 404
