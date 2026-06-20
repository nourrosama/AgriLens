"""
Scan controller -- image/video upload and synchronous detection flow.
Enforces subscription plan limits and gates the detection response by plan tier.
"""
import os
import tempfile
import threading

from flask import Blueprint, current_app, g, jsonify, request

from app.extensions import limiter
from app.middleware.auth_middleware import require_auth
from app.models import audit_model, farm_model, notification_model, scan_model
from app.observers import event_publisher
from app.services import (
    detection_proxy_service, disease_report_service,
    storage_service, video_service,
)
from app.services.subscription_service import can_scan, build_scan_response
from app.utils.validators import is_valid_object_id
from app.views.responses import error_response, success_response

scan_bp = Blueprint('scans', __name__)

ALLOWED_IMAGE_EXT = {'jpg', 'jpeg', 'png', 'webp'}
ALLOWED_VIDEO_EXT = {'mp4', 'mov', 'avi', 'mkv'}


def _store_validation_failure(scan_id: str, validation: dict) -> None:
    scan_model.update_scan(
        scan_id,
        {
            'status': 'validation_failed',
            'detection_result': validation,
        },
    )


def _validation_failure_response(scan_id: str, validation: dict):
    stored = scan_model.get_scan_by_id(scan_id)
    return (
        jsonify(
            {
                'status': 'error',
                'message': validation.get('message', 'Scan validation failed'),
                'error_code': validation.get('error_code'),
                'data': {
                    'scan': scan_model.serialize(stored),
                    'validation': validation,
                    'suggested_crop': validation.get('detected_crop'),
                },
            }
        ),
        422,
    )


def _allowed_file(filename: str, allowed: set = None) -> bool:
    if allowed is None:
        allowed = ALLOWED_IMAGE_EXT | ALLOWED_VIDEO_EXT
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in allowed


_IMAGE_SIGNATURES = [
    (b'\xff\xd8\xff', {'jpg', 'jpeg'}),
    (b'\x89PNG', {'png'}),
]

_WEBP_RIFF = b'RIFF'
_WEBP_MAGIC = b'WEBP'
_MP4_FTYP = b'ftyp'
_AVI_MAGIC = b'AVI '
_MKV_MAGIC = b'\x1aE\xdf\xa3'


def _verify_magic_bytes(file_obj, expected_types: set) -> bool:
    """Read the first 12 bytes and confirm the file signature matches the claimed type."""
    header = file_obj.read(12)
    file_obj.seek(0)

    for sig, types in _IMAGE_SIGNATURES:
        if header[:len(sig)] == sig and expected_types & types:
            return True

    if header[:4] == _WEBP_RIFF and header[8:12] == _WEBP_MAGIC and 'webp' in expected_types:
        return True

    # MP4 / MOV: 'ftyp' box starts at byte 4
    if header[4:8] == _MP4_FTYP and expected_types & {'mp4', 'mov'}:
        return True

    if header[:4] == _WEBP_RIFF and header[8:12] == _AVI_MAGIC and 'avi' in expected_types:
        return True

    if header[:4] == _MKV_MAGIC and 'mkv' in expected_types:
        return True

    return False


def _update_field_health_from_detection(farm_id: str, field_id: str, detection: dict) -> None:
    if not farm_id or not field_id or not detection:
        return

    is_healthy = detection.get('is_healthy', True)
    severity = str(detection.get('severity', 'none')).lower()
    risk_level = str(detection.get('risk_level', 'low')).lower()

    if is_healthy:
        health_score = 100
        risk_level = 'low'
    elif severity in ('critical', 'high') or risk_level == 'high':
        health_score = 45
        risk_level = 'high'
    elif severity == 'medium' or risk_level == 'medium':
        health_score = 65
        risk_level = 'medium'
    else:
        health_score = 78
        risk_level = 'low'

    try:
        farm_model.update_field(
            farm_id,
            field_id,
            {
                'health_score': health_score,
                'risk_level': risk_level,
            },
        )
    except Exception as exc:
        current_app.logger.warning(
            'Failed to update field health for farm=%s field=%s: %s',
            farm_id,
            field_id,
            exc,
        )


