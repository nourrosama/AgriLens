"""
Disease detection controller.
Accepts image bytes or a remote image URL and returns a crop disease prediction.

Pass include_gradcam=true (form field or JSON key) to receive a base64 PNG
Grad-CAM overlay in the response under the key ``gradcam_overlay``.
"""
import os
import tempfile

from flask import Blueprint, jsonify, request

from app.utils import model_loader

detection_bp = Blueprint('detection', __name__)


def _normalize_crop(crop_type: str) -> str:
    return model_loader.normalize_crop(crop_type)


def _want_gradcam(payload: dict) -> bool:
    """Return True when the caller explicitly requests a Grad-CAM overlay."""
    form_val = request.form.get('include_gradcam', '').strip().lower()
    if form_val in ('1', 'true', 'yes'):
        return True
    return bool(payload.get('include_gradcam', False))


@detection_bp.route('/api/detect', methods=['POST'])
def detect_disease():
    """Accept an image or image_url and return a disease prediction."""
    payload = request.get_json(silent=True) or {}
    if 'image' not in request.files and not payload.get('image_url'):
        return jsonify({'error': 'No image provided'}), 400

    crop_type = _normalize_crop(
        request.form.get('crop_type') or payload.get('crop_type', 'tomato')
    )
    if not model_loader.is_supported_crop(crop_type):
        return (
            jsonify(model_loader.unsupported_crop_payload(crop_type)),
            422,
        )

    include_gradcam = _want_gradcam(payload)

    try:
        if 'image' in request.files and request.files['image'].filename:
            file_bytes = request.files['image'].read()
            prediction = (
                model_loader.predict_from_file_bytes_with_gradcam(file_bytes, crop_type)
                if include_gradcam
                else model_loader.predict_from_file_bytes(file_bytes, crop_type)
            )
        else:
            image_url = payload.get('image_url', '')
            prediction = (
                model_loader.predict_from_url_with_gradcam(image_url, crop_type)
                if include_gradcam
                else model_loader.predict_from_url(image_url, crop_type)
            )
        return jsonify(prediction), 200
    except model_loader.ValidationFailure as exc:
        return jsonify(exc.payload), 422
    except ValueError as exc:
        message = str(exc)
        if message.startswith('NOT_A_PLANT:'):
            clean = message[len('NOT_A_PLANT:'):].strip()
            return jsonify({'error': clean, 'error_code': 'NOT_A_PLANT'}), 422
        return jsonify({'error': message}), 400
    except RuntimeError as exc:
        return (
            jsonify(
                {
                    'error': str(exc),
                    'model_status': model_loader.get_model_status(crop_type),
                }
            ),
            503,
        )
    except Exception as exc:  # pragma: no cover - runtime safety
        return jsonify({'error': f'Inference failed: {exc}'}), 500


@detection_bp.route('/api/video/keyframes', methods=['POST'])
def select_video_keyframes():
    """Return representative frame indices from the local video keyframe model."""
    if 'video' not in request.files or not request.files['video'].filename:
        return jsonify({'error': 'No video provided'}), 400

    max_frames = request.form.get('max_frames', '').strip()
    try:
        max_frames_int = int(max_frames) if max_frames else None
    except ValueError:
        return jsonify({'error': 'max_frames must be an integer'}), 400
    if max_frames_int is not None and max_frames_int <= 0:
        return jsonify({'error': 'max_frames must be greater than zero'}), 400

    suffix = os.path.splitext(request.files['video'].filename)[1] or '.mp4'
    temp_path = ''
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            temp_path = temp_file.name
            request.files['video'].save(temp_file)
        result = model_loader.select_video_keyframes(temp_path, max_frames=max_frames_int)
        return jsonify(result), 200
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400
    except RuntimeError as exc:
        return (
            jsonify(
                {
                    'error': str(exc),
                    'model_status': model_loader.get_model_status().get('special_models', {}).get('video_model'),
                }
            ),
            503,
        )
    except Exception as exc:  # pragma: no cover - runtime safety
        return jsonify({'error': f'Video keyframe selection failed: {exc}'}), 500
    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)
