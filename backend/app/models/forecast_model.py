"""
Forecast snapshot storage for per-user farm risk summaries.
"""
from datetime import datetime, timezone
from bson import ObjectId
from app.models.db import forecasts_col


def upsert_snapshot(user_id: str, scope: dict, payload: dict) -> dict:
    """Store the latest forecast snapshot for a farm or field."""
    now = datetime.now(timezone.utc)
    filter_doc = {
        'user_id': ObjectId(user_id),
        'farm_id': ObjectId(scope['farm_id']) if scope.get('farm_id') else None,
        'field_id': ObjectId(scope['field_id']) if scope.get('field_id') else None,
    }
    doc = {
        **filter_doc,
        'payload': payload,
        'updated_at': now,
        'created_at': now,
    }
    forecasts_col().update_one(
        filter_doc,
        {
            '$set': {
                'payload': payload,
                'updated_at': now,
            },
            '$setOnInsert': {
                'created_at': now,
            },
        },
        upsert=True,
    )
    stored = forecasts_col().find_one(filter_doc)
    return stored or doc


def latest_for_user(user_id: str, limit: int = 20) -> list:
    """Return forecast snapshots for a user."""
    return list(
        forecasts_col()
        .find({'user_id': ObjectId(user_id)})
        .sort('updated_at', -1)
        .limit(limit)
    )


def serialize(snapshot: dict) -> dict:
    """Convert a forecast snapshot to a JSON-safe dict."""
    if snapshot is None:
        return None
    return {
        'id': str(snapshot.get('_id', '')),
        'user_id': str(snapshot.get('user_id', '')),
        'farm_id': str(snapshot.get('farm_id')) if snapshot.get('farm_id') else None,
        'field_id': str(snapshot.get('field_id')) if snapshot.get('field_id') else None,
        'payload': snapshot.get('payload', {}),
        'created_at': snapshot.get('created_at', '').isoformat() if snapshot.get('created_at') else None,
        'updated_at': snapshot.get('updated_at', '').isoformat() if snapshot.get('updated_at') else None,
    }
