"""
Database connection module.
Lazy init pattern — call init_db(app) from main.py.
"""
from pymongo import MongoClient

_client = None
_db = None


def init_db(app):
    """Initialize MongoDB client from app config. Call once on startup."""
    global _client, _db
    uri = app.config.get('MONGO_URI', 'mongodb://localhost:27017/agrilens')
    _client = MongoClient(uri, serverSelectionTimeoutMS=5000)
    _db = _client.get_default_database()
    # Quick connectivity check
    try:
        _client.admin.command('ping')
        app.logger.info('✅ MongoDB connected')
    except Exception as e:
        app.logger.warning(f'⚠️  MongoDB not reachable: {e}')
    return _db


def get_db():
    """Returns the MongoDB database instance."""
    if _db is None:
        raise RuntimeError('Database not initialised — call init_db(app) first')
    return _db


# ── Collection accessors ─────────────────────────────────────
def users_col():
    return get_db()['users']

def farms_col():
    return get_db()['farms']

def scans_col():
    return get_db()['scans']

def audit_col():
    return get_db()['audit_logs']
