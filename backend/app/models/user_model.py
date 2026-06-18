"""
User model — MongoDB CRUD operations for the users collection.
"""
from datetime import datetime, timezone
from bson import ObjectId
from app.models.db import users_col


def create_user(
    phone: str,
    name: str = '',
    language: str = 'ar',
    role: str = 'farmer',
    email: str = '',
    country: str = '',
    photo_url: str = '',
) -> dict:
    """Insert a new user. Returns the created document."""
    doc = {
        'name': name,
        'language': language,
        'role': role,            # farmer | researcher | admin
        'email': email.lower() if email else '',
        'country': country,
        'photo_url': photo_url,
        'plan': 'free',
        'profile_completed': bool(name or country),
        'farms': [],
        'fcm_tokens': [],
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    }
    # Store phone only when provided — the sparse unique index skips null/missing
    # values, so email-only users (phone='') don't collide with each other.
    if phone:
        doc['phone'] = phone
    result = users_col().insert_one(doc)
    doc['_id'] = result.inserted_id
    return doc


def find_by_phone(phone: str) -> dict | None:
    """Find user by phone number. Returns None for empty/blank phone."""
    if not phone:
        return None
    return users_col().find_one({'phone': phone})


def find_by_email(email: str) -> dict | None:
    """Find user by email address (case-insensitive)."""
    return users_col().find_one({'email': email.lower()})


def find_by_id(user_id: str) -> dict | None:
    """Find user by _id."""
    return users_col().find_one({'_id': ObjectId(user_id)})


def update_user(user_id: str, updates: dict) -> bool:
    """Update user fields. Returns True if modified."""
    updates['updated_at'] = datetime.now(timezone.utc)
    result = users_col().update_one(
        {'_id': ObjectId(user_id)},
        {'$set': updates},
    )
    return result.modified_count > 0


def add_farm_ref(user_id: str, farm_id) -> bool:
    """Push a farm ObjectId into the user's farms array."""
    result = users_col().update_one(
        {'_id': ObjectId(user_id)},
        {'$addToSet': {'farms': ObjectId(farm_id)}},
    )
    return result.modified_count > 0


def remove_farm_ref(user_id: str, farm_id) -> bool:
    """Pull a farm ObjectId from the user's farms array."""
    result = users_col().update_one(
        {'_id': ObjectId(user_id)},
        {'$pull': {'farms': ObjectId(farm_id)}},
    )
    return result.modified_count > 0


def add_fcm_token(user_id: str, token: str) -> bool:
    """Attach a device FCM token to the user."""
    result = users_col().update_one(
        {'_id': ObjectId(user_id)},
        {
            '$addToSet': {'fcm_tokens': token},
            '$set': {'updated_at': datetime.now(timezone.utc)},
        },
    )
    return result.modified_count > 0


def remove_fcm_token(user_id: str, token: str) -> bool:
    """Remove a stored device FCM token from the user."""
    result = users_col().update_one(
        {'_id': ObjectId(user_id)},
        {
            '$pull': {'fcm_tokens': token},
            '$set': {'updated_at': datetime.now(timezone.utc)},
        },
    )
    return result.modified_count > 0


def serialize(user: dict) -> dict:
    """Convert a user document to JSON-safe dict."""
    if user is None:
        return None
    return {
        'id': str(user['_id']),
        'phone': user.get('phone', ''),
        'name': user.get('name', ''),
        'language': user.get('language', 'ar'),
        'role': user.get('role', 'farmer'),
        'email': user.get('email', ''),
        'country': user.get('country', ''),
        'photo_url': user.get('photo_url', ''),
        'plan': user.get('plan', 'free'),
        'profile_completed': user.get('profile_completed', False),
        'farms': [str(f) for f in user.get('farms', [])],
        'fcm_tokens': user.get('fcm_tokens', []),
        'created_at': user.get('created_at', '').isoformat() if user.get('created_at') else None,
        'updated_at': user.get('updated_at', '').isoformat() if user.get('updated_at') else None,
    }
