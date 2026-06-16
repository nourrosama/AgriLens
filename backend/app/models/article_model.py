"""
Article model — MongoDB CRUD for admin-authored articles shown to farmers.
"""
from datetime import datetime, timezone
from bson import ObjectId
from app.models.db import articles_col


def create_article(
    title: str,
    body: str,
    author_id: str,
    category: str = 'general',
    image_url: str = '',
    published: bool = False,
) -> dict:
    doc = {
        'title': title,
        'body': body,
        'author_id': ObjectId(author_id),
        'category': category,       # general | disease | tips | weather
        'image_url': image_url,
        'published': published,
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    }
    result = articles_col().insert_one(doc)
    doc['_id'] = result.inserted_id
    return doc


def get_all_articles(page: int = 1, per_page: int = 20) -> list:
    skip = (page - 1) * per_page
    return list(
        articles_col()
        .find()
        .sort('created_at', -1)
        .skip(skip)
        .limit(per_page)
    )


def get_published_articles(page: int = 1, per_page: int = 20, category: str = '') -> list:
    query = {'published': True}
    if category:
        query['category'] = category
    skip = (page - 1) * per_page
    return list(
        articles_col()
        .find(query)
        .sort('created_at', -1)
        .skip(skip)
        .limit(per_page)
    )


def get_article_by_id(article_id: str) -> dict | None:
    return articles_col().find_one({'_id': ObjectId(article_id)})


def update_article(article_id: str, updates: dict) -> bool:
    updates['updated_at'] = datetime.now(timezone.utc)
    result = articles_col().update_one(
        {'_id': ObjectId(article_id)},
        {'$set': updates},
    )
    return result.modified_count > 0


def delete_article(article_id: str) -> bool:
    result = articles_col().delete_one({'_id': ObjectId(article_id)})
    return result.deleted_count > 0


def count_articles(published_only: bool = False) -> int:
    query = {'published': True} if published_only else {}
    return articles_col().count_documents(query)


def serialize(article: dict) -> dict:
    if article is None:
        return None
    return {
        'id': str(article['_id']),
        'title': article.get('title', ''),
        'body': article.get('body', ''),
        'author_id': str(article.get('author_id', '')),
        'category': article.get('category', 'general'),
        'image_url': article.get('image_url', ''),
        'published': article.get('published', False),
        'created_at': article['created_at'].isoformat() if article.get('created_at') else None,
        'updated_at': article['updated_at'].isoformat() if article.get('updated_at') else None,
    }
