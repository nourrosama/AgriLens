"""
Weather controller for mobile dashboard and forecasting.
"""
from flask import Blueprint, request, g
from app.middleware.auth_middleware import require_auth
from app.models import farm_model
from app.services import insights_service
from app.views.responses import success_response, error_response
from app.utils.validators import is_valid_object_id

weather_bp = Blueprint('weather', __name__)


@weather_bp.route('/api/weather', methods=['GET'])
@require_auth
def get_weather():
    """Return weather data for the user's current farm context."""
    farm_id = request.args.get('farm_id')
    location = {}
    if farm_id:
        if not is_valid_object_id(farm_id):
            return error_response('Invalid farm ID', 400)
        farm = farm_model.get_farm_by_id(farm_id)
        if not farm or str(farm.get('owner_id')) != str(g.current_user['_id']):
            return error_response('Farm not found', 404)
        location = farm.get('location', {})
    else:
        farms = farm_model.get_farms_by_owner(str(g.current_user['_id']))
        if farms:
            location = farms[0].get('location', {})
            if not location:
                first_field = next(iter(farms[0].get('fields', [])), {})
                location = first_field.get('location', {})
    weather = insights_service.build_weather(location)
    return success_response({'weather': weather})
