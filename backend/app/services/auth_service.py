"""
Auth service for OTP delivery, verification, and JWT generation.
Supports two channels:
  - Phone OTP via Twilio Verify (falls back to mock in dev)
  - Email OTP via Gmail SMTP (6-digit code stored in Redis; falls back to mock)
"""
import logging
import os
import random
import smtplib
import ssl
import string
from datetime import datetime, timedelta, timezone
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

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

    if sid and token and _verify_sid and not app.config.get('TWILIO_MOCK_MODE', True):
        try:
            from twilio.rest import Client

            _twilio_client = Client(sid, token)
            app.logger.info('Twilio Verify initialized')
        except Exception as e:
            app.logger.warning(f'Twilio init failed: {e}. Using mock mode.')
            _twilio_client = None
    else:
        app.logger.info('Twilio mock mode enabled. OTP will be logged to the console.')


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

    return _mock_otp_response(phone)


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

    return code == '123456'


def generate_token(user_id: str) -> str:
    """Create a JWT for the given user."""
    expiry_hours = current_app.config.get('JWT_EXPIRY_HOURS', 24)
    payload = {
        'sub': user_id,
        'iat': datetime.now(timezone.utc),
        'exp': datetime.now(timezone.utc) + timedelta(hours=expiry_hours),
    }
    return jwt.encode(payload, current_app.config['JWT_SECRET'], algorithm='HS256')


# ── Email OTP (Resend) ─────────────────────────────────────────────────────────

# In-memory fallback when Redis is unavailable (dev only — not for production).
_email_otp_store: dict[str, str] = {}

_EMAIL_OTP_TTL = 600  # 10 minutes


def _generate_otp() -> str:
    """Return a cryptographically adequate 6-digit numeric OTP."""
    return ''.join(random.choices(string.digits, k=6))


def _store_email_otp(email: str, code: str) -> None:
    """Persist the OTP in Redis (preferred) or the in-memory fallback."""
    key = f'email_otp:{email}'
    if _redis is not None:
        _redis.setex(key, _EMAIL_OTP_TTL, code)
    else:
        _email_otp_store[key] = code


def _get_email_otp(email: str) -> str | None:
    """Retrieve and immediately delete the stored OTP (single-use)."""
    key = f'email_otp:{email}'
    if _redis is not None:
        code = _redis.get(key)
        if code:
            _redis.delete(key)
            return code.decode() if isinstance(code, bytes) else code
        return None
    return _email_otp_store.pop(key, None)


def check_email_otp_rate_limit(email: str) -> bool:
    """Max 3 email OTP sends per 10 minutes."""
    return _check_rate_limit(
        f'email_otp_send:{email}',
        current_app.config.get('OTP_RATE_LIMIT_MAX', 3),
        current_app.config.get('OTP_RATE_LIMIT_WINDOW', 600),
    )


def check_email_verify_rate_limit(email: str) -> bool:
    """Max 5 verification attempts per 10 minutes."""
    return _check_rate_limit(
        f'email_otp_verify:{email}',
        current_app.config.get('VERIFY_RATE_LIMIT_MAX', 5),
        current_app.config.get('VERIFY_RATE_LIMIT_WINDOW', 600),
    )


def send_email_otp(email: str) -> dict:
    """Generate a 6-digit OTP and deliver it via Gmail SMTP (or log it in dev)."""
    code = _generate_otp()
    _store_email_otp(email, code)

    gmail_user = current_app.config.get('GMAIL_USER', '')
    gmail_password = current_app.config.get('GMAIL_APP_PASSWORD', '')

    if not gmail_user or not gmail_password:
        # Mock mode — log the code for local development
        logger.info(f'[MOCK EMAIL OTP] Email: {email}. Use code "{code}" to verify.')
        # Return the code in the response so the Flutter dev UI can display it.
        return {'status': 'pending', 'mock': True, 'dev_code': code}

    html_body = f"""
    <div style="font-family:sans-serif;max-width:480px;margin:auto;padding:32px">
      <h2 style="color:#2E7D32">AgriLens Verification Code</h2>
      <p>Use the code below to log in. It expires in 10 minutes.</p>
      <div style="font-size:40px;font-weight:bold;letter-spacing:12px;
                  color:#2E7D32;background:#E8F5E9;padding:16px 24px;
                  border-radius:8px;display:inline-block;margin:16px 0">
        {code}
      </div>
      <p style="color:#9E9E9E;font-size:13px">
        If you did not request this code, you can safely ignore this email.
      </p>
    </div>
    """

    msg = MIMEMultipart('alternative')
    msg['Subject'] = 'Your AgriLens verification code'
    msg['From'] = f'AgriLens <{gmail_user}>'
    msg['To'] = email
    msg.attach(MIMEText(f'Your AgriLens verification code is: {code}', 'plain'))
    msg.attach(MIMEText(html_body, 'html'))

    try:
        context = ssl.create_default_context()
        with smtplib.SMTP('smtp.gmail.com', 587) as server:
            server.ehlo()
            server.starttls(context=context)
            server.login(gmail_user, gmail_password)
            server.sendmail(gmail_user, email, msg.as_string())
        logger.info(f'[GMAIL] OTP sent to {email}')
        return {'status': 'pending'}
    except smtplib.SMTPAuthenticationError as exc:
        logger.error(f'[GMAIL] Auth failed — check GMAIL_USER and GMAIL_APP_PASSWORD: {exc}')
        raise OtpDeliveryError(
            'Email service configuration error. Please contact support.',
            500,
        ) from exc
    except Exception as exc:
        logger.error(f'[GMAIL] Failed to send OTP to {email}: {exc}')
        raise OtpDeliveryError(
            'Unable to send verification email right now. Please try again.',
            502,
        ) from exc


