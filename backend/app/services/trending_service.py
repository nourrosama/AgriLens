"""
Trending service — computes most-discussed diseases, most-scanned crops,
and most-liked posts from the last 7–30 days.

Results are cached in-process for 15 minutes to avoid hammering MongoDB
on every feed load.
"""
import time
from datetime import datetime, timezone, timedelta

from app.models.db import scans_col, get_db

_TTL = 15 * 60  # seconds
_cache: dict = {'data': None, 'computed_at': 0.0}


def get_trending(force_refresh: bool = False) -> dict:
    """Return cached trending data, recomputing if stale."""
    now = time.monotonic()
    if not force_refresh and _cache['data'] and (now - _cache['computed_at']) < _TTL:
        return _cache['data']

    data = _compute()
    _cache['data'] = data
    _cache['computed_at'] = now
    return data


def _compute() -> dict:
    since_30d = datetime.now(timezone.utc) - timedelta(days=30)
    since_7d = datetime.now(timezone.utc) - timedelta(days=7)

    # Top scanned crops — last 30 days
    crop_pipeline = [
        {
            '$match': {
                'status': 'completed',
                'created_at': {'$gte': since_30d},
                'crop_type': {'$nin': ['', None]},
            }
        },
        {'$group': {'_id': '$crop_type', 'count': {'$sum': 1}}},
        {'$sort': {'count': -1}},
        {'$limit': 5},
    ]
    top_crops = [
        {'crop': row['_id'], 'scan_count': row['count']}
        for row in scans_col().aggregate(crop_pipeline)
        if row.get('_id')
    ]

    # Top detected diseases — last 30 days
    disease_pipeline = [
        {
            '$match': {
                'status': 'completed',
                'created_at': {'$gte': since_30d},
                'detection_result.is_healthy': False,
                'detection_result.disease': {'$nin': ['', None]},
            }
        },
        {'$group': {'_id': '$detection_result.disease', 'count': {'$sum': 1}}},
        {'$sort': {'count': -1}},
        {'$limit': 5},
    ]
    top_diseases = [
        {'disease': row['_id'], 'count': row['count']}
        for row in scans_col().aggregate(disease_pipeline)
        if row.get('_id')
    ]

    # Trending posts — most liked in last 7 days
    posts_col = get_db()['forum_posts']
    post_pipeline = [
        {'$match': {'created_at': {'$gte': since_7d}}},
        {'$sort': {'likes_count': -1, 'comments_count': -1}},
        {'$limit': 5},
        {
            '$project': {
                'body': 1,
                'content_type': 1,
                'likes_count': 1,
                'comments_count': 1,
                'tags': 1,
            }
        },
    ]
    trending_posts = []
    for p in posts_col.aggregate(post_pipeline):
        trending_posts.append({
            'id': str(p['_id']),
            'body': (p.get('body') or '')[:120],
            'content_type': p.get('content_type', 'post'),
            'likes_count': p.get('likes_count', 0),
            'comments_count': p.get('comments_count', 0),
            'tags': p.get('tags', {}),
        })

    return {
        'top_crops': top_crops,
        'top_diseases': top_diseases,
        'trending_posts': trending_posts,
    }
