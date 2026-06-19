"""Shared Flask extensions."""

try:
    from flask_limiter import Limiter
    from flask_limiter.util import get_remote_address
except ImportError:  # pragma: no cover - local env may install deps after code checkout.
    class _NoopLimiter:
        def init_app(self, *args, **kwargs):
            return None

        def limit(self, *args, **kwargs):
            def decorator(func):
                return func

            return decorator

    limiter = _NoopLimiter()
else:
    limiter = Limiter(key_func=get_remote_address)
