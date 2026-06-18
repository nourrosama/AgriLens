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


def _mongo_kwargs(uri: str, allow_invalid_certs: bool = False) -> dict:
    kwargs = {
        'serverSelectionTimeoutMS': 15000,
        'connectTimeoutMS': 15000,
    }
    normalized = uri.lower()
    use_tls = normalized.startswith('mongodb+srv://') or 'tls=true' in normalized or 'ssl=true' in normalized
    if use_tls:
        if allow_invalid_certs:
            kwargs['tlsAllowInvalidCertificates'] = True
        else:
            kwargs['tlsCAFile'] = certifi.where()
    return kwargs


def _ensure_indexes(app):
    """Create indexes that the application depends on for correctness and performance."""
    try:
        from pymongo import ASCENDING, DESCENDING
        _db['users'].create_index('phone', unique=True, sparse=True)
        _db['scans'].create_index([('user_id', ASCENDING), ('created_at', DESCENDING)])
        _db['notifications'].create_index([('user_id', ASCENDING), ('is_read', ASCENDING)])
        _db['farms'].create_index('user_id')
        _db['forum_posts'].create_index([('created_at', DESCENDING)])
        _db['forecasts'].create_index([('farm_id', ASCENDING), ('created_at', DESCENDING)])
        _db['audit_logs'].create_index('timestamp', expireAfterSeconds=7776000)
        _db['articles'].create_index([('published', ASCENDING), ('created_at', DESCENDING)])
        _db['support_tickets'].create_index([('user_id', ASCENDING), ('updated_at', DESCENDING)])
        app.logger.info('MongoDB indexes created/verified')
    except Exception as exc:
        app.logger.warning('Index creation warning (non-fatal): %s', exc)


def init_db(app):
    """Initialize MongoDB client from app config. Call once on startup.

    Tries strict TLS verification (certifi) first.  If the connection fails
    due to an SSL certificate error — common in university / corporate networks
    that intercept TLS with a self-signed proxy cert — it retries with
    certificate verification disabled and logs a warning.
    """
    global _client, _db
    uri = (app.config.get('MONGO_URI', '') or '').strip()
    if not uri:
        app.logger.error('MONGO_URI is required. Atlas/local Mongo URI was not provided.')
        _client = None
        _db = None
        return None

    last_exc = None
    for allow_invalid in (False, True):
        try:
            client = MongoClient(uri, **_mongo_kwargs(uri, allow_invalid_certs=allow_invalid))
            client.admin.command('ping')
            _client = client
            _db = _resolve_database(_client)
            if allow_invalid:
                app.logger.warning(
                    'MongoDB connected with TLS certificate verification DISABLED. '
                    'A self-signed certificate was detected in the chain (likely a '
                    'network proxy). This is acceptable for local development but '
                    'must NOT be used in production.'
                )
            else:
                app.logger.info('MongoDB connected to database: %s', _db.name)
            _ensure_indexes(app)
            return _db
        except Exception as exc:
            last_exc = exc
            if allow_invalid:
                # Both attempts failed — give up
                app.logger.warning('MongoDB not reachable: %s', exc)
                _client = None
                _db = None
            # First attempt failed — loop will retry with relaxed TLS

    return _db


def get_db_status() -> dict:
    """Expose runtime MongoDB state for health checks."""
    return {
        'mongo_ready': _db is not None,
        'database': getattr(_db, 'name', None),
    }


def get_db():
    """Return the MongoDB database instance.

    If startup init failed (e.g. MongoDB was not yet ready), attempts a lazy
    reconnect on the first request that needs the database.  This lets the
    backend self-heal after a temporary MongoDB restart without requiring a
    manual container restart.
    """
    global _client, _db
    if _db is not None:
        return _db

    # Lazy reconnect — try once without blocking the request too long.
    try:
        from flask import current_app
        uri = (current_app.config.get('MONGO_URI', '') or '').strip()
        if uri:
            for allow_invalid in (False, True):
                try:
                    client = MongoClient(uri, **_mongo_kwargs(uri, allow_invalid_certs=allow_invalid))
                    client.admin.command('ping')
                    _client = client
                    _db = _resolve_database(_client)
                    current_app.logger.info('MongoDB reconnected lazily: %s', _db.name)
                    _ensure_indexes(current_app)
                    return _db
                except Exception:
                    if allow_invalid:
                        raise
    except Exception as exc:
        try:
            from flask import current_app
            current_app.logger.warning('MongoDB lazy-reconnect failed: %s', exc)
        except RuntimeError:
            pass

    from flask import abort
    abort(503, description='Database unavailable — MongoDB is not reachable.')


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


# ── Forum collections ──────────────────────────────────────────────────────────

def forum_posts_col():
    return get_db()['forum_posts']


def forum_comments_col():
    return get_db()['forum_comments']


def forum_questions_col():
    return get_db()['forum_questions']


def forum_answers_col():
    return get_db()['forum_answers']


def communities_col():
    return get_db()['communities']


# ── Chatbot collections ────────────────────────────────────────────────────────

def chat_sessions_col():
    return get_db()['chat_sessions']


def chat_messages_col():
    return get_db()['chat_messages']


def articles_col():
    return get_db()['articles']


def support_tickets_col():
    return get_db()['support_tickets']
