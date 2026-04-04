from flask import Blueprint, jsonify

from app.services.runtime import get_status

health_bp = Blueprint('health', __name__)


@health_bp.route('/api/health', methods=['GET'])
def health_check():
    integrations = get_status()
    return jsonify({
        'status': 'ok' if all(integrations.values()) else 'degraded',
        'service': 'agrilens-notification-service',
        'version': '0.2.0',
        'integrations': integrations,
    }), 200
