"""
AI-powered chatbot controller using Groq API.
Chat history is persisted to MongoDB (chat_sessions / chat_messages collections).
"""
import logging
from datetime import datetime, timezone

from bson import ObjectId
from flask import Blueprint, request, g

from app.middleware.auth_middleware import require_auth
from app.services import chatbot_service, disease_report_service
from app.models.db import chat_sessions_col, chat_messages_col
from app.views.responses import success_response, error_response

chatbot_bp = Blueprint('chatbot', __name__)
_log = logging.getLogger(__name__)


# ── helpers ───────────────────────────────────────────────────────────────────

def _session_to_dict(s):
    return {
        'id': str(s['_id']),
        'title': s.get('title', ''),
        'created_at': s['created_at'].isoformat(),
        'updated_at': s['updated_at'].isoformat(),
    }


def _message_to_dict(m):
    return {
        'id': str(m['_id']),
        'text': m['text'],
        'is_user': m['is_user'],
        'created_at': m['created_at'].isoformat(),
    }


# ── public test endpoint (no auth) ───────────────────────────────────────────

@chatbot_bp.route('/api/chatbot-test', methods=['POST'])
def chat_test():
    """Public chatbot endpoint for testing (no auth required)."""
    data = request.get_json(silent=True) or {}
    message = (data.get('message') or '').strip()
    lang = (data.get('lang') or 'en').strip()
    if not message:
        return error_response('Message is required', 400)
    response = chatbot_service.get_ai_response(message, lang)
    return success_response({'message': response, 'user_id': 'test-user'})


# ── authenticated chat (saves history) ───────────────────────────────────────

@chatbot_bp.route('/api/chatbot', methods=['POST'])
@require_auth
def chat():
    """Return an AI-powered assistant response and persist the exchange."""
    data = request.get_json(silent=True) or {}
    message = (data.get('message') or '').strip()
    lang = (data.get('lang') or 'en').strip()
    session_id = (data.get('session_id') or '').strip() or None

    if not message:
        return error_response('Message is required', 400)

    user_id = str(g.current_user['_id'])
    now = datetime.now(timezone.utc)

    # Call AI first — we still return even if DB write fails
    response_dict = chatbot_service.get_ai_response(message, lang)

    returned_session_id = None
    try:
        sessions = chat_sessions_col()
        messages = chat_messages_col()

        # Resolve or create a session
        current_session = None
        if session_id:
            try:
                current_session = sessions.find_one(
                    {'_id': ObjectId(session_id), 'user_id': user_id}
                )
            except Exception:
                pass  # bad ObjectId — treat as new session

        if current_session is None:
            title = message[:45] + '…' if len(message) > 45 else message
            result = sessions.insert_one({
                'user_id': user_id,
                'title': title,
                'created_at': now,
                'updated_at': now,
            })
            returned_session_id = str(result.inserted_id)
        else:
            returned_session_id = str(current_session['_id'])
            sessions.update_one(
                {'_id': ObjectId(returned_session_id)},
                {'$set': {'updated_at': now}},
            )

        # Persist user message + AI reply as a pair
        messages.insert_many([
            {
                'session_id': returned_session_id,
                'user_id': user_id,
                'text': message,
                'is_user': True,
                'created_at': now,
            },
            {
                'session_id': returned_session_id,
                'user_id': user_id,
                'text': response_dict['reply'],
                'is_user': False,
                'created_at': now,
            },
        ])
    except Exception as exc:
        _log.warning('Chat history save failed: %s', exc)
        returned_session_id = None

    return success_response({
        'message': response_dict,
        'session_id': returned_session_id,
        'user_id': user_id,
    })


# ── session list ──────────────────────────────────────────────────────────────

@chatbot_bp.route('/api/chatbot/sessions', methods=['GET'])
@require_auth
def list_sessions():
    """Return all chat sessions for the authenticated user, newest first."""
    user_id = str(g.current_user['_id'])
    docs = list(
        chat_sessions_col().find(
            {'user_id': user_id},
            sort=[('updated_at', -1)],
        )
    )
    return success_response({'sessions': [_session_to_dict(s) for s in docs]})


# ── delete session ────────────────────────────────────────────────────────────

@chatbot_bp.route('/api/chatbot/sessions/<session_id>', methods=['DELETE'])
@require_auth
def delete_session(session_id):
    """Delete a chat session and all its messages."""
    user_id = str(g.current_user['_id'])
    try:
        oid = ObjectId(session_id)
    except Exception:
        return error_response('Invalid session ID', 400)

    result = chat_sessions_col().delete_one({'_id': oid, 'user_id': user_id})
    if result.deleted_count:
        chat_messages_col().delete_many({'session_id': session_id})

    return success_response({'deleted': result.deleted_count > 0})


# ── messages for a session ────────────────────────────────────────────────────

@chatbot_bp.route('/api/chatbot/sessions/<session_id>/messages', methods=['GET'])
@require_auth
def get_messages(session_id):
    """Return all messages in a session (oldest first)."""
    user_id = str(g.current_user['_id'])
    try:
        oid = ObjectId(session_id)
    except Exception:
        return error_response('Invalid session ID', 400)

    session = chat_sessions_col().find_one({'_id': oid, 'user_id': user_id})
    if not session:
        return error_response('Session not found', 404)

    msgs = list(
        chat_messages_col().find(
            {'session_id': session_id},
            sort=[('created_at', 1)],
        )
    )
    return success_response({'messages': [_message_to_dict(m) for m in msgs]})


# ── disease report (public) ───────────────────────────────────────────────────

@chatbot_bp.route('/api/disease-report', methods=['POST'])
def get_disease_report():
    """Generate a structured AI disease report for a scan result (no auth required)."""
    data = request.get_json(silent=True) or {}
    disease = (data.get('disease') or '').strip()
    if not disease:
        return error_response('disease is required', 400)

    report = disease_report_service.generate_disease_report(
        disease=disease,
        crop_type=(data.get('crop_type') or 'unknown').strip(),
        severity=(data.get('severity') or 'medium').strip(),
        confidence=float(data.get('confidence') or 0.5),
        scientific_name=(data.get('scientific_name') or '').strip(),
        lang=(data.get('lang') or 'en').strip(),
    )
    return success_response({'report': report})
