"""
Farm model — MongoDB CRUD for farms and embedded fields.
"""
from datetime import datetime, timezone
from bson import ObjectId
from app.models.db import farms_col


def create_farm(owner_id: str, name: str, location: dict = None) -> dict:
    """Create a new farm."""
    doc = {
        'owner_id': ObjectId(owner_id),
        'name': name,
        'location': location or {},
        'fields': [],
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    }
    result = farms_col().insert_one(doc)
    doc['_id'] = result.inserted_id
    return doc


def get_farms_by_owner(owner_id: str) -> list:
    """List all farms belonging to a user."""
    return list(farms_col().find({'owner_id': ObjectId(owner_id)}))


def get_farm_by_id(farm_id: str) -> dict | None:
    """Get single farm."""
    return farms_col().find_one({'_id': ObjectId(farm_id)})


def update_farm(farm_id: str, updates: dict) -> bool:
    """Update farm fields."""
    updates['updated_at'] = datetime.now(timezone.utc)
    result = farms_col().update_one(
        {'_id': ObjectId(farm_id)},
        {'$set': updates},
    )
    return result.modified_count > 0


def delete_farm(farm_id: str) -> bool:
    """Delete a farm."""
    result = farms_col().delete_one({'_id': ObjectId(farm_id)})
    return result.deleted_count > 0


# ── Field sub-document operations ─────────────────────────────

def add_field(
    farm_id: str,
    name: str,
    crop_type: str = '',
    area_hectares: float = 0,
    location: dict = None,
    soil_type: str = '',
    irrigation_type: str = '',
    season: str = '',
    health_score: float = 0,
    risk_level: str = 'low',
    photo_url: str = '',
) -> dict:
    """Add a field sub-document to a farm."""
    field = {
        'field_id': ObjectId(),
        'name': name,
        'crop_type': crop_type,
        'area_hectares': area_hectares,
        'location': location or {},
        'soil_type': soil_type,
        'irrigation_type': irrigation_type,
        'season': season,
        'health_score': health_score,
        'risk_level': risk_level,
        'photo_url': photo_url,
        'weather_snapshot': {},
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    }
    farms_col().update_one(
        {'_id': ObjectId(farm_id)},
        {
            '$push': {'fields': field},
            '$set': {'updated_at': datetime.now(timezone.utc)},
        },
    )
    return field


def update_field(farm_id: str, field_id: str, updates: dict) -> bool:
    """Update a field sub-document in a farm."""
    updates = dict(updates)
    updates['updated_at'] = datetime.now(timezone.utc)
    set_updates = {f'fields.$.{key}': value for key, value in updates.items()}
    result = farms_col().update_one(
        {
            '_id': ObjectId(farm_id),
            'fields.field_id': ObjectId(field_id),
        },
        {
            '$set': {
                **set_updates,
                'updated_at': datetime.now(timezone.utc),
            },
        },
    )
    return result.modified_count > 0


def get_field(farm_id: str, field_id: str) -> dict | None:
    """Get a single field by id from a farm."""
    farm = get_farm_by_id(farm_id)
    if farm is None:
        return None
    for field in farm.get('fields', []):
        if str(field.get('field_id')) == field_id:
            return field
    return None


def serialize_field(field: dict) -> dict:
    """Convert a field sub-document to JSON-safe dict."""
    return {
        'field_id': str(field.get('field_id', '')),
        'name': field.get('name', ''),
        'crop_type': field.get('crop_type', ''),
        'area_hectares': field.get('area_hectares', 0),
        'location': field.get('location', {}),
        'soil_type': field.get('soil_type', ''),
        'irrigation_type': field.get('irrigation_type', ''),
        'season': field.get('season', ''),
        'health_score': field.get('health_score', 0),
        'risk_level': field.get('risk_level', 'low'),
        'photo_url': field.get('photo_url', ''),
        'weather_snapshot': field.get('weather_snapshot', {}),
        'created_at': field.get('created_at', '').isoformat() if field.get('created_at') else None,
        'updated_at': field.get('updated_at', '').isoformat() if field.get('updated_at') else None,
    }


def remove_field(farm_id: str, field_id: str) -> bool:
    """Remove a field sub-document from a farm."""
    result = farms_col().update_one(
        {'_id': ObjectId(farm_id)},
        {
            '$pull': {'fields': {'field_id': ObjectId(field_id)}},
            '$set': {'updated_at': datetime.now(timezone.utc)},
        },
    )
    return result.modified_count > 0


def serialize(farm: dict) -> dict:
    """Convert farm document to JSON-safe dict."""
    if farm is None:
        return None
    return {
        'id': str(farm['_id']),
        'owner_id': str(farm.get('owner_id', '')),
        'name': farm.get('name', ''),
        'location': farm.get('location', {}),
        'weather_snapshot': farm.get('weather_snapshot', {}),
        'fields': [serialize_field(f) for f in farm.get('fields', [])],
        'created_at': farm.get('created_at', '').isoformat() if farm.get('created_at') else None,
        'updated_at': farm.get('updated_at', '').isoformat() if farm.get('updated_at') else None,
    }
