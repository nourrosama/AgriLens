"""
Health check controller.
Provides a simple endpoint to verify the backend service is running.
"""
import os
from flask import Blueprint, jsonify

from app.models.db import get_db_status
from app.services.storage_service import get_storage_status

health_bp = Blueprint('health', __name__)

APP_VERSION = os.environ.get('APP_VERSION', '1.0.0')
APK_URL = 'https://github.com/nourrosama/AgriLens/releases/latest/download/app-release.apk'


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


@health_bp.route('/api/version', methods=['GET'])
def app_version():
    """Returns the latest mobile app version and APK download URL."""
    return jsonify({
        'version': APP_VERSION,
        'apk_url': APK_URL,
    }), 200
