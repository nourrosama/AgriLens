"""Firebase Cloud Messaging push notification channel."""
import logging

from app.services import runtime

logger = logging.getLogger(__name__)


def send(
    user_id: str,
    title_en: str,
    body_en: str,
    title_ar: str = '',
    body_ar: str = '',
    scan_id: str = '',
):
    """Send a push notification to all stored FCM tokens for the user.

    Picks the language that matches the user's stored preference (language='ar'
    or anything else defaults to English).  scan_id is embedded in the data
    payload so the Flutter app can deep-link to the scan result screen.
    """
    user = runtime.get_user(user_id)
    if not user:
        logger.warning('Push skipped; user %s not found', user_id)
        return

    lang = user.get('language', 'en')
    title = title_ar if lang == 'ar' and title_ar else title_en
    body = body_ar if lang == 'ar' and body_ar else body_en

    tokens = user.get('fcm_tokens', [])
    sent = runtime.send_push(
        tokens, title, body,
        data={'user_id': user_id, 'scan_id': scan_id},
    )
    logger.info('Push delivery attempted for user=%s scan=%s lang=%s sent=%s',
                user_id, scan_id, lang, sent)
