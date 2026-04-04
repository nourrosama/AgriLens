"""
Report export controller for the mobile reports screen.
"""
from datetime import datetime, timezone
from flask import Blueprint, request, g
from app.middleware.auth_middleware import require_auth
from app.models import farm_model, notification_model, scan_model
from app.services import insights_service
from app.views.responses import success_response

reports_bp = Blueprint('reports', __name__)


@reports_bp.route('/api/reports/export', methods=['GET'])
@require_auth
def export_report():
    """Return a derived report payload that can be shown or exported by the app."""
    user_id = str(g.current_user['_id'])
    period = request.args.get('period', 'weekly')
    export_format = request.args.get('format', 'json')
    farms = [farm_model.serialize(item) for item in farm_model.get_farms_by_owner(user_id)]
    scans = [scan_model.serialize(item) for item in scan_model.get_scans_by_user(user_id, 1, 100)]
    notifications = [notification_model.serialize(item) for item in notification_model.list_notifications(user_id, 100)]
    summary = insights_service.build_dashboard_summary(user_id)
    report = {
        'period': period,
        'format': export_format,
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'summary': summary,
        'farms': farms,
        'scans': scans,
        'notifications': notifications,
    }
    return success_response({
        'report': report,
        'filename': f'agrilens-{period}-report.{export_format}',
    })
