"""
Auth service for OTP delivery, verification, and JWT generation.
Falls back to mock mode when Twilio is not enabled.
"""
import logging
import os
from datetime import datetime, timedelta, timezone

import jwt
import redis
from flask import current_app

logger = logging.getLogger(__name__)

_redis = None
_twilio_client = None
_verify_sid = None


class OtpDeliveryError(Exception):
    """Raised when OTP delivery fails and should return a user-facing API error."""

    def __init__(self, message: str, status_code: int = 502):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _should_use_mock_fallback() -> bool:
    """Allow OTP flow to keep working during local development."""
    return (
        current_app.config.get('TWILIO_MOCK_MODE', False)
        or current_app.config.get('TESTING', False)
        or current_app.debug
        or os.getenv('FLASK_ENV') == 'development'
    )


def _is_strict_auth_env(config) -> bool:
    """Return True when startup should reject mock/missing Twilio OTP config."""
    return (
        str(config.get('APP_ENV', '')).lower() in {'staging', 'production'}
        and not config.get('TESTING', False)
    )


def _mock_otp_response(phone: str) -> dict:
    """Return the standard mock OTP response and log the code."""
    logger.info(f'[MOCK OTP] Phone: {phone}. Use code "123456" to verify.')
    return {'status': 'pending', 'mock': True}


def init_auth_service(app):
    """Initialize Redis (rate limiting) and Twilio client."""
    global _redis, _twilio_client, _verify_sid

    try:
        _redis = redis.from_url(app.config.get('REDIS_URL', 'redis://localhost:6379/0'))
        _redis.ping()
        app.logger.info('Redis connected for auth rate limiting')
    except Exception as e:
        app.logger.warning(f'Redis not reachable: {e}. Rate limiting disabled.')
        _redis = None

    sid = app.config.get('TWILIO_ACCOUNT_SID', '')
    token = app.config.get('TWILIO_AUTH_TOKEN', '')
    _verify_sid = app.config.get('TWILIO_VERIFY_SERVICE_SID', '')
    strict_auth = _is_strict_auth_env(app.config)

    if strict_auth and app.config.get('TWILIO_MOCK_MODE', True):
        raise RuntimeError('TWILIO_MOCK_MODE must be false in staging/production.')
    if strict_auth and not (sid and token and _verify_sid):
        raise RuntimeError(
            'Twilio Verify credentials are required in staging/production.'
        )

    if sid and token and _verify_sid and not app.config.get('TWILIO_MOCK_MODE', True):
        try:
            from twilio.rest import Client

            _twilio_client = Client(sid, token)
            app.logger.info('Twilio Verify initialized')
        except Exception as e:
            app.logger.warning(f'Twilio init failed: {e}')
            _twilio_client = None
    else:
        if app.config.get('TWILIO_MOCK_MODE', True):
            app.logger.info('Twilio mock mode enabled. OTP will be logged to the console.')
        else:
            app.logger.warning('Twilio Verify is not configured; OTP delivery is disabled.')


def _check_rate_limit(key: str, max_attempts: int, window_seconds: int) -> bool:
    """Return True if the key is under the limit, False otherwise."""
    if _redis is None:
        return True

    count = _redis.get(key)
    if count and int(count) >= max_attempts:
        return False

    pipe = _redis.pipeline()
    pipe.incr(key)
    pipe.expire(key, window_seconds)
    pipe.execute()
    return True


def check_otp_rate_limit(phone: str) -> bool:
    """Max 3 OTP sends per 10 minutes per phone."""
    return _check_rate_limit(
        f'otp_send:{phone}',
        current_app.config.get('OTP_RATE_LIMIT_MAX', 3),
        current_app.config.get('OTP_RATE_LIMIT_WINDOW', 600),
    )


def check_verify_rate_limit(phone: str) -> bool:
    """Max 5 verification attempts per 10 minutes per phone."""
    return _check_rate_limit(
        f'otp_verify:{phone}',
        current_app.config.get('VERIFY_RATE_LIMIT_MAX', 5),
        current_app.config.get('VERIFY_RATE_LIMIT_WINDOW', 600),
    )


def send_otp(phone: str) -> dict:
    """Send an OTP using Twilio Verify or mock mode."""
    if _twilio_client and _verify_sid:
        try:
            verification = (
                _twilio_client.verify.v2.services(_verify_sid).verifications.create(
                    to=phone,
                    channel='sms',
                )
            )
            return {'status': verification.status}
        except Exception as e:
            logger.warning(f'Twilio send failed: {e}')
            if _should_use_mock_fallback():
                logger.warning('Falling back to mock OTP flow for development.')
                return _mock_otp_response(phone)
            message = str(e).lower()
            if 'trial accounts cannot send messages to unverified numbers' in message:
                raise OtpDeliveryError(
                    'This Twilio trial account can only send OTPs to phone numbers verified in Twilio. '
                    'Verify the destination number in Twilio or enable mock mode for local development.',
                    400,
                ) from e
            raise OtpDeliveryError(
                'Unable to send OTP right now. Please try again later.',
                502,
            ) from e

    if _should_use_mock_fallback():
        return _mock_otp_response(phone)
    raise OtpDeliveryError(
        'OTP delivery is not configured. Please try again later.',
        503,
    )


def verify_otp(phone: str, code: str) -> bool:
    """Verify an OTP code and return True when it is valid."""
    if _twilio_client and _verify_sid:
        try:
            check = (
                _twilio_client.verify.v2.services(_verify_sid).verification_checks.create(
                    to=phone,
                    code=code,
                )
            )
            return check.status == 'approved'
        except Exception as e:
            logger.warning(f'Twilio verify failed: {e}')
            if _should_use_mock_fallback():
                return code == '123456'
            return False

    return _should_use_mock_fallback() and code == '123456'


def generate_token(user_id: str) -> str:
    """Create a JWT for the given user."""
    expiry_hours = current_app.config.get('JWT_EXPIRY_HOURS', 24)
    payload = {
        'sub': user_id,
        'iat': datetime.now(timezone.utc),
        'exp': datetime.now(timezone.utc) + timedelta(hours=expiry_hours),
    }
    return jwt.encode(payload, current_app.config['JWT_SECRET'], algorithm='HS256')
