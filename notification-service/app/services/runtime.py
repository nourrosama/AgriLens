"""Integration runtime for Mongo, Twilio SMS, and Firebase Cloud Messaging."""
from __future__ import annotations

import logging
import os
from typing import Any

import certifi
from bson import ObjectId
from pymongo import MongoClient
from pymongo.errors import ConfigurationError

logger = logging.getLogger(__name__)

_mongo_client: MongoClient | None = None
_db = None
_twilio_client = None
_firebase_ready = False


def _resolve_database(client: MongoClient):
    try:
        return client.get_default_database()
    except ConfigurationError:
        return client['agrilens']


def _mongo_kwargs(uri: str) -> dict:
    kwargs = {
        'serverSelectionTimeoutMS': 15000,
        'connectTimeoutMS': 15000,
    }
    normalized = uri.lower()
    use_tls = normalized.startswith('mongodb+srv://') or 'tls=true' in normalized or 'ssl=true' in normalized
    if use_tls:
        kwargs['tlsCAFile'] = certifi.where()
    return kwargs


def init_runtime(app) -> None:
    """Initialize external integrations once at startup."""
    global _mongo_client, _db, _twilio_client, _firebase_ready

    mongo_uri = app.config.get('MONGO_URI', '')
    if mongo_uri:
        try:
            _mongo_client = MongoClient(mongo_uri, **_mongo_kwargs(mongo_uri))
            _mongo_client.admin.command('ping')
            _db = _resolve_database(_mongo_client)
            app.logger.info('MongoDB connected for notification-service: %s', _db.name)
        except Exception as exc:  # pragma: no cover - runtime safety
            app.logger.warning('MongoDB init failed: %s', exc)
            _mongo_client = None
            _db = None

    sid = app.config.get('TWILIO_ACCOUNT_SID', '')
    token = app.config.get('TWILIO_AUTH_TOKEN', '')
    if sid and token:
        try:
            from twilio.rest import Client

            _twilio_client = Client(sid, token)
            app.logger.info('Twilio SMS client initialized')
        except Exception as exc:  # pragma: no cover - runtime safety
            app.logger.warning('Twilio init failed: %s', exc)
            _twilio_client = None

    creds_path = app.config.get('FIREBASE_CREDENTIALS_PATH', '')
    if creds_path and os.path.exists(creds_path):
        try:
            import firebase_admin
            from firebase_admin import credentials

            if not firebase_admin._apps:
                cred = credentials.Certificate(creds_path)
                firebase_admin.initialize_app(cred)
            _firebase_ready = True
            app.logger.info('Firebase admin initialized for push delivery')
        except Exception as exc:  # pragma: no cover - runtime safety
            app.logger.warning('Firebase init failed: %s', exc)
            _firebase_ready = False


def get_status() -> dict[str, Any]:
    return {
        'mongo_ready': _db is not None,
        'twilio_ready': _twilio_client is not None,
        'firebase_ready': _firebase_ready,
    }


def get_user(user_id: str) -> dict | None:
    if _db is None:
        return None
    try:
        return _db['users'].find_one({'_id': ObjectId(user_id)})
    except Exception as exc:  # pragma: no cover - runtime safety
        logger.warning('Failed to fetch user %s: %s', user_id, exc)
        return None


def send_sms(phone: str, body: str) -> str | None:
    if _twilio_client is None:
        logger.warning('Twilio client is not ready; SMS not sent')
        return None
    if not phone:
        logger.warning('No phone number provided for SMS delivery')
        return None

    params = {'body': body, 'to': phone}
    messaging_service_sid = os.getenv('TWILIO_MESSAGING_SERVICE_SID', '')
    from_number = os.getenv('TWILIO_PHONE_NUMBER', '')
    if messaging_service_sid:
        params['messaging_service_sid'] = messaging_service_sid
    elif from_number:
        params['from_'] = from_number
    else:
        logger.warning('Twilio SMS sender is not configured')
        return None

    message = _twilio_client.messages.create(**params)
    return getattr(message, 'sid', None)


def send_push(tokens: list[str], title: str, body: str, data: dict[str, str] | None = None) -> int:
    if not _firebase_ready:
        logger.warning('Firebase admin is not ready; push notification not sent')
        return 0
    tokens = [token for token in tokens if token]
    if not tokens:
        return 0

    from firebase_admin import messaging

    sent = 0
    for token in tokens:
        try:
            message = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                token=token,
                data=data or {},
            )
            messaging.send(message)
            sent += 1
        except Exception as exc:  # pragma: no cover - runtime safety
            logger.warning('Failed to send push to token %s: %s', token, exc)
    return sent
