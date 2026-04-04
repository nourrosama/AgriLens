"""
Forecast controller for mobile risk and trend views.
"""
from flask import Blueprint, request, g
from app.middleware.auth_middleware import require_auth
from app.models import farm_model, forecast_model, scan_model
from app.services import insights_service
from app.utils.validators import is_valid_object_id
from app.views.responses import success_response, error_response

forecast_bp = Blueprint('forecast', __name__)


@forecast_bp.route('/api/forecast', methods=['POST'])
@require_auth
def get_forecast():
    """Return a derived disease risk forecast for a farm or field."""
    data = request.get_json(silent=True) or {}
    farm_id = data.get('farm_id')
    field_id = data.get('field_id')
    days_ahead = min(max(int(data.get('days_ahead', 7)), 1), 14)

    scope = {'farm_id': None, 'field_id': None}
    location = {}
    if farm_id:
        if not is_valid_object_id(farm_id):
            return error_response('Invalid farm ID', 400)
        farm = farm_model.get_farm_by_id(farm_id)
        if not farm or str(farm.get('owner_id')) != str(g.current_user['_id']):
            return error_response('Farm not found', 404)
        scope['farm_id'] = farm_id
        location = farm.get('location', {})
    if field_id:
        if not is_valid_object_id(field_id):
            return error_response('Invalid field ID', 400)
        scope['field_id'] = field_id

    if farm_id:
        scans = scan_model.get_scans_by_farm(farm_id, 1, 50)
    else:
        scans = scan_model.get_scans_by_user(str(g.current_user['_id']), 1, 50)

    weather = insights_service.build_weather(location, days_ahead)
    forecast_payload = insights_service.compute_forecast(scans, weather, days_ahead)
    snapshot = forecast_model.upsert_snapshot(str(g.current_user['_id']), scope, forecast_payload)
    return success_response({
        'forecast': forecast_payload,
        'snapshot': forecast_model.serialize(snapshot),
    })
