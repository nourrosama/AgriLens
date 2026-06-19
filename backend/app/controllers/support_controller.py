"""
Support / contact-us controller.

User-facing:
  POST /api/support/tickets          — submit first message (creates ticket)
  GET  /api/support/tickets          — list own tickets with messages
  POST /api/support/tickets/<id>/messages — follow-up reply from user

Admin:
  GET  /api/admin/support/tickets          — list all tickets
  POST /api/admin/support/tickets/<id>/reply — admin replies to a ticket
  PUT  /api/admin/support/tickets/<id>/status — close / reopen a ticket
"""
import uuid
from datetime import datetime, timezone

from bson import ObjectId
from flask import Blueprint, g, request

from app.middleware.auth_middleware import require_auth
from app.middleware.admin_middleware import require_admin
from app.models import notification_model, user_model
from app.models.db import get_db
from app.services import push_service
from app.views.responses import error_response, success_response

support_bp = Blueprint('support', __name__)


# ── Helpers ────────────────────────────────────────────────────────────────────

def _tickets_col():
    return get_db()['support_tickets']


def _make_message(sender: str, sender_name: str, text: str) -> dict:
    return {
        'id': str(uuid.uuid4()),
        'sender': sender,          # 'user' | 'admin'
        'sender_name': sender_name,
        'text': text,
        'created_at': datetime.now(timezone.utc),
    }


def _serialize_message(m: dict) -> dict:
    ts = m.get('created_at')
    return {
        'id': m.get('id', ''),
        'sender': m.get('sender', ''),
        'sender_name': m.get('sender_name', ''),
        'text': m.get('text', ''),
        'created_at': ts.isoformat() if ts else None,
    }


def _serialize_ticket(t: dict, include_messages: bool = True) -> dict:
    out = {
        'id': str(t['_id']),
        'user_id': str(t.get('user_id', '')),
        'user_name': t.get('user_name', ''),
        'user_email': t.get('user_email', ''),
        'subject': t.get('subject', ''),
        'status': t.get('status', 'open'),
        'created_at': t['created_at'].isoformat() if t.get('created_at') else None,
        'updated_at': t['updated_at'].isoformat() if t.get('updated_at') else None,
    }
    if include_messages:
        out['messages'] = [_serialize_message(m) for m in t.get('messages', [])]
    return out


def _send_admin_email_notification(ticket: dict, first_message: str):
    """Email the admin and send a confirmation to the user when a ticket is submitted."""
    from flask import current_app
    from app.services.auth_service import (
        send_support_email_to_admin,
        send_support_confirmation_to_user,
    )
    user_name = ticket.get('user_name', '')
    user_email = ticket.get('user_email', '')
    subject = ticket.get('subject', '')

    try:
        send_support_email_to_admin(
            ticket_id=str(ticket['_id']),
            user_name=user_name,
            user_email=user_email,
            subject=subject,
            message=first_message,
        )
    except Exception as exc:
        current_app.logger.warning('Support email to admin failed: %s', exc)

    try:
        send_support_confirmation_to_user(
            user_email=user_email,
            user_name=user_name,
            subject=subject,
            message=first_message,
        )
    except Exception as exc:
        current_app.logger.warning('Support confirmation to user failed: %s', exc)


# ── User endpoints ─────────────────────────────────────────────────────────────

@support_bp.route('/api/support/tickets', methods=['POST'])
@require_auth
def create_ticket():
    """Submit a new support message.  Creates a ticket (one active per user)."""
    data = request.get_json(silent=True) or {}
    subject = str(data.get('subject', '')).strip()
    message_text = str(data.get('message', '')).strip()

    if not subject:
        return error_response('Subject is required', 400)
    if not message_text:
        return error_response('Message is required', 400)

    user = g.current_user
    user_id = str(user['_id'])

    first_msg = _make_message(
        sender='user',
        sender_name=user.get('name', 'User'),
        text=message_text,
    )
    now = datetime.now(timezone.utc)
    doc = {
        'user_id': ObjectId(user_id),
        'user_name': user.get('name', ''),
        'user_email': user.get('email', ''),
        'subject': subject,
        'status': 'open',
        'created_at': now,
        'updated_at': now,
        'messages': [first_msg],
    }
    result = _tickets_col().insert_one(doc)
    doc['_id'] = result.inserted_id

    _send_admin_email_notification(doc, message_text)

    return success_response(
        {'ticket': _serialize_ticket(doc)},
        'Your message has been sent. We will reply shortly.',
        201,
    )


@support_bp.route('/api/support/tickets', methods=['GET'])
@require_auth
def list_my_tickets():
    """Return all tickets (with messages) for the logged-in user."""
    user_id = str(g.current_user['_id'])
    tickets = list(
        _tickets_col()
        .find({'user_id': ObjectId(user_id)})
        .sort('updated_at', -1)
    )
    return success_response({'tickets': [_serialize_ticket(t) for t in tickets]})


