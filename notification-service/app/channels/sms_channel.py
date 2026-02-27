"""
SMS notification channel via Twilio.
Logs notifications until Twilio SMS is fully integrated.
"""
import logging

logger = logging.getLogger(__name__)


def send(user_id: str, message: str):
    """Send SMS via Twilio.

    TODO: Look up user's phone from DB and send via Twilio API.
    """
    logger.info(f'📱 [SMS STUB] to user={user_id} | {message}')
    # When ready:
    # from twilio.rest import Client
    # client = Client(account_sid, auth_token)
    # client.messages.create(
    #     body=message,
    #     from_=twilio_phone,
    #     to=user_phone,
    # )
