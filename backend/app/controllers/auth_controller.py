"""
Auth controller — OTP send/verify, profile CRUD.
Uses Twilio Verify for OTP (no manual Redis storage).
"""
from flask import Blueprint, current_app, request, g
from app.services import auth_service
from app.services import storage_service
from app.models import user_model, audit_model
from app.middleware.auth_middleware import require_auth
from app.utils.validators import is_valid_phone, sanitize_phone
from app.views.responses import success_response, error_response

auth_bp = Blueprint('auth', __name__)


@auth_bp.route('/api/auth/send-otp', methods=['POST'])
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
    data = request.get_json(silent=True) or {}
    phone = sanitize_phone(data.get('phone', ''))
    code = data.get('code', '')
    signup_name = str(data.get('name', '')).strip()
    signup_country = str(data.get('country', '')).strip()
    signup_email = str(data.get('email', '')).strip()

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