@support_bp.route('/api/support/tickets/<ticket_id>/messages', methods=['POST'])
@require_auth
def add_user_message(ticket_id: str):
    """User sends a follow-up message to an existing ticket."""
    try:
        oid = ObjectId(ticket_id)
    except Exception:
        return error_response('Invalid ticket ID', 400)

    ticket = _tickets_col().find_one({
        '_id': oid,
        'user_id': ObjectId(str(g.current_user['_id'])),
    })
    if not ticket:
        return error_response('Ticket not found', 404)
    if ticket.get('status') == 'closed':
        return error_response('This ticket is closed', 400)

    data = request.get_json(silent=True) or {}
    message_text = str(data.get('message', '')).strip()
    if not message_text:
        return error_response('Message is required', 400)

    msg = _make_message(
        sender='user',
        sender_name=g.current_user.get('name', 'User'),
        text=message_text,
    )
    now = datetime.now(timezone.utc)
    _tickets_col().update_one(
        {'_id': oid},
        {
            '$push': {'messages': msg},
            '$set': {'updated_at': now, 'status': 'open'},
        },
    )
    ticket = _tickets_col().find_one({'_id': oid})
    return success_response({'ticket': _serialize_ticket(ticket)}, 'Message sent')


# ── Admin endpoints ────────────────────────────────────────────────────────────

@support_bp.route('/api/admin/support/tickets', methods=['GET'])
@require_admin
def admin_list_tickets():
    """Admin: list all support tickets, newest first."""
    status = request.args.get('status')  # optional filter: open | replied | closed
    query = {}
    if status:
        query['status'] = status
    tickets = list(_tickets_col().find(query).sort('updated_at', -1).limit(200))
    return success_response({'tickets': [_serialize_ticket(t) for t in tickets]})


@support_bp.route('/api/admin/support/tickets/<ticket_id>/reply', methods=['POST'])
@require_admin
def admin_reply(ticket_id: str):
    """Admin: post a reply to a support ticket and notify the user."""
    try:
        oid = ObjectId(ticket_id)
    except Exception:
        return error_response('Invalid ticket ID', 400)

    ticket = _tickets_col().find_one({'_id': oid})
    if not ticket:
        return error_response('Ticket not found', 404)

    data = request.get_json(silent=True) or {}
    reply_text = str(data.get('message', '')).strip()
    if not reply_text:
        return error_response('Reply message is required', 400)

    msg = _make_message(
        sender='admin',
        sender_name='AgriLens Support',
        text=reply_text,
    )
    now = datetime.now(timezone.utc)
    _tickets_col().update_one(
        {'_id': oid},
        {
            '$push': {'messages': msg},
            '$set': {'updated_at': now, 'status': 'replied'},
        },
    )

    # ── Notify the user ────────────────────────────────────────────────────
    user_id = str(ticket.get('user_id', ''))
    if user_id:
        user = user_model.find_by_id(user_id)
        if user:
            # In-app notification
            notification_model.create_notification(
                user_id=user_id,
                title='Support Reply',
                message=f'You have a new reply to: {ticket.get("subject", "your message")}',
                category='support',
                metadata={'ticket_id': ticket_id},
            )
            # FCM push
            push_service.send_push_to_user(
                user=user,
                title='New reply from AgriLens Support',
                body=f'Re: {ticket.get("subject", "your message")}',
                data={'ticket_id': ticket_id, 'type': 'support_reply'},
            )

    ticket = _tickets_col().find_one({'_id': oid})
    return success_response({'ticket': _serialize_ticket(ticket)}, 'Reply sent')


@support_bp.route('/api/admin/support/tickets/<ticket_id>/status', methods=['PUT'])
@require_admin
def admin_update_status(ticket_id: str):
    """Admin: change ticket status (open | replied | closed)."""
    try:
        oid = ObjectId(ticket_id)
    except Exception:
        return error_response('Invalid ticket ID', 400)

    data = request.get_json(silent=True) or {}
    new_status = str(data.get('status', '')).strip()
    if new_status not in ('open', 'replied', 'closed'):
        return error_response('Status must be open, replied, or closed', 400)

    result = _tickets_col().update_one(
        {'_id': oid},
        {'$set': {'status': new_status, 'updated_at': datetime.now(timezone.utc)}},
    )
    if result.matched_count == 0:
        return error_response('Ticket not found', 404)

    ticket = _tickets_col().find_one({'_id': oid})
    return success_response({'ticket': _serialize_ticket(ticket)}, f'Ticket marked as {new_status}')
