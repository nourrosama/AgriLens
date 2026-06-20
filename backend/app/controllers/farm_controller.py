"""
Farm controller — CRUD for farms and embedded fields.
"""
from flask import Blueprint, request, g, current_app
from app.middleware.auth_middleware import require_auth
from app.models import farm_model, user_model, audit_model
from app.services import insights_service, storage_service
from app.services import cache
from app.utils.validators import is_valid_object_id
from app.views.responses import success_response, error_response

farm_bp = Blueprint('farms', __name__)


@farm_bp.route('/api/farms', methods=['POST'])
@require_auth
def create_farm():
    """Create a new farm.
    ---
    tags:
      - Farms
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - name
          properties:
            name:
              type: string
              example: "Main Farm"
            location:
              type: object
              properties:
                lat:
                  type: number
                  example: 30.04
                lng:
                  type: number
                  example: 31.23
    responses:
      201:
        description: Farm created
    """
    data = request.get_json(silent=True) or {}
    name = data.get('name', '').strip()
    if not name:
        return error_response('Farm name is required', 400)

    user_id = str(g.current_user['_id'])
    location = data.get('location')
    farm = farm_model.create_farm(user_id, name, location)
    if location:
        farm_model.update_farm(str(farm['_id']), {
            'weather_snapshot': insights_service.build_weather(location),
        })
        farm = farm_model.get_farm_by_id(str(farm['_id']))
    user_model.add_farm_ref(user_id, farm['_id'])

    # Invalidate cache
    cache.delete(f'farms:{user_id}')

    audit_model.log_action(user_id, 'farm_created',
                           resource_id=str(farm['_id']),
                           ip_address=request.remote_addr)

    return success_response({'farm': farm_model.serialize(farm)}, 'Farm created', 201)


@farm_bp.route('/api/farms', methods=['GET'])
@require_auth
def list_farms():
    """List all farms for the current user.
    ---
    tags:
      - Farms
    security:
      - Bearer: []
    responses:
      200:
        description: List of farms
    """
    user_id = str(g.current_user['_id'])

    # Try cache first
    cached = cache.get(f'farms:{user_id}')
    if cached:
        return success_response({'farms': cached})

    farms = farm_model.get_farms_by_owner(user_id)
    serialized = [farm_model.serialize(f) for f in farms]

    cache.set(f'farms:{user_id}', serialized, ttl=300)
    return success_response({'farms': serialized})


@farm_bp.route('/api/farms/<farm_id>', methods=['GET'])
@require_auth
def get_farm(farm_id):
    """Get farm details.
    ---
    tags:
      - Farms
    security:
      - Bearer: []
    parameters:
      - in: path
        name: farm_id
        type: string
        required: true
    responses:
      200:
        description: Farm details
      404:
        description: Farm not found
    """
    if not is_valid_object_id(farm_id):
        return error_response('Invalid farm ID', 400)

    farm = farm_model.get_farm_by_id(farm_id)
    if not farm:
        return error_response('Farm not found', 404)
    if str(farm['owner_id']) != str(g.current_user['_id']):
        return error_response('Forbidden', 403)

    return success_response({'farm': farm_model.serialize(farm)})


@farm_bp.route('/api/farms/<farm_id>', methods=['PUT'])
@require_auth
def update_farm(farm_id):
    """Update a farm.
    ---
    tags:
      - Farms
    security:
      - Bearer: []
    parameters:
      - in: path
        name: farm_id
        type: string
        required: true
      - in: body
        name: body
        schema:
          type: object
          properties:
            name:
              type: string
            location:
              type: object
    responses:
      200:
        description: Farm updated
    """
    if not is_valid_object_id(farm_id):
        return error_response('Invalid farm ID', 400)

    farm = farm_model.get_farm_by_id(farm_id)
    if not farm:
        return error_response('Farm not found', 404)
    if str(farm['owner_id']) != str(g.current_user['_id']):
        return error_response('Forbidden', 403)

    data = request.get_json(silent=True) or {}
    updates = {}
    if 'name' in data:
        updates['name'] = data['name']
    if 'location' in data:
        updates['location'] = data['location']
        updates['weather_snapshot'] = insights_service.build_weather(data['location'])

    if updates:
        farm_model.update_farm(farm_id, updates)
        cache.delete(f'farms:{str(g.current_user["_id"])}')

        audit_model.log_action(str(g.current_user['_id']), 'farm_updated',
                               resource_id=farm_id,
                               ip_address=request.remote_addr)

    farm = farm_model.get_farm_by_id(farm_id)
    return success_response({'farm': farm_model.serialize(farm)}, 'Farm updated')


@farm_bp.route('/api/farms/<farm_id>', methods=['DELETE'])
@require_auth
def delete_farm(farm_id):
    """Delete a farm.
    ---
    tags:
      - Farms
    security:
      - Bearer: []
    parameters:
      - in: path
        name: farm_id
        type: string
        required: true
    responses:
      200:
        description: Farm deleted
    """
    if not is_valid_object_id(farm_id):
        return error_response('Invalid farm ID', 400)

    farm = farm_model.get_farm_by_id(farm_id)
    if not farm:
        return error_response('Farm not found', 404)
    if str(farm['owner_id']) != str(g.current_user['_id']):
        return error_response('Forbidden', 403)

    farm_model.delete_farm(farm_id)
    user_model.remove_farm_ref(str(g.current_user['_id']), farm_id)
    cache.delete(f'farms:{str(g.current_user["_id"])}')

    return success_response(message='Farm deleted')


