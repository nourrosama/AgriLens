"""
Disease Detection Controller.
Uses deterministic demo inference until the production model is integrated.
"""
import hashlib
from flask import Blueprint, request, jsonify

detection_bp = Blueprint('detection', __name__)

CATALOG = {
    'tomato': [
        {
            'disease': 'Tomato Early Blight',
            'scientific_name': 'Alternaria solani',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Remove affected leaves and start preventive fungicide coverage.',
        },
        {
            'disease': 'Tomato Late Blight',
            'scientific_name': 'Phytophthora infestans',
            'severity': 'high',
            'risk_level': 'high',
            'recommendation': 'Act quickly, isolate infected plants, and reduce leaf wetness.',
        },
        {
            'disease': 'Tomato Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Keep monitoring and maintain balanced irrigation.',
        },
    ],
    'corn': [
        {
            'disease': 'Corn Leaf Blight',
            'scientific_name': 'Exserohilum turcicum',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Scout neighboring plants and avoid prolonged leaf wetness.',
        },
        {
            'disease': 'Corn Rust',
            'scientific_name': 'Puccinia sorghi',
            'severity': 'low',
            'risk_level': 'low',
            'recommendation': 'Track humidity and monitor lesion spread over the next week.',
        },
        {
            'disease': 'Corn Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Continue routine scouting.',
        },
    ],
    'wheat': [
        {
            'disease': 'Wheat Rust',
            'scientific_name': 'Puccinia triticina',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Monitor canopy humidity and inspect nearby leaves for spread.',
        },
        {
            'disease': 'Powdery Mildew',
            'scientific_name': 'Blumeria graminis',
            'severity': 'low',
            'risk_level': 'low',
            'recommendation': 'Increase airflow and continue monitoring susceptible areas.',
        },
        {
            'disease': 'Wheat Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Maintain balanced nutrition and scouting.',
        },
    ],
    'sweetpotato': [
        {
            'disease': 'Sweet Potato Leaf Spot',
            'scientific_name': 'Cercospora spp.',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Remove heavily affected leaves and keep foliage dry where possible.',
        },
        {
            'disease': 'Sweet Potato Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Continue routine monitoring.',
        },
    ],
}


def _normalize_crop(crop_type: str) -> str:
    return (crop_type or "tomato").strip().lower().replace("_", "").replace(" ", "")


@detection_bp.route("/api/detect", methods=["POST"])
def detect_disease():
    """Accept an image or image_url and return a tomato disease prediction."""
    payload = request.get_json(silent=True) or {}
    if "image" not in request.files and not payload.get("image_url"):
        return jsonify({"error": "No image provided"}), 400

    crop_type = _normalize_crop(
        request.form.get("crop_type") or payload.get("crop_type", "tomato")
    )
    if crop_type not in ("", "tomato"):
        return (
            jsonify(
                {
                    "error": "This detection model currently supports tomato scans only.",
                    "supported_crops": ["tomato"],
                }
            ),
            422,
        )

    try:
        if "image" in request.files and request.files["image"].filename:
            prediction = model_loader.predict_from_file_bytes(
                request.files["image"].read()
            )
        else:
            prediction = model_loader.predict_from_url(payload.get("image_url", ""))
        return jsonify(prediction), 200
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400
    except RuntimeError as exc:
        return (
            jsonify(
                {
                    "error": str(exc),
                    "model_status": model_loader.get_model_status(),
                }
            ),
            503,
        )
    except Exception as exc:  # pragma: no cover - runtime safety
        return jsonify({"error": f"Inference failed: {exc}"}), 500
