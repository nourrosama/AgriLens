"""
Redis caching utility — caches farm data and recent scan results.
Redis is NOT used for OTP storage (Twilio Verify handles that).
"""
import json
import logging
import redis

logger = logging.getLogger(__name__)

_redis = None
DEFAULT_TTL = 300  # 5 minutes


def init_cache(app):
    """Initialize Redis connection for caching."""
    global _redis
    try:
        _redis = redis.from_url(app.config.get('REDIS_URL', 'redis://localhost:6379/0'))
        _redis.ping()
        app.logger.info('✅ Redis connected (caching)')
    except Exception as e:
        app.logger.warning(f'⚠️  Redis cache not reachable: {e}')
        _redis = None


def get(key: str):
    """Get a cached value (returns parsed JSON or None)."""
    if _redis is None:
        return None
    try:
        val = _redis.get(key)
        return json.loads(val) if val else None
    except Exception:
        return None


def set(key: str, value, ttl: int = DEFAULT_TTL):
    """Cache a value as JSON with TTL in seconds."""
    if _redis is None:
        return
    try:
        _redis.setex(key, ttl, json.dumps(value, default=str))
    except Exception as e:
        logger.warning(f'Cache set failed: {e}')


def delete(key: str):
    """Remove a cached key."""
    if _redis is None:
        return
    try:
        _redis.delete(key)
    except Exception:
        pass


def invalidate_pattern(pattern: str):
    """Delete all keys matching a glob pattern."""
    if _redis is None:
        return
    try:
        for key in _redis.scan_iter(match=pattern):
            _redis.delete(key)
    except Exception as e:
        logger.warning(f'Cache invalidate failed: {e}')
