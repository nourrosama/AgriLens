"""
Admin authorization middleware.
Provides @require_admin — stacks on top of @require_auth.
"""
from functools import wraps
from flask import g
from app.middleware.auth_middleware import require_auth
from app.views.responses import error_response


def require_admin(f):
    """Decorator — allows only users with role='admin'.
    Must be applied AFTER @require_auth (or stacked: @require_auth then @require_admin).
    Combines both checks so a single decorator is enough.
    """
    @wraps(f)
    @require_auth
    def decorated(*args, **kwargs):
        if g.current_user.get('role') != 'admin':
            return error_response('Admin access required', 403)
        return f(*args, **kwargs)
    return decorated
