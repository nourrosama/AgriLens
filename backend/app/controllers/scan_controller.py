"""
Scan controller -- image/video upload and synchronous detection flow.
Enforces subscription plan limits and gates the detection response by plan tier.
"""
import os
import tempfile

from flask import Blueprint, current_app, g, request

from app.middleware.auth_middleware import require_auth
from app.models import audit_model, farm_model, forecast_model, notification_model, scan_model
from app.observers import event_publisher
from app.services import (
    detection_proxy_service, disease_report_service,
    insights_service, storage_service, video_service,
)
from app.services.subscription_service import can_scan, build_scan_response
from app.utils.validators import is_valid_object_id
from app.views.responses import error_response, success_response

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
    # ── Subscription scan quota check ────────────────────────────────────────
    allowed, quota_msg = can_scan(g.current_user)
    if not allowed:
        return error_response(quota_msg, 403, extra={'upgrade_required': True, 'required_plan': 'premium'})

    has_image = 'image' in request.files and request.files['image'].filename
    has_video = 'video' in request.files and request.files['video'].filename

    if not has_image and not has_video:
        return error_response('No image or video file provided', 400)

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

    try:
        media_url = (
            storage_service.upload_video(file)
            if media_type == 'video'
            else storage_service.upload_image(file)
        )
        storage_backend = storage_service.get_storage_backend()
    except Exception as exc:
        current_app.logger.exception('Failed to store uploaded scan media: %s', exc)
        return error_response('Unable to store the uploaded file right now. Please try again.', 503)

    scan = scan_model.create_scan(
        user_id=user_id,
        farm_id=farm_id,
        field_id=field_id,
        media_url=media_url,
        image_url=media_url,
        storage_backend=storage_backend,
        scan_type=media_type,
        crop_type=crop_type,
        media_type=media_type,
        device_info=device_info,
    )
    scan_id = str(scan['_id'])
    event_publisher.scan_created(scan_id, media_url)

    if media_type == 'video':
        scan_model.update_status(scan_id, 'processing')

        local_path = storage_service.resolve_local_path(media_url)
        _tmp_video_path = None

        if not (local_path and os.path.exists(local_path)):
            if media_url.startswith('http'):
                # Video is on Cloudinary (or another remote URL). Download it to a
                # temp file so cv2.VideoCapture gets a reliable local file descriptor.
                try:
                    import requests as _req
                    ext = media_url.rsplit('.', 1)[-1].split('?')[0].lower() or 'mp4'
                    with tempfile.NamedTemporaryFile(suffix=f'.{ext}', delete=False) as tmp:
                        resp = _req.get(media_url, timeout=120, stream=True)
                        resp.raise_for_status()
                        for chunk in resp.iter_content(chunk_size=8 * 1024 * 1024):
                            tmp.write(chunk)
                        _tmp_video_path = tmp.name
                    local_path = _tmp_video_path
                except Exception as dl_exc:
                    current_app.logger.warning('Could not download video for analysis: %s', dl_exc)
                    local_path = media_url
            else:
                local_path = media_url

        result = None
        forecast_payload = None
        _video_error = None

        try:
            result = video_service.analyze_video(local_path, crop_type)

            if result is not None:
                scan_model.update_detection_result(scan_id, result)
                event_publisher.scan_completed(scan_id, result)

                location = {}
                if farm_id:
                    farm = farm_model.get_farm_by_id(farm_id)
                    if farm:
                        location = farm.get('location', {})
                        if field_id:
                            for field in farm.get('fields', []):
                                if str(field.get('field_id')) == field_id:
                                    location = field.get('location') or location
                                    break

                weather = insights_service.build_weather(location)
                scans = scan_model.get_scans_by_user(user_id, 1, 50)
                forecast_payload = insights_service.compute_forecast(scans, weather, 7)
                forecast_model.upsert_snapshot(
                    user_id,
                    {'farm_id': farm_id, 'field_id': field_id},
                    forecast_payload,
                )

                if not result.get('is_healthy', True):
                    notification_model.create_notification(
                        user_id,
                        'Disease detected',
                        f"{result.get('disease', 'Unknown disease')} detected with {result.get('severity', 'unknown')} severity.",
                        category='disease',
                        related_scan_id=scan_id,
                        metadata={'scan_id': scan_id},
                    )
                    event_publisher.disease_detected(
                        scan_id,
                        result.get('disease', ''),
                        result.get('severity', ''),
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

        except Exception as exc:
            _video_error = str(exc)
            current_app.logger.exception('Video analysis failed for %s: %s', scan_id, exc)
            scan_model.update_scan(scan_id, {'status': 'failed'})
        finally:
            if _tmp_video_path:
                try:
                    os.unlink(_tmp_video_path)
                except OSError:
                    pass

        audit_model.log_action(
            user_id,
            'scan_created',
            resource_id=scan_id,
            ip_address=request.remote_addr,
            details={**device_info, 'media_type': media_type},
        )

        if result is None:
            return error_response(_video_error or 'Video analysis failed.', 422)

        stored = scan_model.get_scan_by_id(scan_id)
        return success_response(
            {'scan': scan_model.serialize(stored), 'forecast': forecast_payload},
            'Video scan processed successfully',
            201,
        )

    scan_model.update_status(scan_id, 'processing')

    image_reference = media_url
    local_path = storage_service.resolve_local_path(media_url)
    if local_path and os.path.exists(local_path):
        image_reference = local_path

    detection = None
    gradcam_overlay = None   # held in memory only — never written to MongoDB
    forecast_payload = None

    try:
        detection = detection_proxy_service.detect(image_reference, crop_type)

        if detection:
            # Pop the Grad-CAM overlay before persisting to keep the document lean.
            # It will be re-injected into the one-time 201 response below.
            gradcam_overlay = detection.pop('gradcam_overlay', None)
            scan_model.update_detection_result(scan_id, detection)
            event_publisher.scan_completed(scan_id, detection)

            location = {}
            if farm_id:
                farm = farm_model.get_farm_by_id(farm_id)
                if farm:
                    location = farm.get('location', {})
                    if field_id:
                        for field in farm.get('fields', []):
                            if str(field.get('field_id')) == field_id:
                                location = field.get('location') or location
                                break

            weather = insights_service.build_weather(location)
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
    except ValueError as exc:
        # Detection service rejected the image (e.g. not a plant).
        # Mark the scan record as invalid so it does not pollute history,
        # then surface the reason to the caller immediately.
        scan_model.update_scan(scan_id, {'status': 'invalid_image'})
        return error_response(str(exc), 422)
    except Exception as exc:
        current_app.logger.exception('Scan processing failed for %s: %s', scan_id, exc)
        scan_model.update_scan(scan_id, {'status': 'failed'})

    audit_model.log_action(
        user_id,
        'scan_created',
        resource_id=scan_id,
        ip_address=request.remote_addr,
        details={**device_info, 'media_type': media_type},
    )

    stored = scan_model.get_scan_by_id(scan_id)
    serialized_scan = scan_model.serialize(stored)

    # Re-inject the Grad-CAM overlay into the creation response only.
    # It is intentionally absent from subsequent GET /api/scans responses.
    if gradcam_overlay and serialized_scan.get('detection_result'):
        serialized_scan['detection_result']['gradcam_overlay'] = gradcam_overlay

    # ── Generate AI disease report and build plan-gated result ───────────────
    subscription_result = None
    if detection and not detection.get('is_healthy', True):
        try:
            report = disease_report_service.generate_disease_report(
                disease=detection.get('disease', ''),
                crop_type=crop_type or detection.get('crop_type', 'unknown'),
                severity=detection.get('severity', 'medium'),
                confidence=detection.get('confidence', 0.8),
                scientific_name=detection.get('scientific_name', ''),
                lang=g.current_user.get('language', 'en'),
            )
        except Exception as exc:
            current_app.logger.warning('Disease report generation failed: %s', exc)
            report = None
        subscription_result = build_scan_response(detection, report, g.current_user)
    elif detection and detection.get('is_healthy'):
        subscription_result = {
            'disease_name': 'Healthy Plant',
            'confidence_score': round(detection.get('confidence', 0) * 100, 1),
            'is_healthy': True,
            'basic_summary': 'No disease detected. Your plant appears healthy.',
            'basic_treatment': ['Continue routine monitoring and balanced irrigation.'],
            'plan': g.current_user.get('plan', 'free'),
        }

    message = 'Scan processed successfully' if detection else 'Scan uploaded but detection failed'
    return success_response(
        {
            'scan': serialized_scan,
            'forecast': forecast_payload,
            'result': subscription_result,
        },
        message,
        201,
    )


@scan_bp.route('/api/scans', methods=['GET'])
@require_auth
def list_scans():
    """List scans for the current user, optionally filtered by farm, field, or crop."""
    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 20, type=int), 100)
    farm_id = request.args.get('farm_id')
    field_id = request.args.get('field_id')
    crop_type = request.args.get('crop_type', '').strip()

    if farm_id:
        if not is_valid_object_id(farm_id):
            return error_response('Invalid farm_id', 400)
    if field_id:
        if not is_valid_object_id(field_id):
            return error_response('Invalid field_id', 400)

    scans = scan_model.get_scans_filtered(
        str(g.current_user['_id']),
        farm_id=farm_id,
        field_id=field_id,
        crop_type=crop_type,
        page=page,
        per_page=per_page,
    )

    return success_response(
        {
            'scans': [scan_model.serialize(scan) for scan in scans],
            'page': page,
            'per_page': per_page,
        }
    )


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
