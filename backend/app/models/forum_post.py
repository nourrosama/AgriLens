"""
Forum post model — MongoDB CRUD for community feed posts and comments.
"""
from datetime import datetime, timezone

from bson import ObjectId

from app.models.db import forum_posts_col, forum_comments_col, users_col

CONTENT_TYPES = ('post', 'video', 'article', 'blog')


def _author_fields(author_id) -> dict:
    if not author_id:
        return {'author_name': '', 'author_photo_url': ''}
    user = users_col().find_one({'_id': ObjectId(str(author_id))})
    if not user:
        return {'author_name': '', 'author_photo_url': ''}
    return {
        'author_name': user.get('name', '') or user.get('email', '') or user.get('phone', ''),
        'author_photo_url': user.get('photo_url', ''),
    }


def create_post(
    author_id: str,
    body: str,
    content_type: str = 'post',
    media_url: str = '',
    crop_tags: list = None,
    disease_tags: list = None,
) -> dict:
    """Insert a new forum post and return the full document."""
    if content_type not in CONTENT_TYPES:
        content_type = 'post'
    doc = {
        'author_id': ObjectId(author_id),
        'body': body,
        'content_type': content_type,
        'media_url': media_url or '',
        'tags': {
            'crops': [c.lower() for c in (crop_tags or [])],
            'diseases': [d.lower() for d in (disease_tags or [])],
            'content_type': content_type,
        },
        'likes': [],
        'likes_count': 0,
        'comments_count': 0,
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    }
    result = forum_posts_col().insert_one(doc)
    doc['_id'] = result.inserted_id
    return doc


def toggle_like(post_id: str, user_id: str) -> dict | None:
    """Toggle a like for a user on a post.
    Returns {'liked': bool, 'likes_count': int} or None if post not found.
    """
    col = forum_posts_col()
    post = col.find_one({'_id': ObjectId(post_id)})
    if not post:
        return None

    likes = [str(uid) for uid in (post.get('likes') or [])]
    if user_id in likes:
        col.update_one(
            {'_id': ObjectId(post_id)},
            {'$pull': {'likes': user_id}, '$inc': {'likes_count': -1}},
        )
        return {'liked': False, 'likes_count': max(0, post.get('likes_count', 1) - 1)}
    else:
        col.update_one(
            {'_id': ObjectId(post_id)},
            {'$addToSet': {'likes': user_id}, '$inc': {'likes_count': 1}},
        )
        return {'liked': True, 'likes_count': post.get('likes_count', 0) + 1}


def add_comment(post_id: str, author_id: str, body: str) -> dict:
    """Add a comment to a post and increment the post's comment counter."""
    doc = {
        'post_id': ObjectId(post_id),
        'author_id': ObjectId(author_id),
        'body': body,
        'created_at': datetime.now(timezone.utc),
    }
    forum_comments_col().insert_one(doc)
    forum_posts_col().update_one(
        {'_id': ObjectId(post_id)},
        {'$inc': {'comments_count': 1}},
    )
    return doc


def get_comments(post_id: str, page: int = 1, per_page: int = 20) -> list:
    skip = (page - 1) * per_page
    return list(
        forum_comments_col()
        .find({'post_id': ObjectId(post_id)})
        .sort('created_at', 1)
        .skip(skip)
        .limit(per_page)
    )


def get_posts_by_tags(
    crop_tags: list = None,
    disease_tags: list = None,
    content_type: str = '',
    author_id: str = '',
    page: int = 1,
    per_page: int = 20,
) -> list:
    query = {}
    if crop_tags:
        query['tags.crops'] = {'$in': [t.lower() for t in crop_tags]}
    if disease_tags:
        query['tags.diseases'] = {'$in': [t.lower() for t in disease_tags]}
    if content_type:
        query['tags.content_type'] = content_type
    if author_id:
        query['author_id'] = ObjectId(author_id)
    skip = (page - 1) * per_page
    return list(
        forum_posts_col()
        .find(query)
        .sort([('likes_count', -1), ('created_at', -1)])
        .skip(skip)
        .limit(per_page)
    )


def get_recent_posts(page: int = 1, per_page: int = 20) -> list:
    skip = (page - 1) * per_page
    return list(
        forum_posts_col()
        .find()
        .sort('created_at', -1)
        .skip(skip)
        .limit(per_page)
    )


def get_post_by_id(post_id: str) -> dict | None:
    return forum_posts_col().find_one({'_id': ObjectId(post_id)})


def serialize_post(post: dict, current_user_id: str = '') -> dict:
    if not post:
        return None
    likes = [str(uid) for uid in (post.get('likes') or [])]
    return {
        'id': str(post['_id']),
        'author_id': str(post.get('author_id', '')),
        **_author_fields(post.get('author_id')),
        'body': post.get('body', ''),
        'content_type': post.get('content_type', 'post'),
        'media_url': post.get('media_url', ''),
        'tags': post.get('tags', {}),
        'likes_count': post.get('likes_count', 0),
        'comments_count': post.get('comments_count', 0),
        'liked_by_me': (current_user_id in likes) if current_user_id else False,
        'created_at': post['created_at'].isoformat() if post.get('created_at') else None,
    }


def serialize_comment(comment: dict) -> dict:
    if not comment:
        return None
    return {
        'id': str(comment['_id']),
        'post_id': str(comment.get('post_id', '')),
        'author_id': str(comment.get('author_id', '')),
        **_author_fields(comment.get('author_id')),
        'body': comment.get('body', ''),
        'created_at': comment['created_at'].isoformat() if comment.get('created_at') else None,
    }
