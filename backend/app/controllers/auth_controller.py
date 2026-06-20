"""
Auth controller — OTP send/verify, profile CRUD.
Supports two OTP channels:
  - Phone (Twilio Verify / mock)   → /api/auth/send-otp + /api/auth/verify-otp
  - Email (Resend / mock)          → /api/auth/send-email-otp + /api/auth/verify-email-otp
"""
import re

from flask import Blueprint, current_app, request, g
from app.extensions import limiter
from app.services import auth_service
from app.services import storage_service
from app.models import user_model, audit_model
from app.middleware.auth_middleware import require_auth
from app.utils.validators import is_valid_phone, sanitize_phone
from app.views.responses import success_response, error_response

auth_bp = Blueprint('auth', __name__)

_EMAIL_RE = re.compile(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')


@auth_bp.route('/api/auth/send-otp', methods=['POST'])
@limiter.limit('5 per minute')
def send_otp():
    """Send OTP to phone via Twilio Verify.
    ---
    tags:
      - Auth
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - phone
          properties:
            phone:
              type: string
              example: "+201234567890"
    responses:
      200:
        description: OTP sent
      400:
        description: Invalid phone
      429:
        description: Rate limit exceeded
    """
    data = request.get_json(silent=True) or {}
    phone = sanitize_phone(data.get('phone', ''))

    if not is_valid_phone(phone):
        return error_response('Invalid Egyptian phone number. Use format: +20XXXXXXXXXX', 400)

    # Rate limit: max 3 per 10 min
    if not auth_service.check_otp_rate_limit(phone):
        return error_response('Too many OTP requests. Try again in 10 minutes.', 429)

    result = auth_service.send_otp(phone)

    # Audit log (user may not exist yet)
    user = user_model.find_by_phone(phone)
    if user:
        audit_model.log_action(
            str(user['_id']), 'otp_sent',
            ip_address=request.remote_addr,
        )

    return success_response({'verification_status': result.get('status', 'pending')},
                            'OTP sent successfully')


@auth_bp.route('/api/auth/register', methods=['POST'])
def register():
    """Start new-user registration: validate profile data, confirm phone is free, send OTP.
    ---
    tags:
      - Auth
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - name
            - country
            - phone
          properties:
            name:
              type: string
              example: "Ahmed Ali"
            country:
              type: string
              example: "egypt"
            phone:
              type: string
              example: "+201234567890"
            email:
              type: string
              example: "ahmed@example.com"
    responses:
      200:
        description: OTP sent — proceed to verify
      400:
        description: Validation error
      409:
        description: Phone already registered
      429:
        description: Rate limit exceeded
    """
    data = request.get_json(silent=True) or {}
    phone = sanitize_phone(data.get('phone', ''))
    name = str(data.get('name', '')).strip()
    country = str(data.get('country', '')).strip()
    email = str(data.get('email', '')).strip()

    if not name:
        return error_response('Full name is required', 400)
    if not country:
        return error_response('Country is required', 400)
    if not is_valid_phone(phone):
        return error_response('Invalid Egyptian phone number. Use format: +20XXXXXXXXXX', 400)

    # Reject if phone already has an account
    if user_model.find_by_phone(phone):
        return error_response(
            'An account with this phone number already exists. Please log in instead.', 409
        )

    if not auth_service.check_otp_rate_limit(phone):
        return error_response('Too many OTP requests. Try again in 10 minutes.', 429)

    result = auth_service.send_otp(phone)
    return success_response(
        {'verification_status': result.get('status', 'pending')},
        'OTP sent. Enter the code to complete your registration.',
    )


@auth_bp.route('/api/auth/verify-otp', methods=['POST'])
@limiter.limit('10 per minute')
def verify_otp():
    """Verify OTP — handles both login and new-user signup.

    Signup flow: include ``name`` and ``country`` in the body.
    Login flow: omit ``name``/``country`` — the account must already exist.
    ---
    tags:
      - Auth
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - phone
            - code
          properties:
            phone:
              type: string
              example: "+201234567890"
            code:
              type: string
              example: "123456"
            name:
              type: string
              example: "Ahmed Ali"
            country:
              type: string
              example: "egypt"
            email:
              type: string
    responses:
      200:
        description: JWT token + user object + is_new_user flag
      400:
        description: Invalid input
      401:
        description: Invalid OTP
      404:
        description: No account found (login flow, phone not registered)
      409:
        description: Phone already registered (signup flow, race condition)
      429:
        description: Rate limit exceeded
    """
    from datetime import datetime, timezone as tz

    data = request.get_json(silent=True) or {}
    phone = sanitize_phone(data.get('phone', ''))
    code = data.get('code', '')
    signup_name = str(data.get('name', '')).strip()
    signup_country = str(data.get('country', '')).strip()
    signup_email = str(data.get('email', '')).strip()
    signup_language = data.get('language') if data.get('language') in ('ar', 'en') else 'en'
    # GDPR: client sends ISO-8601 timestamp of when user checked the consent box.
    raw_consent = data.get('consent_given_at')
    consent_given_at = None
    if raw_consent:
        try:
            consent_given_at = datetime.fromisoformat(str(raw_consent).replace('Z', '+00:00'))
        except ValueError:
            consent_given_at = datetime.now(tz.utc)

    if not is_valid_phone(phone):
        return error_response('Invalid phone number', 400)
    if not code:
        return error_response('OTP code is required', 400)

    # Rate limit: max 5 verify attempts per 10 min
    if not auth_service.check_verify_rate_limit(phone):
        return error_response('Too many verification attempts. Try again later.', 429)

    if not auth_service.verify_otp(phone, code):
        return error_response('Invalid or expired OTP', 401)

    is_new_user = False
    is_signup = bool(signup_name and signup_country)

    if is_signup:
        # Signup flow: create a brand-new account
        if user_model.find_by_phone(phone):
            return error_response(
                'An account with this phone number already exists. Please log in instead.', 409
            )
        user = user_model.create_user(
            phone=phone,
            name=signup_name,
            country=signup_country,
            email=signup_email,
            language=signup_language,
            consent_given_at=consent_given_at,
        )
        is_new_user = True
    else:
        # Login flow: the account must already exist
        user = user_model.find_by_phone(phone)
        if user is None:
            return error_response(
                'No account found for this number. Please register first.', 404
            )

    token = auth_service.generate_token(str(user['_id']))

    audit_model.log_action(
        str(user['_id']),
        'register_success' if is_new_user else 'login_success',
        ip_address=request.remote_addr,
    )

    return success_response({
        'token': token,
        'user': user_model.serialize(user),
        'is_new_user': is_new_user,
    }, 'Registration successful' if is_new_user else 'Login successful')


@auth_bp.route('/api/auth/send-email-otp', methods=['POST'])
@limiter.limit('5 per minute')
def send_email_otp():
    """Send a 6-digit OTP to the user's email address via Resend.
    ---
    tags:
      - Auth
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required: [email]
          properties:
            email:
              type: string
              example: "user@example.com"
    responses:
      200:
        description: OTP sent
      400:
        description: Invalid email
      429:
        description: Rate limit exceeded
    """
    data = request.get_json(silent=True) or {}
    email = str(data.get('email', '')).strip().lower()

    if not email or not _EMAIL_RE.match(email):
        return error_response('Invalid email address', 400)

    # When the caller declares signup intent (name present), reject if email taken.
    is_signup_intent = bool(str(data.get('name', '')).strip())
    if is_signup_intent and user_model.find_by_email(email):
        return error_response(
            'This email is already registered. Please log in instead.', 409
        )

    if not auth_service.check_email_otp_rate_limit(email):
        return error_response('Too many OTP requests. Try again in 10 minutes.', 429)

    try:
        result = auth_service.send_email_otp(email)
    except auth_service.OtpDeliveryError as exc:
        return error_response(exc.message, exc.status_code)

    # Audit (user may not exist yet)
    user = user_model.find_by_email(email)
    if user:
        audit_model.log_action(str(user['_id']), 'email_otp_sent',
                               ip_address=request.remote_addr)

    payload: dict = {'verification_status': result.get('status', 'pending')}
    # In mock mode (no Gmail configured) surface the code so the Flutter dev
    # UI can display it — developers no longer have to tail server logs.
    if result.get('mock') and result.get('dev_code'):
        payload['dev_code'] = result['dev_code']

    return success_response(payload, 'Verification code sent to your email')


@auth_bp.route('/api/auth/verify-email-otp', methods=['POST'])
@limiter.limit('10 per minute')
def verify_email_otp():
    """Verify an email OTP — handles login and new-user signup via email.

    Signup flow: include ``name`` and ``country`` in the body.
    Login flow: omit them — the account must already exist with this email.
    ---
    tags:
      - Auth
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required: [email, code]
          properties:
            email:
              type: string
            code:
              type: string
              example: "123456"
            name:
              type: string
            country:
              type: string
    responses:
      200:
        description: JWT token + user object
      400:
        description: Invalid input
      401:
        description: Invalid OTP
      404:
        description: No account found (login flow)
      409:
        description: Email already registered (signup flow)
      429:
        description: Rate limit exceeded
    """
    from datetime import datetime, timezone as tz

    data = request.get_json(silent=True) or {}
    email = str(data.get('email', '')).strip().lower()
    code = str(data.get('code', '')).strip()
    signup_name = str(data.get('name', '')).strip()
    signup_country = str(data.get('country', '')).strip()
    signup_language = data.get('language') if data.get('language') in ('ar', 'en') else 'en'
    raw_consent = data.get('consent_given_at')
    consent_given_at = None
    if raw_consent:
        try:
            consent_given_at = datetime.fromisoformat(str(raw_consent).replace('Z', '+00:00'))
        except ValueError:
            consent_given_at = datetime.now(tz.utc)

    if not email or not _EMAIL_RE.match(email):
        return error_response('Invalid email address', 400)
    if not code:
        return error_response('Verification code is required', 400)

    if not auth_service.check_email_verify_rate_limit(email):
        return error_response('Too many verification attempts. Try again later.', 429)

    if not auth_service.verify_email_otp(email, code):
        return error_response('Invalid or expired verification code', 401)

    is_new_user = False
    is_signup = bool(signup_name and signup_country)

    if is_signup:
        if user_model.find_by_email(email):
            return error_response(
                'An account with this email already exists. Please log in instead.', 409
            )
        user = user_model.create_user(
            phone='',
            name=signup_name,
            country=signup_country,
            email=email,
            language=signup_language,
            consent_given_at=consent_given_at,
        )
        is_new_user = True
    else:
        user = user_model.find_by_email(email)
        if user is None:
            return error_response(
                'No account found for this email. Please register first.', 404
            )

    token = auth_service.generate_token(str(user['_id']))

    audit_model.log_action(
        str(user['_id']),
        'register_success' if is_new_user else 'login_success',
        ip_address=request.remote_addr,
    )

    return success_response({
        'token': token,
        'user': user_model.serialize(user),
        'is_new_user': is_new_user,
    }, 'Registration successful' if is_new_user else 'Login successful')


@auth_bp.route('/api/auth/link-phone', methods=['POST'])
@require_auth
def link_phone():
    """Send OTP to a new phone number so the user can link it to their account.
    Rejects the request if the phone is already used by another account.
    ---
    tags: [Auth]
    security: [{Bearer: []}]
    """
    data = request.get_json(silent=True) or {}
    phone = sanitize_phone(data.get('phone', ''))

    if not is_valid_phone(phone):
        return error_response('Invalid Egyptian phone number. Use format: +20XXXXXXXXXX', 400)

    existing = user_model.find_by_phone(phone)
    if existing and str(existing['_id']) != str(g.current_user['_id']):
        return error_response('This phone number is already linked to another account.', 409)

    if not auth_service.check_otp_rate_limit(phone):
        return error_response('Too many OTP requests. Try again in 10 minutes.', 429)

    result = auth_service.send_otp(phone)
    return success_response({'verification_status': result.get('status', 'pending')},
                            'OTP sent. Enter the code to link this number.')


@auth_bp.route('/api/auth/verify-link-phone', methods=['POST'])
@require_auth
def verify_link_phone():
    """Verify OTP and attach the phone number to the current user's account.
    ---
    tags: [Auth]
    security: [{Bearer: []}]
    """
    data = request.get_json(silent=True) or {}
    phone = sanitize_phone(data.get('phone', ''))
    code = str(data.get('code', '')).strip()

    if not is_valid_phone(phone):
        return error_response('Invalid phone number', 400)
    if not code:
        return error_response('OTP code is required', 400)

    if not auth_service.check_verify_rate_limit(phone):
        return error_response('Too many verification attempts. Try again later.', 429)

    if not auth_service.verify_otp(phone, code):
        return error_response('Invalid or expired OTP', 401)

    existing = user_model.find_by_phone(phone)
    if existing and str(existing['_id']) != str(g.current_user['_id']):
        return error_response('This phone number is already linked to another account.', 409)

    user_model.update_user(str(g.current_user['_id']), {'phone': phone})
    user = user_model.find_by_id(str(g.current_user['_id']))
    return success_response({'user': user_model.serialize(user)}, 'Phone number linked successfully')


@auth_bp.route('/api/auth/link-email', methods=['POST'])
@require_auth
def link_email():
    """Send OTP to a new email so the user can link it to their account.
    ---
    tags: [Auth]
    security: [{Bearer: []}]
    """
    data = request.get_json(silent=True) or {}
    email = str(data.get('email', '')).strip().lower()

    if not email or not _EMAIL_RE.match(email):
        return error_response('Invalid email address', 400)

    existing = user_model.find_by_email(email)
    if existing and str(existing['_id']) != str(g.current_user['_id']):
        return error_response('This email is already linked to another account.', 409)

    if not auth_service.check_email_otp_rate_limit(email):
        return error_response('Too many OTP requests. Try again in 10 minutes.', 429)

    try:
        result = auth_service.send_email_otp(email)
    except auth_service.OtpDeliveryError as exc:
        return error_response(exc.message, exc.status_code)

    return success_response({'verification_status': result.get('status', 'pending')},
                            'Verification code sent to your email')


@auth_bp.route('/api/auth/verify-link-email', methods=['POST'])
@require_auth
def verify_link_email():
    """Verify email OTP and attach the email to the current user's account.
    ---
    tags: [Auth]
    security: [{Bearer: []}]
    """
    data = request.get_json(silent=True) or {}
    email = str(data.get('email', '')).strip().lower()
    code = str(data.get('code', '')).strip()

    if not email or not _EMAIL_RE.match(email):
        return error_response('Invalid email address', 400)
    if not code:
        return error_response('Verification code is required', 400)

    if not auth_service.check_email_verify_rate_limit(email):
        return error_response('Too many verification attempts. Try again later.', 429)

    if not auth_service.verify_email_otp(email, code):
        return error_response('Invalid or expired verification code', 401)

    existing = user_model.find_by_email(email)
    if existing and str(existing['_id']) != str(g.current_user['_id']):
        return error_response('This email is already linked to another account.', 409)

    user_model.update_user(str(g.current_user['_id']), {'email': email})
    user = user_model.find_by_id(str(g.current_user['_id']))
    return success_response({'user': user_model.serialize(user)}, 'Email linked successfully')


@auth_bp.route('/api/auth/me', methods=['GET'])
@require_auth
def get_profile():
    """Get current user profile.
    ---
    tags:
      - Auth
    security:
      - Bearer: []
    responses:
      200:
        description: User profile
      401:
        description: Unauthorized
    """
    return success_response({'user': user_model.serialize(g.current_user)})


@auth_bp.route('/api/auth/me', methods=['PUT'])
@require_auth
def update_profile():
    """Update current user profile.
    ---
    tags:
      - Auth
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          type: object
          properties:
            name:
              type: string
            language:
              type: string
              enum: [ar, en]
    responses:
      200:
        description: Updated profile
      401:
        description: Unauthorized
    """
    if request.content_type and request.content_type.startswith('multipart/form-data'):
        data = request.form.to_dict()
    else:
        data = request.get_json(silent=True) or {}

    allowed = {}
    if 'name' in data:
        allowed['name'] = str(data['name']).strip()
    if 'email' in data:
        allowed['email'] = str(data['email']).strip()
    if 'country' in data:
        allowed['country'] = str(data['country']).strip()
    if 'photo_url' in data:
        allowed['photo_url'] = str(data['photo_url']).strip()
    if 'profile_completed' in data:
        value = data['profile_completed']
        allowed['profile_completed'] = value is True or str(value).lower() in ('1', 'true', 'yes')
    if 'language' in data and data['language'] in ('ar', 'en'):
        allowed['language'] = data['language']

    photo = request.files.get('photo')
    if photo and photo.filename:
        try:
            allowed['photo_url'] = storage_service.upload_profile_image(photo)
        except Exception as exc:
            current_app.logger.exception('Failed to store profile photo: %s', exc)
            return error_response('Unable to store the profile photo right now. Please try again.', 503)

    if allowed:
        user_model.update_user(str(g.current_user['_id']), allowed)

    user = user_model.find_by_id(str(g.current_user['_id']))
    return success_response({'user': user_model.serialize(user)}, 'Profile updated')


@auth_bp.route('/api/auth/account', methods=['DELETE'])
@require_auth
def delete_account():
    """Permanently delete the authenticated user's account and all associated data.
    ---
    tags:
      - Auth
    security:
      - Bearer: []
    responses:
      200:
        description: Account and all data deleted
      401:
        description: Unauthorized
    """
    from bson import ObjectId
    from app.models.db import (
        scans_col, farms_col, notifications_col,
        chat_sessions_col, chat_messages_col,
        forum_posts_col, forum_comments_col,
        forum_questions_col, forum_answers_col,
        users_col,
    )

    user_id = str(g.current_user['_id'])
    uid_obj = ObjectId(user_id)

    try:
        scans_col().delete_many({'user_id': uid_obj})
        farms_col().delete_many({'user_id': uid_obj})
        notifications_col().delete_many({'user_id': uid_obj})
        sessions = list(chat_sessions_col().find({'user_id': user_id}, {'_id': 1}))
        session_ids = [s['_id'] for s in sessions]
        if session_ids:
            chat_messages_col().delete_many({'session_id': {'$in': [str(sid) for sid in session_ids]}})
        chat_sessions_col().delete_many({'user_id': user_id})
        forum_posts_col().delete_many({'author_id': uid_obj})
        forum_comments_col().delete_many({'author_id': uid_obj})
        forum_questions_col().delete_many({'author_id': uid_obj})
        forum_answers_col().delete_many({'author_id': uid_obj})
        users_col().delete_one({'_id': uid_obj})

        audit_model.log_action(
            user_id,
            'account_deleted',
            ip_address=request.remote_addr,
        )
        current_app.logger.info('account_deleted', extra={'event': 'account_deleted', 'user_id': user_id})
    except Exception as exc:
        current_app.logger.exception('Account deletion failed for user %s: %s', user_id, exc)
        return error_response('Account deletion failed. Please try again or contact support.', 500)

    return success_response(message='Your account and all associated data have been permanently deleted.')


@auth_bp.route('/api/auth/export-data', methods=['GET'])
@require_auth
def export_data():
    """GDPR data portability — export all data belonging to the current user.
    ---
    tags:
      - Auth
    security:
      - Bearer: []
    responses:
      200:
        description: JSON bundle containing profile, farms, and scans
      401:
        description: Unauthorized
    """
    from app.models.db import scans_col, farms_col
    from bson import ObjectId

    user_id = str(g.current_user['_id'])
    uid_obj = ObjectId(user_id)

    def _serialize_doc(doc: dict) -> dict:
        """Convert ObjectId fields to strings for JSON output."""
        out = {}
        for k, v in doc.items():
            if isinstance(v, ObjectId):
                out[k] = str(v)
            elif isinstance(v, list):
                out[k] = [str(i) if isinstance(i, ObjectId) else i for i in v]
            else:
                out[k] = v.isoformat() if hasattr(v, 'isoformat') else v
        return out

    profile = user_model.serialize(g.current_user)
    farms = [_serialize_doc(f) for f in farms_col().find({'user_id': uid_obj})]
    scans = [_serialize_doc(s) for s in scans_col().find({'user_id': uid_obj}, {'gradcam_overlay': 0})]

    audit_model.log_action(user_id, 'data_export_requested', ip_address=request.remote_addr)

    return success_response({
        'profile': profile,
        'farms': farms,
        'scans': scans,
    }, 'Data export complete')
