"""
FCM push notification service.
Sends notifications to user devices via Firebase Admin SDK.
Falls back gracefully when Firebase credentials are not configured.
"""
import logging
import os

logger = logging.getLogger(__name__)

_firebase_app = None
_firebase_enabled = False


def init_push_service(app):
    """Initialize Firebase Admin SDK.  Called once on startup."""
    global _firebase_app, _firebase_enabled

    creds_path = app.config.get('FIREBASE_CREDENTIALS_PATH', '')
    if not creds_path or not os.path.exists(creds_path):
        app.logger.warning(
            'Firebase credentials not found at "%s". '
            'Push notifications disabled — set FIREBASE_CREDENTIALS_PATH in .env.',
            creds_path,
        )
        return

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(creds_path)
        _firebase_app = firebase_admin.initialize_app(cred)
        _firebase_enabled = True
        app.logger.info('Firebase Admin SDK initialised — push notifications enabled.')
    except ImportError:
        app.logger.warning(
            'firebase-admin package is not installed. '
            'Push notifications disabled. Run: pip install firebase-admin'
        )
    except Exception as exc:
        app.logger.warning('Firebase init failed: %s. Push notifications disabled.', exc)


def send_push_to_user(user: dict, title: str, body: str, data: dict | None = None):
    """
    Send an FCM push notification to ALL registered devices of *user*.

    Parameters
    ----------
    user    : MongoDB user document (must contain 'fcm_tokens' list)
    title   : Notification title string
    body    : Notification body string
    data    : Optional extra key-value data payload (string values only)

    If Firebase is not configured this is a no-op and logs a message instead.
    """
    tokens: list[str] = user.get('fcm_tokens', [])
    if not tokens:
        logger.debug('No FCM tokens for user %s — skipping push.', user.get('_id'))
        return

    if not _firebase_enabled:
        logger.info(
            '[MOCK PUSH] "%s" → %s (user %s, %d device(s))',
            title, body, user.get('_id'), len(tokens),
        )
        return

    try:
        from firebase_admin import messaging

        actor_photo = (data or {}).get('actor_photo_url', '')
        messages = [
            messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                android=messaging.AndroidConfig(
                    notification=messaging.AndroidNotification(image=actor_photo),
                ) if actor_photo else None,
                data={k: str(v) for k, v in (data or {}).items()},
                token=token,
            )
            for token in tokens
        ]
        response = messaging.send_each(messages, app=_firebase_app)
        logger.info(
            'FCM push sent to user %s: %d success / %d failure',
            user.get('_id'),
            response.success_count,
            response.failure_count,
        )
    except Exception as exc:
        logger.warning('FCM send failed for user %s: %s', user.get('_id'), exc)
