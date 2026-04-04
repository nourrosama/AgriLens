"""
Health check controller.
Provides a simple endpoint to verify the backend service is running.
"""
from flask import Blueprint, jsonify

from app.models.db import get_db_status
from app.services.storage_service import get_storage_status

health_bp = Blueprint('health', __name__)


@health_bp.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint - returns service status."""
    return jsonify({
        'status': 'ok',
        'service': 'agrilens-backend',
        'version': '0.1.0',
        'integrations': {
            'mongo': get_db_status(),
            'storage': get_storage_status(),
        },
    }), 200
