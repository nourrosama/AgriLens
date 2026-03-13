"""
Disease Detection Controller
Real CNN inference using trained paddy and tomato models.
"""
from flask import Blueprint, request, jsonify
from services.paddy_services import predict as paddy_predict
from services.tomato_service import predict as tomato_predict

detection_bp = Blueprint('detection', __name__)


@detection_bp.route('/api/detect', methods=['POST'])
def detect_disease():
    """
    Accepts an image and crop_type, returns disease detection results.

    Request: multipart/form-data with:
        - 'image'     : image file (jpg, png, webp)
        - 'crop_type' : 'paddy' or 'tomato'

    Response: {
        "disease": str,
        "confidence": float,
        "severity": str,
        "is_healthy": bool,
        "probabilities": dict
    }
    """
    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400

    crop_type = request.form.get('crop_type', 'tomato').lower()
    if crop_type not in ('paddy', 'tomato'):
        return jsonify({'error': 'crop_type must be paddy or tomato'}), 400

    image_bytes = request.files['image'].read()

    # ── Run real model inference ──
    if crop_type == 'paddy':
        result = paddy_predict(image_bytes)
    else:
        result = tomato_predict(image_bytes)

    disease    = result['predicted_class']
    confidence = result['confidence']
    is_healthy = 'healthy' in disease.lower()

    # Map confidence to severity
    if is_healthy:
        severity = 'none'
    elif confidence >= 0.90:
        severity = 'critical'
    elif confidence >= 0.75:
        severity = 'high'
    elif confidence >= 0.50:
        severity = 'medium'
    else:
        severity = 'low'

    return jsonify({
        'disease':       disease,
        'confidence':    confidence,
        'severity':      severity,
        'is_healthy':    is_healthy,
        'probabilities': result['probabilities'],
    }), 200