@scan_bp.route('/api/scans', methods=['POST'])
@limiter.limit(lambda: current_app.config.get('SCAN_UPLOAD_RATE_LIMIT', '10 per minute'))
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
        if not _verify_magic_bytes(file.stream, ALLOWED_IMAGE_EXT):
            return error_response('File content does not match a supported image format', 400)
        media_type = 'image'
    else:
        file = request.files['video']
        if not _allowed_file(file.filename, ALLOWED_VIDEO_EXT):
            return error_response('Invalid video type. Allowed: mp4, mov, avi, mkv', 400)
        if not _verify_magic_bytes(file.stream, ALLOWED_VIDEO_EXT):
            return error_response('File content does not match a supported video format', 400)
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

    # Video: read into memory immediately (werkzeug already has it buffered) so
    # we can return 202 before touching the network. The background thread writes
    # to /tmp, runs detection, then uploads to Cloudinary with no timeout pressure.
    # Image: small enough to upload to Cloudinary synchronously.
    _video_bytes: bytes | None = None
    _vid_ext: str = 'mp4'
    if media_type == 'video':
        _vid_ext = file.filename.rsplit('.', 1)[-1].lower() if '.' in file.filename else 'mp4'
        _video_bytes = file.stream.read()
        media_url = ''
        storage_backend = 'pending'
    else:
        try:
            media_url = storage_service.upload_image(file)
            storage_backend = storage_service.get_storage_backend()
        except Exception as exc:
            current_app.logger.exception('Failed to store uploaded image: %s', exc)
            detail = str(exc) if current_app.debug else 'Please try again.'
            return error_response(f'Unable to store the uploaded file: {detail}', 503)

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
    current_app.logger.info(
        'scan_received',
        extra={
            'event': 'scan_received',
            'scan_id': scan_id,
            'user_id': user_id,
            'crop_type': crop_type,
            'media_type': media_type,
        },
    )
    event_publisher.scan_created(scan_id, media_url)

    if media_type == 'video':
        scan_model.update_status(scan_id, 'processing')

        # Capture request-context values before the thread is spawned — they are
        # unavailable once the HTTP response is returned.
        _app = current_app._get_current_object()
        _remote_addr = request.remote_addr

        def _process_video():
            _tmp_path = None
            result = None
            with _app.app_context():
                # Write in-memory bytes to an OS temp file in /tmp (not uploads/).
                # cv2.VideoCapture requires a file path — BytesIO is not accepted.
                try:
                    with tempfile.NamedTemporaryFile(
                        suffix=f'.{_vid_ext}', delete=False
                    ) as tmp:
                        tmp.write(_video_bytes or b'')
                        _tmp_path = tmp.name
                except Exception as exc:
                    _app.logger.exception(
                        'Failed to write video temp file for %s: %s', scan_id, exc
                    )
                    scan_model.update_scan(scan_id, {'status': 'failed'})
                    return

                try:
                    result = video_service.analyze_video(_tmp_path, crop_type, scan_id=scan_id)

                    if result is not None:
                        scan_model.update_detection_result(scan_id, result)
                        _update_field_health_from_detection(farm_id, field_id, result)
                        _app.logger.info(
                            'scan_completed',
                            extra={
                                'event': 'scan_completed',
                                'scan_id': scan_id,
                                'user_id': user_id,
                                'crop_type': crop_type,
                                'media_type': 'video',
                            },
                        )
                        event_publisher.scan_completed(scan_id, result, user_id, media_type='video')

                        if not result.get('is_healthy', True):
                            notification_model.create_notification(
                                user_id,
                                'Disease detected',
                                f"{result.get('disease', 'Unknown disease')} detected with {result.get('severity', 'unknown')} severity.",
                                category='disease',
                                related_scan_id=scan_id,
                                metadata={'scan_id': scan_id},
                                title_en='Disease detected',
                                message_en=f"{result.get('disease', 'Unknown disease')} detected with {result.get('severity', 'unknown')} severity.",
                                title_ar='تم اكتشاف مرض',
                                message_ar=f"تم اكتشاف {result.get('disease', 'مرض غير معروف')} بدرجة خطورة {result.get('severity', 'غير معروفة')}.",
                            )
                            event_publisher.disease_detected(
                                scan_id,
                                result.get('disease', ''),
                                result.get('severity', ''),
                                user_id,
                            )

                    else:
                        scan_model.update_scan(scan_id, {'status': 'failed'})

                except detection_proxy_service.DetectionValidationError as exc:
                    _store_validation_failure(scan_id, exc.payload)
                except Exception as exc:
                    _app.logger.exception('Video analysis failed for %s: %s', scan_id, exc)
                    scan_model.update_scan(scan_id, {'status': 'failed'})
                finally:
                    # Upload to Cloudinary after detection — user is already notified,
                    # so this is best-effort with no timeout. Cleans up temp file either way.
                    if _tmp_path:
                        try:
                            cloud_url = storage_service.upload_video_from_path(_tmp_path)
                            scan_model.update_scan(scan_id, {
                                'media_url': cloud_url,
                                'image_url': cloud_url,
                                'storage_backend': 'cloudinary',
                            })
                        except Exception as cloud_exc:
                            _app.logger.warning(
                                'Cloudinary upload failed for scan %s (result already saved): %s',
                                scan_id, cloud_exc,
                            )
                        try:
                            os.unlink(_tmp_path)
                        except OSError:
                            pass

                audit_model.log_action(
                    user_id,
                    'scan_created',
                    resource_id=scan_id,
                    ip_address=_remote_addr,
                    details={**device_info, 'media_type': media_type},
                )

        threading.Thread(target=_process_video, daemon=True).start()

        stored = scan_model.get_scan_by_id(scan_id)
        return success_response(
            {'scan': scan_model.serialize(stored)},
            'Video uploaded. You will be notified when analysis is complete.',
            202,
        )

    scan_model.update_status(scan_id, 'processing')

    image_reference = media_url
    local_path = storage_service.resolve_local_path(media_url)
    if local_path and os.path.exists(local_path):
        image_reference = local_path

    detection = None
    gradcam_overlay = None   # held in memory only — never written to MongoDB
    validation_payload = None

    try:
        detection = detection_proxy_service.detect(image_reference, crop_type)

        if detection:
            # Pop the Grad-CAM overlay before persisting to keep the document lean.
            # It will be re-injected into the one-time 201 response below.
            gradcam_overlay = detection.pop('gradcam_overlay', None)
            scan_model.update_detection_result(scan_id, detection)
            _update_field_health_from_detection(farm_id, field_id, detection)
            current_app.logger.info(
                'scan_completed',
                extra={
                    'event': 'scan_completed',
                    'scan_id': scan_id,
                    'user_id': user_id,
                    'crop_type': crop_type,
                    'media_type': 'image',
                },
            )
            event_publisher.scan_completed(scan_id, detection, user_id, media_type='image')

            if not detection.get('is_healthy', True):
                notification_model.create_notification(
                    user_id,
                    'Disease detected',
                    f"{detection.get('disease', 'Unknown disease')} detected with {detection.get('severity', 'unknown')} severity.",
                    category='disease',
                    related_scan_id=scan_id,
                    metadata={'scan_id': scan_id},
                    title_en='Disease detected',
                    message_en=f"{detection.get('disease', 'Unknown disease')} detected with {detection.get('severity', 'unknown')} severity.",
                    title_ar='تم اكتشاف مرض',
                    message_ar=f"تم اكتشاف {detection.get('disease', 'مرض غير معروف')} بدرجة خطورة {detection.get('severity', 'غير معروفة')}.",
                )
                event_publisher.disease_detected(
                    scan_id,
                    detection.get('disease', ''),
                    detection.get('severity', ''),
                    user_id,
                )
        else:
            scan_model.update_scan(scan_id, {'status': 'failed'})
    except detection_proxy_service.DetectionValidationError as exc:
        validation_payload = exc.payload
        _store_validation_failure(scan_id, validation_payload)
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

    if validation_payload:
        return _validation_failure_response(scan_id, validation_payload)

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
            'result': subscription_result,
        },
        message,
        201,
    )


