"""Firebase Cloud Messaging push notification channel."""
import logging

from app.services import runtime

logger = logging.getLogger(__name__)


def send(user_id: str, title: str, body: str):
    """Send a push notification to all stored FCM tokens for the user."""
    user = runtime.get_user(user_id)
    if not user:
        logger.warning('Push skipped; user %s not found', user_id)
        return
    tokens = user.get('fcm_tokens', [])
    sent = runtime.send_push(tokens, title, body, data={'user_id': user_id})
    logger.info('Push delivery attempted for user=%s sent=%s', user_id, sent)
