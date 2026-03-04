"""
JWT authentication middleware.
Provides a @require_auth decorator for protected endpoints.
"""
import jwt
from functools import wraps
from flask import request, g, current_app
from app.models import user_model
from app.views.responses import error_response


def require_auth(f):
    """Decorator — rejects requests without a valid JWT.
    Sets g.current_user to the authenticated user document.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        token = _extract_token()
        if token is None:
            return error_response('Authorization header missing', 401)

        try:
            payload = jwt.decode(
                token,
                current_app.config['JWT_SECRET'],
                algorithms=['HS256'],
            )
        except jwt.ExpiredSignatureError:
            return error_response('Token expired', 401)
        except jwt.InvalidTokenError:
            return error_response('Invalid token', 401)

        user = user_model.find_by_id(payload.get('sub'))
        if user is None:
            return error_response('User not found', 401)

        g.current_user = user
        return f(*args, **kwargs)

    return decorated


def _extract_token() -> str | None:
    """Pull Bearer token from Authorization header."""
    header = request.headers.get('Authorization', '')
    if header.startswith('Bearer '):
        return header[7:]
    return None