def verify_email_otp(email: str, code: str) -> bool:
    """Return True when the supplied code matches the stored OTP for this email."""
    stored = _get_email_otp(email)
    if stored is None:
        return False
    return stored == code


# ── Support ticket email ────────────────────────────────────────────────────────

def send_support_email_to_admin(
    ticket_id: str,
    user_name: str,
    user_email: str,
    subject: str,
    message: str,
) -> None:
    """Send a notification email to the admin when a user submits a support ticket."""
    admin_email = current_app.config.get('SUPPORT_EMAIL', '')
    gmail_user = current_app.config.get('GMAIL_USER', '')
    gmail_password = current_app.config.get('GMAIL_APP_PASSWORD', '')

    if not admin_email:
        logger.warning('[SUPPORT] SUPPORT_EMAIL not configured — skipping admin email.')
        return

    if not gmail_user or not gmail_password:
        logger.info(
            '[MOCK SUPPORT EMAIL] Ticket #%s from %s (%s): %s',
            ticket_id, user_name, user_email, subject,
        )
        return

    admin_panel_url = f'http://127.0.0.1:5000/admin/support.html'
    html_body = f"""
    <div style="font-family:sans-serif;max-width:600px;margin:auto;padding:32px">
      <h2 style="color:#2E7D32">New Support Message — AgriLens</h2>
      <table style="width:100%;border-collapse:collapse;margin-bottom:16px">
        <tr><td style="color:#9E9E9E;padding:4px 0;width:100px">From</td>
            <td><strong>{user_name}</strong> ({user_email})</td></tr>
        <tr><td style="color:#9E9E9E;padding:4px 0">Ticket&nbsp;#</td>
            <td><code>{ticket_id}</code></td></tr>
        <tr><td style="color:#9E9E9E;padding:4px 0">Subject</td>
            <td><strong>{subject}</strong></td></tr>
      </table>
      <div style="background:#F5F5F5;border-radius:8px;padding:16px;margin-bottom:24px;
                  white-space:pre-wrap;font-size:15px">
{message}
      </div>
      <a href="{admin_panel_url}"
         style="display:inline-block;background:#2E7D32;color:#fff;text-decoration:none;
                padding:12px 24px;border-radius:8px;font-weight:600">
        Reply in Admin Panel →
      </a>
      <p style="color:#9E9E9E;font-size:12px;margin-top:24px">
        AgriLens Admin · Do not reply directly to this email.
      </p>
    </div>
    """

    msg = MIMEMultipart('alternative')
    msg['Subject'] = f'[AgriLens Support] {subject}'
    msg['From'] = f'AgriLens <{gmail_user}>'
    msg['To'] = admin_email
    msg['Reply-To'] = user_email  # allows quick email reply to user if needed
    msg.attach(MIMEText(f'New support ticket from {user_name}: {message}', 'plain'))
    msg.attach(MIMEText(html_body, 'html'))

    try:
        context = ssl.create_default_context()
        with smtplib.SMTP('smtp.gmail.com', 587) as server:
            server.ehlo()
            server.starttls(context=context)
            server.login(gmail_user, gmail_password)
            server.sendmail(gmail_user, admin_email, msg.as_string())
        logger.info('[GMAIL] Support ticket email sent to admin (%s)', admin_email)
    except Exception as exc:
        logger.warning('[GMAIL] Failed to send support ticket email: %s', exc)


def send_support_confirmation_to_user(
    user_email: str,
    user_name: str,
    subject: str,
    message: str,
) -> None:
    """Send a confirmation email to the user after they submit a support ticket."""
    if not user_email:
        return

    gmail_user = current_app.config.get('GMAIL_USER', '')
    gmail_password = current_app.config.get('GMAIL_APP_PASSWORD', '')

    if not gmail_user or not gmail_password:
        logger.info('[MOCK] Support confirmation email to %s', user_email)
        return

    html_body = f"""
    <div style="font-family:sans-serif;max-width:560px;margin:auto;padding:32px">
      <h2 style="color:#2E7D32">We received your message</h2>
      <p>Hi {user_name or 'there'},</p>
      <p>Thanks for reaching out. We've received your support request and will reply
         to you inside the AgriLens app as soon as possible.</p>

      <div style="background:#F5F5F5;border-radius:8px;padding:16px;margin:20px 0">
        <div style="font-size:12px;color:#9E9E9E;margin-bottom:6px">
          Subject: <strong style="color:#111">{subject}</strong>
        </div>
        <div style="font-size:14px;white-space:pre-wrap;color:#374151">{message}</div>
      </div>

      <p style="color:#6B7280;font-size:14px">
        You'll receive a notification in the app when we reply. You can also open
        <strong>Contact Support</strong> at any time to view the full conversation.
      </p>
      <p style="color:#9E9E9E;font-size:12px;margin-top:24px">
        AgriLens Support · This is a confirmation — no need to reply to this email.
      </p>
    </div>
    """

    msg = MIMEMultipart('alternative')
    msg['Subject'] = f'We received your message — {subject}'
    msg['From'] = f'AgriLens Support <{gmail_user}>'
    msg['To'] = user_email
    msg.attach(MIMEText(f'Hi {user_name}, we received your support request: {subject}', 'plain'))
    msg.attach(MIMEText(html_body, 'html'))

    try:
        context = ssl.create_default_context()
        with smtplib.SMTP('smtp.gmail.com', 587) as server:
            server.ehlo()
            server.starttls(context=context)
            server.login(gmail_user, gmail_password)
            server.sendmail(gmail_user, user_email, msg.as_string())
        logger.info('[GMAIL] Support confirmation sent to user (%s)', user_email)
    except Exception as exc:
        logger.warning('[GMAIL] Failed to send support confirmation to user: %s', exc)
