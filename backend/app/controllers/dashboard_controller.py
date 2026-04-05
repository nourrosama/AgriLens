"""
Dashboard controller for the mobile home summary.
"""
from flask import Blueprint, g
from app.middleware.auth_middleware import require_auth
from app.services import insights_service
from app.views.responses import success_response

dashboard_bp = Blueprint('dashboard', __name__)


@dashboard_bp.route('/api/dashboard/summary', methods=['GET'])
@require_auth
def get_dashboard_summary():
    """Return the home dashboard summary for the current user."""
    summary = insights_service.build_dashboard_summary(str(g.current_user['_id']))
    return success_response({'summary': summary})