@scan_bp.route('/api/scans', methods=['GET'])
@require_auth
def list_scans():
    """List scans for the current user, optionally filtered by farm, field, or crop.

    Free-plan users: limited to the last 3 scans from the current week.
    Paid plans: full paginated history.
    """
    from datetime import datetime, timedelta, timezone
    from bson import ObjectId
    from app.models.db import scans_col
    from app.services.subscription_service import has_feature

    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 20, type=int), 100)
    farm_id = request.args.get('farm_id')
    field_id = request.args.get('field_id')
    crop_type = request.args.get('crop_type', '').strip()

    if farm_id and not is_valid_object_id(farm_id):
        return error_response('Invalid farm_id', 400)
    if field_id and not is_valid_object_id(field_id):
        return error_response('Invalid field_id', 400)

    is_paid = has_feature(g.current_user, 'unlimited_scans')

    if not is_paid:
        # Free plan: last 3 scans from this calendar week (Mon–Sun)
        now = datetime.now(timezone.utc)
        week_start = now - timedelta(days=now.weekday())
        week_start = week_start.replace(hour=0, minute=0, second=0, microsecond=0)

        scans = list(
            scans_col().find({
                'user_id': ObjectId(str(g.current_user['_id'])),
                'created_at': {'$gte': week_start},
            })
            .sort('created_at', -1)
            .limit(3)
        )
        return success_response({
            'scans': [scan_model.serialize(s) for s in scans],
            'page': 1,
            'per_page': 3,
            'history_limited': True,
            'history_limit_reason': (
                'Free plan: showing your last 3 scans this week. '
                'Upgrade to Premium to see your full scan history.'
            ),
        })

    # Paid plans — full history
    scans = scan_model.get_scans_filtered(
        str(g.current_user['_id']),
        farm_id=farm_id,
        field_id=field_id,
        crop_type=crop_type,
        page=page,
        per_page=per_page,
    )
    return success_response({
        'scans': [scan_model.serialize(scan) for scan in scans],
        'page': page,
        'per_page': per_page,
        'history_limited': False,
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
