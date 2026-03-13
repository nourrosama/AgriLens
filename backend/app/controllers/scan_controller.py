"""
Scan controller — image upload (event-driven flow).
Flow: upload → Firebase Storage → create pending scan → publish scan.created → return.
Detection is handled asynchronously by the detection service via RabbitMQ.
"""
from flask import Blueprint, request, g
from app.middleware.auth_middleware import require_auth
from app.models import scan_model, audit_model
from app.services import storage_service
from app.observers import event_publisher
from app.utils.validators import is_valid_object_id
from app.views.responses import success_response, error_response

scan_bp = Blueprint('scans', __name__)

ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png', 'webp'}


def _allowed_file(filename: str) -> bool:
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


@scan_bp.route('/api/scans', methods=['POST'])
@require_auth
def upload_scan():
    """Upload an image for disease detection (event-driven).
    ---
    tags:
      - Scans
    security:
      - Bearer: []
    consumes:
      - multipart/form-data
    parameters:
      - in: formData
        name: image
        type: file
        required: true
        description: Plant image (jpg, png, webp)
      - in: formData
        name: farm_id
        type: string
        required: false
      - in: formData
        name: field_id
        type: string
        required: false
      - in: formData
        name: device_type
        type: string
        required: false
        example: "mobile"
      - in: formData
        name: app_version
        type: string
        required: false
        example: "1.0.0"
    responses:
      201:
        description: Scan created with status pending
      400:
        description: No image provided
    """
    if 'image' not in request.files:
        return error_response('No image file provided', 400)

    file = request.files['image']
    if not file.filename or not _allowed_file(file.filename):
        return error_response('Invalid file type. Allowed: jpg, jpeg, png, webp', 400)

    user_id = str(g.current_user['_id'])
    farm_id = request.form.get('farm_id')
    field_id = request.form.get('field_id')

    # Validate optional IDs
    if farm_id and not is_valid_object_id(farm_id):
        return error_response('Invalid farm_id', 400)
    if field_id and not is_valid_object_id(field_id):
        return error_response('Invalid field_id', 400)

    # Device metadata
    device_info = {
        'device_type': request.form.get('device_type', 'unknown'),
        'app_version': request.form.get('app_version', ''),
    }

    # 1. Upload to Firebase Storage (or local fallback)
    image_url = storage_service.upload_image(file)

    # 2. Create scan record with status = "pending"
    scan = scan_model.create_scan(
        user_id=user_id,
        farm_id=farm_id,
        field_id=field_id,
        image_url=image_url,
        scan_type='image',
        device_info=device_info,
    )

    scan_id = str(scan['_id'])

    # 3. Publish event → detection service picks it up
    event_publisher.scan_created(scan_id, image_url)

    # Audit log
    audit_model.log_action(
        user_id, 'scan_created',
        resource_id=scan_id,
        ip_address=request.remote_addr,
        details=device_info,
    )

    return success_response({'scan': scan_model.serialize(scan)}, 'Scan uploaded — processing', 201)


@scan_bp.route('/api/scans', methods=['GET'])
@require_auth
def list_scans():
    """List scans for the current user (paginated).
    ---
    tags:
      - Scans
    security:
      - Bearer: []
    parameters:
      - in: query
        name: page
        type: integer
        default: 1
      - in: query
        name: per_page
        type: integer
        default: 20
      - in: query
        name: farm_id
        type: string
        required: false
    responses:
      200:
        description: List of scans
    """
    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 20, type=int), 100)
    farm_id = request.args.get('farm_id')

    if farm_id:
        if not is_valid_object_id(farm_id):
            return error_response('Invalid farm_id', 400)
        scans = scan_model.get_scans_by_farm(farm_id, page, per_page)
    else:
        scans = scan_model.get_scans_by_user(str(g.current_user['_id']), page, per_page)

    return success_response({
        'scans': [scan_model.serialize(s) for s in scans],
        'page': page,
        'per_page': per_page,
    })


@scan_bp.route('/api/scans/<scan_id>', methods=['GET'])
@require_auth
def get_scan(scan_id):
    """Get scan details including detection result.
    ---
    tags:
      - Scans
    security:
      - Bearer: []
    parameters:
      - in: path
        name: scan_id
        type: string
        required: true
    responses:
      200:
        description: Scan details
      404:
        description: Scan not found
    """
    if not is_valid_object_id(scan_id):
        return error_response('Invalid scan ID', 400)

    scan = scan_model.get_scan_by_id(scan_id)
    if not scan:
        return error_response('Scan not found', 404)
    if str(scan['user_id']) != str(g.current_user['_id']):
        return error_response('Forbidden', 403)

    return success_response({'scan': scan_model.serialize(scan)})


# ── Internal endpoint — called by detection service callback ──

@scan_bp.route('/api/scans/<scan_id>/result', methods=['POST'])
def receive_detection_result(scan_id):
    """Internal: detection service pushes result here after processing.
    ---
    tags:
      - Scans (Internal)
    parameters:
      - in: path
        name: scan_id
        type: string
        required: true
      - in: body
        name: body
        schema:
          type: object
          properties:
            disease:
              type: string
            confidence:
              type: number
            severity:
              type: string
            is_healthy:
              type: boolean
            bbox:
              type: array
              items:
                type: integer
            risk_level:
              type: string
            recommendation:
              type: string
            model_version:
              type: string
    responses:
      200:
        description: Result stored
    """
    if not is_valid_object_id(scan_id):
        return error_response('Invalid scan ID', 400)

    scan = scan_model.get_scan_by_id(scan_id)
    if not scan:
        return error_response('Scan not found', 404)

    detection = request.get_json(silent=True) or {}

    scan_model.update_detection_result(scan_id, detection)

    # Publish events based on result
    event_publisher.scan_completed(scan_id, detection)

    if not detection.get('is_healthy', True):
        event_publisher.disease_detected(
            scan_id,
            detection.get('disease', ''),
            detection.get('severity', ''),
            str(scan['user_id']),
        )

    risk = detection.get('risk_level', '')
    if risk in ('high', 'critical'):
        event_publisher.risk_high(scan_id, risk, str(scan['user_id']))

    return success_response(message='Detection result stored')