# ── Field sub-routes ──────────────────────────────────────────

@farm_bp.route('/api/farms/<farm_id>/fields', methods=['POST'])
@require_auth
def add_field(farm_id):
    """Add a field to a farm.
    ---
    tags:
      - Farms
    security:
      - Bearer: []
    parameters:
      - in: path
        name: farm_id
        type: string
        required: true
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - name
          properties:
            name:
              type: string
              example: "Field A"
            crop_type:
              type: string
              example: "tomato"
            area_hectares:
              type: number
              example: 2.5
    responses:
      201:
        description: Field added
    """
    if not is_valid_object_id(farm_id):
        return error_response('Invalid farm ID', 400)

    farm = farm_model.get_farm_by_id(farm_id)
    if not farm:
        return error_response('Farm not found', 404)
    if str(farm['owner_id']) != str(g.current_user['_id']):
        return error_response('Forbidden', 403)

    data = request.get_json(silent=True) or {}
    name = data.get('name', '').strip()
    if not name:
        return error_response('Field name is required', 400)

    field = farm_model.add_field(
        farm_id,
        name,
        data.get('crop_type', ''),
        data.get('area_hectares', 0),
        data.get('location'),
        data.get('soil_type', ''),
        data.get('irrigation_type', ''),
        data.get('season', ''),
        data.get('health_score', 0),
        data.get('risk_level', 'low'),
        data.get('photo_url', ''),
    )
    location = data.get('location') or {}
    if location:
        weather = insights_service.build_weather(location)
        farm_model.update_field(
            farm_id,
            str(field['field_id']),
            {'weather_snapshot': weather},
        )
        field = farm_model.get_field(farm_id, str(field['field_id'])) or field
    cache.delete(f'farms:{str(g.current_user["_id"])}')

    return success_response({'field': farm_model.serialize_field(field)}, 'Field added', 201)


@farm_bp.route('/api/farms/<farm_id>/fields/<field_id>', methods=['PUT'])
@require_auth
def update_field(farm_id, field_id):
    """Update a field on a farm."""
    if not is_valid_object_id(farm_id) or not is_valid_object_id(field_id):
        return error_response('Invalid ID', 400)

    farm = farm_model.get_farm_by_id(farm_id)
    if not farm:
        return error_response('Farm not found', 404)
    if str(farm['owner_id']) != str(g.current_user['_id']):
        return error_response('Forbidden', 403)

    data = request.get_json(silent=True) or {}
    allowed_keys = (
        'name',
        'crop_type',
        'area_hectares',
        'location',
        'soil_type',
        'irrigation_type',
        'season',
        'health_score',
        'risk_level',
        'photo_url',
    )
    updates = {key: data[key] for key in allowed_keys if key in data}
    if 'location' in updates:
        updates['weather_snapshot'] = insights_service.build_weather(updates['location'])

    if updates:
        farm_model.update_field(farm_id, field_id, updates)
        cache.delete(f'farms:{str(g.current_user["_id"])}')

    field = farm_model.get_field(farm_id, field_id)
    if field is None:
        return error_response('Field not found', 404)
    return success_response({'field': farm_model.serialize_field(field)}, 'Field updated')


@farm_bp.route('/api/farms/field-photo', methods=['POST'])
@require_auth
def upload_field_photo():
    """Upload a field photo and return the URL."""
    photo = request.files.get('photo')
    if not photo or not photo.filename:
        return error_response('No photo provided', 400)
    try:
        url = storage_service.upload_field_image(photo)
        return success_response({'photo_url': url}, 'Photo uploaded', 201)
    except Exception as exc:
        current_app.logger.exception('Field photo upload failed: %s', exc)
        return error_response('Unable to upload photo. Please try again.', 503)


@farm_bp.route('/api/farms/<farm_id>/fields/<field_id>', methods=['DELETE'])
@require_auth
def remove_field(farm_id, field_id):
    """Remove a field from a farm.
    ---
    tags:
      - Farms
    security:
      - Bearer: []
    parameters:
      - in: path
        name: farm_id
        type: string
        required: true
      - in: path
        name: field_id
        type: string
        required: true
    responses:
      200:
        description: Field removed
    """
    if not is_valid_object_id(farm_id) or not is_valid_object_id(field_id):
        return error_response('Invalid ID', 400)

    farm = farm_model.get_farm_by_id(farm_id)
    if not farm:
        return error_response('Farm not found', 404)
    if str(farm['owner_id']) != str(g.current_user['_id']):
        return error_response('Forbidden', 403)

    farm_model.remove_field(farm_id, field_id)
    cache.delete(f'farms:{str(g.current_user["_id"])}')

    return success_response(message='Field removed')
