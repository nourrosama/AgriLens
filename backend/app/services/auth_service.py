"""
Auth service — Twilio Verify OTP + JWT token management.
Falls back to mock mode (console OTP) when Twilio creds are absent.
"""
import jwt
import redis
import logging
from datetime import datetime, timedelta, timezone
from flask import current_app

logger = logging.getLogger(__name__)

_redis = None
_twilio_client = None
_verify_sid = None


def init_auth_service(app):
    """Initialize Redis (rate limiting) and Twilio client."""
    global _redis, _twilio_client, _verify_sid

    # Redis for rate limiting
    try:
        _redis = redis.from_url(app.config.get('REDIS_URL', 'redis://localhost:6379/0'))
        _redis.ping()
        app.logger.info('✅ Redis connected (auth rate limiting)')
    except Exception as e:
        app.logger.warning(f'⚠️  Redis not reachable: {e} — rate limiting disabled')
        _redis = None

    # Twilio Verify
    sid = app.config.get('TWILIO_ACCOUNT_SID', '')
    token = app.config.get('TWILIO_AUTH_TOKEN', '')
    _verify_sid = app.config.get('TWILIO_VERIFY_SERVICE_SID', '')

    if sid and token and _verify_sid and not app.config.get('TWILIO_MOCK_MODE', True):
        try:
            from twilio.rest import Client
            _twilio_client = Client(sid, token)
            app.logger.info('✅ Twilio Verify initialised')
        except Exception as e:
            app.logger.warning(f'⚠️  Twilio init failed: {e} — using mock mode')
            _twilio_client = None
    else:
        app.logger.info('ℹ️  Twilio mock mode — OTP printed to console')


# ── Rate Limiting ─────────────────────────────────────────────

def _check_rate_limit(key: str, max_attempts: int, window_seconds: int) -> bool:
    """Returns True if under limit, False if exceeded."""
    if _redis is None:
        return True  # no Redis → no limiting
    count = _redis.get(key)
    if count and int(count) >= max_attempts:
        return False
    pipe = _redis.pipeline()
    pipe.incr(key)
    pipe.expire(key, window_seconds)
    pipe.execute()
    return True


def check_otp_rate_limit(phone: str) -> bool:
    """Max 3 OTP sends per 10 min per phone."""
    return _check_rate_limit(
        f'otp_send:{phone}',
        current_app.config.get('OTP_RATE_LIMIT_MAX', 3),
        current_app.config.get('OTP_RATE_LIMIT_WINDOW', 600),
    )


def check_verify_rate_limit(phone: str) -> bool:
    """Max 5 verification attempts per 10 min per phone."""
    return _check_rate_limit(
        f'otp_verify:{phone}',
        current_app.config.get('VERIFY_RATE_LIMIT_MAX', 5),
        current_app.config.get('VERIFY_RATE_LIMIT_WINDOW', 600),
    )


# ── OTP via Twilio Verify ────────────────────────────────────

def send_otp(phone: str) -> dict:
    """Send OTP to phone. Uses Twilio Verify or mock mode."""
    if _twilio_client and _verify_sid:
        verification = _twilio_client.verify \
            .v2 \
            .services(_verify_sid) \
            .verifications \
            .create(to=phone, channel='sms')
        return {'status': verification.status}
    else:
        # Mock mode — log to console
        logger.info(f'[MOCK OTP] Phone: {phone} — use code "123456" to verify')
        return {'status': 'pending', 'mock': True}


def verify_otp(phone: str, code: str) -> bool:
    """Verify OTP code. Returns True if valid."""
    if _twilio_client and _verify_sid:
        try:
            check = _twilio_client.verify \
                .v2 \
                .services(_verify_sid) \
                .verification_checks \
                .create(to=phone, code=code)
            return check.status == 'approved'
        except Exception as e:
            logger.warning(f'Twilio verify failed: {e}')
            return False
    else:
        # Mock mode — accept "123456"
        return code == '123456'


# ── JWT ───────────────────────────────────────────────────────

def generate_token(user_id: str) -> str:
    """Create a JWT for the given user."""
    expiry_hours = current_app.config.get('JWT_EXPIRY_HOURS', 24)
    payload = {
        'sub': user_id,
        'iat': datetime.now(timezone.utc),
        'exp': datetime.now(timezone.utc) + timedelta(hours=expiry_hours),
    }
    return jwt.encode(payload, current_app.config['JWT_SECRET'], algorithm='HS256')
