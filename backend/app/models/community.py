"""
Community model — crop-based sub-communities.
Each crop that has ever been scanned gets an auto-created community.
Users are auto-subscribed when they scan a crop for the first time.
"""
from datetime import datetime, timezone

from app.models.db import communities_col


def _ensure_community(crop_slug: str) -> dict:
    """Return the community for a crop, creating it if it does not yet exist."""
    doc = communities_col().find_one({'crop_slug': crop_slug})
    if doc:
        return doc
    new_doc = {
        'crop_slug': crop_slug,
        'display_name': crop_slug.replace('_', ' ').title(),
        'member_ids': [],
        'member_count': 0,
        'trending_diseases': [],
        'pinned_post_ids': [],
        'created_at': datetime.now(timezone.utc),
    }
    result = communities_col().insert_one(new_doc)
    new_doc['_id'] = result.inserted_id
    return new_doc


def auto_subscribe(user_id: str, crop_slug: str) -> None:
    """Add a user to the crop community — idempotent, safe to call repeatedly."""
    if not crop_slug:
        return
    slug = crop_slug.lower().strip()
    _ensure_community(slug)
    communities_col().update_one(
        {'crop_slug': slug, 'member_ids': {'$ne': user_id}},
        {'$addToSet': {'member_ids': user_id}, '$inc': {'member_count': 1}},
    )


def get_all_communities() -> list:
    return list(communities_col().find().sort('member_count', -1))


def get_community(crop_slug: str) -> dict | None:
    return communities_col().find_one({'crop_slug': crop_slug.lower().strip()})


def get_user_communities(user_id: str) -> list:
    return list(communities_col().find({'member_ids': user_id}))


def serialize(community: dict) -> dict:
    if not community:
        return None
    return {
        'id': str(community['_id']),
        'crop_slug': community.get('crop_slug', ''),
        'display_name': community.get('display_name', ''),
        'member_count': community.get('member_count', 0),
        'trending_diseases': community.get('trending_diseases', []),
        'pinned_post_ids': [str(pid) for pid in community.get('pinned_post_ids', [])],
        'created_at': community['created_at'].isoformat() if community.get('created_at') else None,
    }
