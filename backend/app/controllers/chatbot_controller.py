"""
AI-powered chatbot controller using Groq API.
"""
from flask import Blueprint, request, g
from app.middleware.auth_middleware import require_auth
from app.services import chatbot_service
from app.views.responses import success_response, error_response

chatbot_bp = Blueprint('chatbot', __name__)

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

@chatbot_bp.route('/api/chatbot', methods=['POST'])
@require_auth
def chat():
    """Return an AI-powered assistant response."""
    data = request.get_json(silent=True) or {}
    message = (data.get('message') or '').strip()
    lang = (data.get('lang') or 'en').strip()
    if not message:
        return error_response('Message is required', 400)
    response = chatbot_service.get_ai_response(message, lang)
    return success_response({'message': response, 'user_id': str(g.current_user['_id'])})