"""
Database connection module.
Lazy init pattern -- call init_db(app) from main.py.
"""
import certifi
from pymongo import MongoClient
from pymongo.errors import ConfigurationError

_client = None
_db = None


def _resolve_database(client):
    """Return the URI database or fall back to agrilens."""
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


def init_db(app):
    """Initialize MongoDB client from app config. Call once on startup."""
    global _client, _db
    uri = app.config.get('MONGO_URI', 'mongodb://localhost:27017/agrilens')
    _client = MongoClient(uri, **_mongo_kwargs(uri))
    _db = _resolve_database(_client)
    try:
        _client.admin.command('ping')
        app.logger.info('MongoDB connected to database: %s', _db.name)
    except Exception as exc:
        app.logger.warning('MongoDB not reachable: %s', exc)
    return _db


def get_db():
    """Return the MongoDB database instance."""
    if _db is None:
        raise RuntimeError('Database not initialised -- call init_db(app) first')
    return _db


def users_col():
    return get_db()['users']


def farms_col():
    return get_db()['farms']


def scans_col():
    return get_db()['scans']


def audit_col():
    return get_db()['audit_logs']


def notifications_col():
    return get_db()['notifications']


def forecasts_col():
    return get_db()['forecasts']
