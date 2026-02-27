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

def add_field(farm_id: str, name: str, crop_type: str = '', area_hectares: float = 0) -> dict:
    """Add a field sub-document to a farm."""
    field = {
        'field_id': ObjectId(),
        'name': name,
        'crop_type': crop_type,
        'area_hectares': area_hectares,
    }
    farms_col().update_one(
        {'_id': ObjectId(farm_id)},
        {
            '$push': {'fields': field},
            '$set': {'updated_at': datetime.now(timezone.utc)},
        },
    )
    return field


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
        'fields': [
            {
                'field_id': str(f.get('field_id', '')),
                'name': f.get('name', ''),
                'crop_type': f.get('crop_type', ''),
                'area_hectares': f.get('area_hectares', 0),
            }
            for f in farm.get('fields', [])
        ],
        'created_at': farm.get('created_at', '').isoformat() if farm.get('created_at') else None,
        'updated_at': farm.get('updated_at', '').isoformat() if farm.get('updated_at') else None,
    }
