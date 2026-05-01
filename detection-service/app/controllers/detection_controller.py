"""
Disease detection controller.
Accepts image bytes or a remote image URL and returns a crop disease prediction.
"""
from flask import Blueprint, jsonify, request

from app.utils import model_loader

detection_bp = Blueprint('detection', __name__)


def _normalize_crop(crop_type: str) -> str:
    return model_loader.normalize_crop(crop_type)


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
            jsonify(
                {
                    'error': f'Unsupported crop type: {crop_type}',
                    'supported_crops': model_loader.supported_crops(),
                }
            ),
            422,
        )

    try:
        if 'image' in request.files and request.files['image'].filename:
            prediction = model_loader.predict_from_file_bytes(
                request.files['image'].read(),
                crop_type,
            )
        else:
            prediction = model_loader.predict_from_url(
                payload.get('image_url', ''),
                crop_type,
            )
        return jsonify(prediction), 200
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400
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
