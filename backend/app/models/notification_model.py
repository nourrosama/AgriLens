"""
Notification model for user-facing alerts.
"""
from datetime import datetime, timezone
from bson import ObjectId
from app.models.db import notifications_col


def create_notification(
    user_id: str,
    title: str,
    message: str,
    category: str = 'info',
    related_scan_id: str = '',
    metadata: dict = None,
) -> dict:
    """Create and store a notification."""
    doc = {
        'user_id': ObjectId(user_id),
        'title': title,
        'message': message,
        'category': category,
        'related_scan_id': ObjectId(related_scan_id) if related_scan_id else None,
        'metadata': metadata or {},
        'is_read': False,
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    }
    result = notifications_col().insert_one(doc)
    doc['_id'] = result.inserted_id
    return doc


def list_notifications(user_id: str, limit: int = 50) -> list:
    """List notifications for a user, newest first."""
    return list(
        notifications_col()
        .find({'user_id': ObjectId(user_id)})
        .sort('created_at', -1)
        .limit(limit)
    )


def get_notification(notification_id: str) -> dict | None:
    """Get a notification by id."""
    return notifications_col().find_one({'_id': ObjectId(notification_id)})


def mark_as_read(notification_id: str, user_id: str) -> bool:
    """Mark a notification as read."""
    result = notifications_col().update_one(
        {'_id': ObjectId(notification_id), 'user_id': ObjectId(user_id)},
        {'$set': {'is_read': True, 'updated_at': datetime.now(timezone.utc)}},
    )
    return result.modified_count > 0


def mark_all_as_read(user_id: str) -> int:
    """Mark all unread notifications as read."""
    result = notifications_col().update_many(
        {'user_id': ObjectId(user_id), 'is_read': False},
        {'$set': {'is_read': True, 'updated_at': datetime.now(timezone.utc)}},
    )
    return result.modified_count


def unread_count(user_id: str) -> int:
    """Count unread notifications for a user."""
    return notifications_col().count_documents(
        {'user_id': ObjectId(user_id), 'is_read': False}
    )


def serialize(notification: dict) -> dict:
    """Convert a notification document to a JSON-safe dict."""
    if notification is None:
        return None
    return {
        'id': str(notification.get('_id', '')),
        'user_id': str(notification.get('user_id', '')),
        'title': notification.get('title', ''),
        'message': notification.get('message', ''),
        'category': notification.get('category', 'info'),
        'related_scan_id': str(notification.get('related_scan_id')) if notification.get('related_scan_id') else None,
        'metadata': notification.get('metadata', {}),
        'is_read': notification.get('is_read', False),
        'created_at': notification.get('created_at', '').isoformat() if notification.get('created_at') else None,
        'updated_at': notification.get('updated_at', '').isoformat() if notification.get('updated_at') else None,
    }
