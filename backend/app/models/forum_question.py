"""
Forum Q&A model — questions and answers (StackOverflow-style).
"""
from datetime import datetime, timezone

from bson import ObjectId

from app.models.db import forum_questions_col, forum_answers_col, users_col


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


def create_question(
    author_id: str,
    title: str,
    body: str,
    crop_tags: list = None,
    disease_tags: list = None,
) -> dict:
    doc = {
        'author_id': ObjectId(author_id),
        'title': title,
        'body': body,
        'tags': {
            'crops': [c.lower() for c in (crop_tags or [])],
            'diseases': [d.lower() for d in (disease_tags or [])],
        },
        'answer_count': 0,
        'is_resolved': False,
        'accepted_answer_id': None,
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    }
    result = forum_questions_col().insert_one(doc)
    doc['_id'] = result.inserted_id
    return doc


def create_answer(question_id: str, author_id: str, body: str) -> dict:
    """Add an answer and increment the parent question's answer_count."""
    doc = {
        'question_id': ObjectId(question_id),
        'author_id': ObjectId(author_id),
        'body': body,
        'is_accepted': False,
        'upvotes': 0,
        'upvoters': [],
        'created_at': datetime.now(timezone.utc),
    }
    forum_answers_col().insert_one(doc)
    forum_questions_col().update_one(
        {'_id': ObjectId(question_id)},
        {'$inc': {'answer_count': 1}, '$set': {'updated_at': datetime.now(timezone.utc)}},
    )
    return doc


def accept_answer(answer_id: str, question_id: str, requester_id: str) -> bool:
    """Mark answer as accepted. Only the question's author may do this.
    Returns False if unauthorised or question not found.
    """
    question = forum_questions_col().find_one({'_id': ObjectId(question_id)})
    if not question:
        return False
    if str(question['author_id']) != requester_id:
        return False

    # Clear any previous accepted answer on this question
    forum_answers_col().update_many(
        {'question_id': ObjectId(question_id)},
        {'$set': {'is_accepted': False}},
    )
    forum_answers_col().update_one(
        {'_id': ObjectId(answer_id)},
        {'$set': {'is_accepted': True}},
    )
    forum_questions_col().update_one(
        {'_id': ObjectId(question_id)},
        {'$set': {
            'is_resolved': True,
            'accepted_answer_id': ObjectId(answer_id),
            'updated_at': datetime.now(timezone.utc),
        }},
    )
    return True


def get_questions(
    crop_tags: list = None,
    disease_tags: list = None,
    author_id: str = '',
    answered_by: str = '',
    page: int = 1,
    per_page: int = 20,
) -> list:
    query = {}
    if crop_tags:
        query['tags.crops'] = {'$in': [t.lower() for t in crop_tags]}
    if disease_tags:
        query['tags.diseases'] = {'$in': [t.lower() for t in disease_tags]}
    if author_id:
        query['author_id'] = ObjectId(author_id)
    if answered_by:
        answer_question_ids = [
            item['question_id']
            for item in forum_answers_col().find(
                {'author_id': ObjectId(answered_by)},
                {'question_id': 1},
            )
        ]
        query['_id'] = {'$in': answer_question_ids or [ObjectId()]}
    skip = (page - 1) * per_page
    return list(
        forum_questions_col()
        .find(query)
        .sort('created_at', -1)
        .skip(skip)
        .limit(per_page)
    )


def get_answers(question_id: str) -> list:
    """Return answers sorted: accepted first, then by upvotes, then chronologically."""
    return list(
        forum_answers_col()
        .find({'question_id': ObjectId(question_id)})
        .sort([('is_accepted', -1), ('upvotes', -1), ('created_at', 1)])
    )


def get_question_by_id(question_id: str) -> dict | None:
    return forum_questions_col().find_one({'_id': ObjectId(question_id)})


def get_answer_by_id(answer_id: str) -> dict | None:
    return forum_answers_col().find_one({'_id': ObjectId(answer_id)})


def serialize_question(q: dict) -> dict:
    if not q:
        return None
    return {
        'id': str(q['_id']),
        'author_id': str(q.get('author_id', '')),
        **_author_fields(q.get('author_id')),
        'title': q.get('title', ''),
        'body': q.get('body', ''),
        'tags': q.get('tags', {}),
        'answer_count': q.get('answer_count', 0),
        'is_resolved': q.get('is_resolved', False),
        'accepted_answer_id': str(q['accepted_answer_id']) if q.get('accepted_answer_id') else None,
        'created_at': q['created_at'].isoformat() if q.get('created_at') else None,
    }


def serialize_answer(a: dict) -> dict:
    if not a:
        return None
    return {
        'id': str(a['_id']),
        'question_id': str(a.get('question_id', '')),
        'author_id': str(a.get('author_id', '')),
        **_author_fields(a.get('author_id')),
        'body': a.get('body', ''),
        'is_accepted': a.get('is_accepted', False),
        'upvotes': a.get('upvotes', 0),
        'created_at': a['created_at'].isoformat() if a.get('created_at') else None,
    }
