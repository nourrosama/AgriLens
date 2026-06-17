"""
Subscription middleware — plan-level access guards.

Usage:
    @require_plan('premium')
    def my_view():
        ...
"""
from functools import wraps
from flask import g
from app.services.subscription_service import plan_meets_minimum, UPGRADE_MESSAGES
from app.views.responses import error_response


def require_plan(minimum_plan: str):
    """Decorator that rejects the request with 403 if the user's plan is below `minimum_plan`.

    Must be applied AFTER @require_auth so that g.current_user is available.

    Example:
        @chatbot_bp.route('/api/chatbot', methods=['POST'])
        @require_auth
        @require_plan('premium')
        def chat():
            ...
    """
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            user = getattr(g, 'current_user', None)
            if user is None:
                return error_response('Authentication required', 401)
            if not plan_meets_minimum(user, minimum_plan):
                return error_response(
                    UPGRADE_MESSAGES.get(minimum_plan, f'This feature requires a {minimum_plan} plan.'),
                    403,
                    extra={'upgrade_required': True, 'required_plan': minimum_plan},
                )
            return f(*args, **kwargs)
        return wrapper
    return decorator
