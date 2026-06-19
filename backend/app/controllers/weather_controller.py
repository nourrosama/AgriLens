"""
Weather controller for mobile dashboard weather.
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
    """Return weather data for current coordinates, farm, or field context."""
    farm_id = request.args.get('farm_id')
    field_id = request.args.get('field_id')
    lat = request.args.get('lat', type=float)
    lng = request.args.get('lng', type=float)

    location = {}
    farm = None

    if lat is not None and lng is not None:
        location = {'lat': lat, 'lng': lng, 'source': 'client_current_location'}
    elif farm_id:
        if not is_valid_object_id(farm_id):
            return error_response('Invalid farm ID', 400)
        farm = farm_model.get_farm_by_id(farm_id)
        if not farm or str(farm.get('owner_id')) != str(g.current_user['_id']):
            return error_response('Farm not found', 404)
        location = farm.get('location', {})
        if field_id:
            if not is_valid_object_id(field_id):
                return error_response('Invalid field ID', 400)
            field = next(
                (
                    item for item in farm.get('fields', [])
                    if str(item.get('field_id')) == field_id
                ),
                None,
            )
            if not field:
                return error_response('Field not found', 404)
            location = field.get('location', {}) or location
    else:
        farms = farm_model.get_farms_by_owner(str(g.current_user['_id']))
        if farms:
            farm = farms[0]
            location = farms[0].get('location', {})
            if not location:
                first_field = next(iter(farms[0].get('fields', [])), {})
                location = first_field.get('location', {})

    weather = insights_service.build_weather(location)
    if farm_id and farm:
        if field_id:
            farm_model.update_field(farm_id, field_id, {'weather_snapshot': weather})
        else:
            farm_model.update_farm(farm_id, {'weather_snapshot': weather})

    return success_response({'weather': weather})
