"""
Audit log model — tracks user actions for security & monitoring.
"""
from datetime import datetime, timezone
from bson import ObjectId
from app.models.db import audit_col


def log_action(
    user_id: str,
    action: str,
    resource_id: str = None,
    ip_address: str = '',
    details: dict = None,
):
    """Record an audit event."""
    doc = {
        'user_id': ObjectId(user_id) if user_id else None,
        'action': action,
        'resource_id': ObjectId(resource_id) if resource_id else None,
        'ip_address': ip_address,
        'details': details or {},
        'timestamp': datetime.now(timezone.utc),
    }
    audit_col().insert_one(doc)


def get_logs_for_user(user_id: str, limit: int = 50) -> list:
    """Recent audit logs for a user."""
    return list(
        audit_col()
        .find({'user_id': ObjectId(user_id)})
        .sort('timestamp', -1)
        .limit(limit)
    )
