"""
Disease Detection Controller (STUB)
Returns mock detection results.
DSAI team will replace with real CNN/YOLO inference.
"""
import random
from flask import Blueprint, request, jsonify

detection_bp = Blueprint('detection', __name__)

# Mock disease classes from the tomato dataset
DISEASE_CLASSES = [
    'Tomato___Bacterial_spot',
    'Tomato___Early_blight',
    'Tomato___Late_blight',
    'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot',
    'Tomato___Spider_mites Two-spotted_spider_mite',
    'Tomato___Target_Spot',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
    'Tomato___Tomato_mosaic_virus',
    'Tomato___healthy',
]


@detection_bp.route('/api/detect', methods=['POST'])
def detect_disease():
    """
    Accepts an image and returns disease detection results.

    Request: multipart/form-data with 'image' file
    Response: {
        "disease": str,
        "confidence": float,
        "severity": str,
        "is_healthy": bool,
        "bbox": [x, y, width, height]
    }
    """
    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400

    # STUB: Return mock detection result
    # TODO: Replace with actual model inference
    disease = random.choice(DISEASE_CLASSES)
    confidence = round(random.uniform(0.75, 0.99), 4)
    is_healthy = disease == 'Tomato___healthy'

    severity_map = {True: 'none', False: random.choice(['low', 'medium', 'high', 'critical'])}

    return jsonify({
        'disease': disease,
        'confidence': confidence,
        'severity': severity_map[is_healthy],
        'is_healthy': is_healthy,
        'bbox': [50, 50, 200, 200],
    }), 200
