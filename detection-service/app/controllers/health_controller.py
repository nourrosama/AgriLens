from flask import Blueprint, jsonify

from app.utils.model_loader import get_model_status

health_bp = Blueprint("health", __name__)


@health_bp.route("/api/health", methods=["GET"])
def health_check():
    model_status = get_model_status()
    return (
        jsonify(
            {
                "status": "ok" if model_status.get("ready") else "degraded",
                "service": "agrilens-detection-service",
                "version": "0.2.0",
                "model": model_status,
            }
        ),
        200,
    )
