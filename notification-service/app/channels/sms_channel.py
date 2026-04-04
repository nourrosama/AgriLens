"""SMS notification channel via Twilio."""
import logging

from app.services import runtime

logger = logging.getLogger(__name__)


def send(user_id: str, message: str):
    """Look up the user's phone number and send an SMS alert."""
    user = runtime.get_user(user_id)
    if not user:
        logger.warning('SMS skipped; user %s not found', user_id)
        return
    sid = runtime.send_sms(user.get('phone', ''), message)
    if sid:
        logger.info('SMS sent to user=%s sid=%s', user_id, sid)
