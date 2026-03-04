"""
FCM Push notification channel (stub).
Logs notifications until Firebase Cloud Messaging is integrated.
"""
import logging

logger = logging.getLogger(__name__)


def send(user_id: str, title: str, body: str):
    """Send push notification via FCM.

    TODO: Integrate firebase-admin SDK to send actual push notifications.
    Requires: user device FCM tokens stored in users collection.
    """
    logger.info(f'📲 [PUSH STUB] to user={user_id} | {title}: {body}')
    # When ready:
    # from firebase_admin import messaging
    # message = messaging.Message(
    #     notification=messaging.Notification(title=title, body=body),
    #     token=user_fcm_token,
    # )
    # messaging.send(message)
