"""
Auth controller — OTP send/verify, profile CRUD.
Uses Twilio Verify for OTP (no manual Redis storage).
"""
from flask import Blueprint, request, g
from app.services import auth_service
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


@auth_bp.route('/api/auth/verify-otp', methods=['POST'])
def verify_otp():
    """Verify OTP and return JWT token.
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
    responses:
      200:
        description: JWT token + user object
      400:
        description: Invalid input
      401:
        description: Invalid OTP
      429:
        description: Rate limit exceeded
    """
    data = request.get_json(silent=True) or {}
    phone = sanitize_phone(data.get('phone', ''))
    code = data.get('code', '')

    if not is_valid_phone(phone):
        return error_response('Invalid phone number', 400)
    if not code:
        return error_response('OTP code is required', 400)

    # Rate limit: max 5 verify attempts per 10 min
    if not auth_service.check_verify_rate_limit(phone):
        return error_response('Too many verification attempts. Try again later.', 429)

    if not auth_service.verify_otp(phone, code):
        return error_response('Invalid or expired OTP', 401)

    # Find or create user
    user = user_model.find_by_phone(phone)
    if user is None:
        user = user_model.create_user(phone)

    token = auth_service.generate_token(str(user['_id']))

    # Audit log
    audit_model.log_action(
        str(user['_id']), 'login_success',
        ip_address=request.remote_addr,
    )

    return success_response({
        'token': token,
        'user': user_model.serialize(user),
    }, 'Login successful')


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
    data = request.get_json(silent=True) or {}
    allowed = {}
    if 'name' in data:
        allowed['name'] = data['name']
    if 'language' in data and data['language'] in ('ar', 'en'):
        allowed['language'] = data['language']

    if allowed:
        user_model.update_user(str(g.current_user['_id']), allowed)

    user = user_model.find_by_id(str(g.current_user['_id']))
    return success_response({'user': user_model.serialize(user)}, 'Profile updated')
