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
    uri = (app.config.get('MONGO_URI', '') or '').strip()
    if not uri:
        app.logger.error('MONGO_URI is required. Atlas/local Mongo URI was not provided.')
        _client = None
        _db = None
        return None

    try:
        _client = MongoClient(uri, **_mongo_kwargs(uri))
        _client.admin.command('ping')
        _db = _resolve_database(_client)
        app.logger.info('MongoDB connected to database: %s', _db.name)
    except Exception as exc:
        app.logger.warning('MongoDB not reachable: %s', exc)
        _client = None
        _db = None
    return _db


def get_db_status() -> dict:
    """Expose runtime MongoDB state for health checks."""
    return {
        'mongo_ready': _db is not None,
        'database': getattr(_db, 'name', None),
    }


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
