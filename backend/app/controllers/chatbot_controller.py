"""
Rule-based chatbot controller for the mobile assistant.
"""
from flask import Blueprint, request, g
from app.middleware.auth_middleware import require_auth
from app.services import insights_service
from app.views.responses import success_response, error_response

chatbot_bp = Blueprint('chatbot', __name__)


# Public test endpoint for development - no auth required
@chatbot_bp.route('/api/chatbot-test', methods=['POST'])
def chat_test():
    """Public chatbot endpoint for testing (no auth required)."""
    data = request.get_json(silent=True) or {}
    message = (data.get('message') or '').strip()
    if not message:
        return error_response('Message is required', 400)
    response = insights_service.build_chat_response(message)
    return success_response({'message': response, 'user_id': 'test-user'})


@chatbot_bp.route('/api/chatbot', methods=['POST'])
@require_auth
def chat():
    """Return a simple assistant response for the provided message."""
    data = request.get_json(silent=True) or {}
    message = (data.get('message') or '').strip()
    if not message:
        return error_response('Message is required', 400)
    response = insights_service.build_chat_response(message)
    return success_response({'message': response, 'user_id': str(g.current_user['_id'])})
