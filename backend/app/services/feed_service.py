"""
Feed recommendation service.
Builds a personalised feed by ranking forum posts against the user's scan history.

Scoring formula (per post):
  crop_match_weight * 10   — proportional to how often the user scans that crop
  disease_match * 20       — recent detected disease matches a post disease tag
  popularity_boost         — capped contribution from likes + comments
"""
from bson import ObjectId

from app.models.db import scans_col
from app.models import forum_post as post_model


# ── Scan-history helpers ───────────────────────────────────────────────────────

def _get_user_crop_weights(user_id: str) -> dict:
    """Return {crop_slug: scan_count} for completed scans by this user."""
    pipeline = [
        {'$match': {'user_id': ObjectId(user_id), 'status': 'completed', 'crop_type': {'$nin': ['', None]}}},
        {'$group': {'_id': '$crop_type', 'count': {'$sum': 1}}},
    ]
    return {row['_id'].lower(): row['count'] for row in scans_col().aggregate(pipeline)}


def _get_recent_diseases(user_id: str, limit: int = 5) -> list:
    """Return lowercase disease names from the user's most recent failed scans."""
    pipeline = [
        {
            '$match': {
                'user_id': ObjectId(user_id),
                'status': 'completed',
                'detection_result.is_healthy': False,
            }
        },
        {'$sort': {'created_at': -1}},
        {'$limit': limit},
        {'$project': {'disease': '$detection_result.disease'}},
    ]
    diseases = []
    for row in scans_col().aggregate(pipeline):
        d = row.get('disease') or ''
        if d:
            diseases.append(d.lower())
    return diseases


# ── Scoring ────────────────────────────────────────────────────────────────────

def _score_post(post: dict, crop_weights: dict, disease_tags: list) -> int:
    score = 0
    tags = post.get('tags', {})
    for crop in tags.get('crops', []):
        score += crop_weights.get(crop.lower(), 0) * 10
    for disease in tags.get('diseases', []):
        if disease.lower() in disease_tags:
            score += 20
    score += min(post.get('likes_count', 0), 50)
    score += min(post.get('comments_count', 0) * 2, 30)
    return score


# ── Public API ─────────────────────────────────────────────────────────────────

def get_personalised_feed(user_id: str, page: int = 1, per_page: int = 20) -> list:
    """Return a relevance-ranked, paginated feed for a user.
    Falls back to recency ordering when the user has no scan history.
    """
    crop_weights = _get_user_crop_weights(user_id)
    disease_tags = _get_recent_diseases(user_id)

    if not crop_weights:
        posts = post_model.get_recent_posts(page=page, per_page=per_page)
        return [post_model.serialize_post(p, user_id) for p in posts]

    # Fetch a wider window, re-rank in Python, then return the requested page.
    fetch_limit = per_page * 5
    offset = (page - 1) * per_page
    candidates = post_model.get_recent_posts(page=1, per_page=fetch_limit + offset)

    scored = sorted(
        candidates,
        key=lambda p: _score_post(p, crop_weights, disease_tags),
        reverse=True,
    )
    page_posts = scored[offset: offset + per_page]
    return [post_model.serialize_post(p, user_id) for p in page_posts]


def get_post_scan_suggestions(crop_type: str, disease: str, limit: int = 3) -> list:
    """Return N posts relevant to a just-completed scan.
    Used by the 'From the Community' card on the scan result screen.
    """
    crop_slug = crop_type.lower().strip() if crop_type else ''
    disease_slug = disease.lower().strip() if disease else ''

    posts = post_model.get_posts_by_tags(
        crop_tags=[crop_slug] if crop_slug else None,
        disease_tags=[disease_slug] if disease_slug else None,
        per_page=limit,
    )

    # Pad with recent posts if not enough tagged content
    if len(posts) < limit:
        seen_ids = {str(p['_id']) for p in posts}
        extras = post_model.get_recent_posts(per_page=limit * 3)
        for p in extras:
            if str(p['_id']) not in seen_ids and len(posts) < limit:
                posts.append(p)
                seen_ids.add(str(p['_id']))

    return [post_model.serialize_post(p) for p in posts[:limit]]
