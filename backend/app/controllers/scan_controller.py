"""
Scan controller -- image/video upload and synchronous detection flow.
"""
import os
from flask import Blueprint, request, g
from app.middleware.auth_middleware import require_auth
from app.models import audit_model, forecast_model, notification_model, scan_model
from app.services import detection_proxy_service, insights_service, storage_service
from app.observers import event_publisher
from app.utils.validators import is_valid_object_id
from app.views.responses import success_response, error_response

scan_bp = Blueprint('scans', __name__)

ALLOWED_IMAGE_EXT = {'jpg', 'jpeg', 'png', 'webp'}
ALLOWED_VIDEO_EXT = {'mp4', 'mov', 'avi', 'mkv'}


def _allowed_file(filename: str, allowed: set = None) -> bool:
    if allowed is None:
        allowed = ALLOWED_IMAGE_EXT | ALLOWED_VIDEO_EXT
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in allowed


@scan_bp.route('/api/scans', methods=['POST'])
@require_auth
def upload_scan():
    """Upload an image or video for disease detection and return the stored result.
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
        required: false
        description: Image file (jpg, jpeg, png, webp)
      - in: formData
        name: video
        type: file
        required: false
        description: Video file (mp4, mov, avi)
      - in: formData
        name: farm_id
        type: string
        required: false
      - in: formData
        name: field_id
        type: string
        required: false
      - in: formData
        name: crop_type
        type: string
        required: false
      - in: formData
        name: device_type
        type: string
        required: false
      - in: formData
        name: app_version
        type: string
        required: false
    responses:
      201:
        description: Scan created and processed
    """
    has_image = 'image' in request.files and request.files['image'].filename
    has_video = 'video' in request.files and request.files['video'].filename

    if not has_image and not has_video:
        return error_response('No image or video file provided', 400)

    # Determine media type
    if has_image:
        file = request.files['image']
        if not _allowed_file(file.filename, ALLOWED_IMAGE_EXT):
            return error_response('Invalid image type. Allowed: jpg, jpeg, png, webp', 400)
        media_type = 'image'
    else:
        file = request.files['video']
        if not _allowed_file(file.filename, ALLOWED_VIDEO_EXT):
            return error_response('Invalid video type. Allowed: mp4, mov, avi, mkv', 400)
        media_type = 'video'

    user_id = str(g.current_user['_id'])
    farm_id = request.form.get('farm_id')
    field_id = request.form.get('field_id')
    crop_type = request.form.get('crop_type', '').strip()

    if farm_id and not is_valid_object_id(farm_id):
        return error_response('Invalid farm_id', 400)
    if field_id and not is_valid_object_id(field_id):
        return error_response('Invalid field_id', 400)

    device_info = {
        'device_type': request.form.get('device_type', 'unknown'),
        'app_version': request.form.get('app_version', ''),
    }

    # Upload media
    if media_type == 'video':
        media_url = storage_service.upload_video(file)
    else:
        media_url = storage_service.upload_image(file)

    scan = scan_model.create_scan(
        user_id=user_id,
        farm_id=farm_id,
        field_id=field_id,
        image_url=media_url,
        scan_type=media_type,
        crop_type=crop_type,
        media_type=media_type,
        device_info=device_info,
    )
    scan_id = str(scan['_id'])
    scan_model.update_status(scan_id, 'processing')

    image_reference = media_url
    local_path = storage_service.resolve_local_path(media_url)
    if local_path and os.path.exists(local_path):
        image_reference = local_path

    detection = detection_proxy_service.detect(image_reference, crop_type)
    forecast_payload = None

    if detection:
        scan_model.update_detection_result(scan_id, detection)
        event_publisher.scan_completed(scan_id, detection)
        weather = insights_service.build_weather()
        scans = scan_model.get_scans_by_user(user_id, 1, 50)
        forecast_payload = insights_service.compute_forecast(scans, weather, 7)
        forecast_model.upsert_snapshot(
            user_id,
            {'farm_id': farm_id, 'field_id': field_id},
            forecast_payload,
        )

        if not detection.get('is_healthy', True):
            notification_model.create_notification(
                user_id,
                'Disease detected',
                f"{detection.get('disease', 'Unknown disease')} detected with {detection.get('severity', 'unknown')} severity.",
                category='disease',
                related_scan_id=scan_id,
                metadata={'scan_id': scan_id},
            )
            event_publisher.disease_detected(
                scan_id,
                detection.get('disease', ''),
                detection.get('severity', ''),
                user_id,
            )

        if forecast_payload and forecast_payload.get('risk_level') in ('high', 'critical'):
            notification_model.create_notification(
                user_id,
                'High risk alert',
                f"Forecast risk is {forecast_payload.get('risk_level')} for the next few days.",
                category='forecast',
                related_scan_id=scan_id,
                metadata={'scan_id': scan_id},
            )
            event_publisher.risk_high(
                scan_id,
                forecast_payload.get('risk_level', 'high'),
                user_id,
            )
    else:
        scan_model.update_scan(scan_id, {'status': 'failed'})

    audit_model.log_action(
        user_id,
        'scan_created',
        resource_id=scan_id,
        ip_address=request.remote_addr,
        details=device_info,
    )

    stored = scan_model.get_scan_by_id(scan_id)
    message = 'Scan processed successfully' if detection else 'Scan uploaded but detection failed'
    return success_response({
        'scan': scan_model.serialize(stored),
        'forecast': forecast_payload,
    }, message, 201)


@scan_bp.route('/api/scans', methods=['GET'])
@require_auth
def list_scans():
    """List scans for the current user (paginated, filterable by crop_type)."""
    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 20, type=int), 100)
    farm_id = request.args.get('farm_id')
    crop_type = request.args.get('crop_type', '').strip()

    if farm_id:
        if not is_valid_object_id(farm_id):
            return error_response('Invalid farm_id', 400)
        scans = scan_model.get_scans_by_farm(farm_id, page, per_page)
    elif crop_type:
        scans = scan_model.get_scans_by_crop(
            str(g.current_user['_id']), crop_type, page, per_page)
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
    """Get scan details including detection result."""
    if not is_valid_object_id(scan_id):
        return error_response('Invalid scan ID', 400)

    scan = scan_model.get_scan_by_id(scan_id)
    if not scan:
        return error_response('Scan not found', 404)
    if str(scan['user_id']) != str(g.current_user['_id']):
        return error_response('Forbidden', 403)

    return success_response({'scan': scan_model.serialize(scan)})


@scan_bp.route('/api/scans/<scan_id>/result', methods=['POST'])
def receive_detection_result(scan_id):
    """Compatibility endpoint for external callbacks if needed later."""
    if not is_valid_object_id(scan_id):
        return error_response('Invalid scan ID', 400)

    scan = scan_model.get_scan_by_id(scan_id)
    if not scan:
        return error_response('Scan not found', 404)

    detection = request.get_json(silent=True) or {}
    scan_model.update_detection_result(scan_id, detection)
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
