"""Notification controller for mobile alert retrieval and device token registration."""
from flask import Blueprint, g, request
from app.middleware.auth_middleware import require_auth
from app.models import notification_model, user_model
from app.utils.validators import is_valid_object_id
from app.views.responses import success_response, error_response

notifications_bp = Blueprint('notifications', __name__)


@notifications_bp.route('/api/notifications', methods=['GET'])
@require_auth
def list_notifications():
    """Return notifications for the current user."""
    user_id = str(g.current_user['_id'])
    notifications = notification_model.list_notifications(user_id, 100)
    return success_response({
        'notifications': [notification_model.serialize(item) for item in notifications],
        'unread_count': notification_model.unread_count(user_id),
    })


@notifications_bp.route('/api/notifications/<notification_id>/read', methods=['PUT'])
@require_auth
def mark_notification_read(notification_id):
    """Mark a notification as read."""
    if not is_valid_object_id(notification_id):
        return error_response('Invalid notification ID', 400)
    updated = notification_model.mark_as_read(notification_id, str(g.current_user['_id']))
    if not updated:
        return error_response('Notification not found', 404)
    notification = notification_model.get_notification(notification_id)
    return success_response({'notification': notification_model.serialize(notification)}, 'Notification updated')


@notifications_bp.route('/api/notifications/read-all', methods=['PUT'])
@require_auth
def mark_all_notifications_read():
    """Mark all notifications as read for the current user."""
    count = notification_model.mark_all_as_read(str(g.current_user['_id']))
    return success_response({'updated_count': count}, 'Notifications updated')


@notifications_bp.route('/api/notifications/device-token', methods=['POST'])
@require_auth
def register_device_token():
    """Register an FCM device token for the current user."""
    data = request.get_json(silent=True) or {}
    token = (data.get('token') or '').strip()
    if not token:
        return error_response('Device token is required', 400)

    user_model.add_fcm_token(str(g.current_user['_id']), token)
    user = user_model.find_by_id(str(g.current_user['_id']))
    return success_response(
        {
            'registered': True,
            'fcm_token_count': len((user or {}).get('fcm_tokens', [])),
        },
        'Device token registered',
    )


@notifications_bp.route('/api/notifications/device-token', methods=['DELETE'])
@require_auth
def unregister_device_token():
    """Remove an FCM device token for the current user."""
    data = request.get_json(silent=True) or {}
    token = (data.get('token') or '').strip()
    if not token:
        return error_response('Device token is required', 400)

    user_model.remove_fcm_token(str(g.current_user['_id']), token)
    user = user_model.find_by_id(str(g.current_user['_id']))
    return success_response(
        {
            'removed': True,
            'fcm_token_count': len((user or {}).get('fcm_tokens', [])),
        },
        'Device token removed',
    )
