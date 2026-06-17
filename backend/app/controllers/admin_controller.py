"""
Admin controller — protected endpoints for the admin web dashboard.
All routes require role='admin'.
"""
from flask import Blueprint, request, g
from bson import ObjectId

from app.middleware.admin_middleware import require_admin
from app.models import user_model, article_model, audit_model
from app.models.db import (
    users_col, scans_col, farms_col, articles_col, audit_col, notifications_col
)
from app.models.scan_model import count_scans_by_user, serialize as serialize_scan
from app.views.responses import success_response, error_response

admin_bp = Blueprint('admin', __name__, url_prefix='/api/admin')


# ── Stats ──────────────────────────────────────────────────────────────────────

@admin_bp.route('/stats', methods=['GET'])
@require_admin
def get_stats():
    """Platform-wide stats for the admin dashboard."""
    total_users   = users_col().count_documents({})
    total_scans   = scans_col().count_documents({})
    total_farms   = farms_col().count_documents({})
    total_articles = articles_col().count_documents({})
    published_articles = articles_col().count_documents({'published': True})

    # Scan status breakdown
    scan_completed = scans_col().count_documents({'status': 'completed'})
    scan_failed    = scans_col().count_documents({'status': 'failed'})
    scan_pending   = scans_col().count_documents({'status': {'$in': ['pending', 'processing']}})

    # Top 5 detected diseases
    pipeline = [
        {'$match': {'status': 'completed', 'detection_result': {'$ne': None}}},
        {'$group': {'_id': '$detection_result.disease_name', 'count': {'$sum': 1}}},
        {'$sort': {'count': -1}},
        {'$limit': 5},
    ]
    top_diseases = [
        {'disease': r['_id'] or 'Unknown', 'count': r['count']}
        for r in scans_col().aggregate(pipeline)
    ]

    # New users in last 30 days
    from datetime import datetime, timedelta, timezone
    since = datetime.now(timezone.utc) - timedelta(days=30)
    new_users_30d = users_col().count_documents({'created_at': {'$gte': since}})

    return success_response({
        'users': {
            'total': total_users,
            'new_last_30_days': new_users_30d,
        },
        'scans': {
            'total': total_scans,
            'completed': scan_completed,
            'failed': scan_failed,
            'pending': scan_pending,
        },
        'farms': {'total': total_farms},
        'articles': {
            'total': total_articles,
            'published': published_articles,
        },
        'top_diseases': top_diseases,
    })


# ── User management ───────────────────────────────────────────────────────────

@admin_bp.route('/users', methods=['GET'])
@require_admin
def list_users():
    """Paginated list of all users."""
    page     = max(1, int(request.args.get('page', 1)))
    per_page = min(100, int(request.args.get('per_page', 20)))
    search   = request.args.get('search', '').strip()
    role     = request.args.get('role', '').strip()

    query = {}
    if search:
        query['$or'] = [
            {'name':  {'$regex': search, '$options': 'i'}},
            {'phone': {'$regex': search, '$options': 'i'}},
            {'email': {'$regex': search, '$options': 'i'}},
        ]
    if role:
        query['role'] = role

    skip  = (page - 1) * per_page
    total = users_col().count_documents(query)
    users = list(users_col().find(query).sort('created_at', -1).skip(skip).limit(per_page))

    return success_response({
        'users': [user_model.serialize(u) for u in users],
        'total': total,
        'page': page,
        'per_page': per_page,
        'pages': -(-total // per_page),
    })


@admin_bp.route('/users/<user_id>', methods=['PUT'])
@require_admin
def update_user(user_id):
    """Update role or active status of a user."""
    data    = request.get_json(silent=True) or {}
    allowed = {}

    if 'role' in data:
        if data['role'] not in ('farmer', 'researcher', 'admin'):
            return error_response('Invalid role', 400)
        allowed['role'] = data['role']

    if 'active' in data:
        allowed['active'] = bool(data['active'])

    if not allowed:
        return error_response('Nothing to update', 400)

    user_model.update_user(user_id, allowed)
    audit_model.log_action(
        str(g.current_user['_id']),
        f'admin_update_user:{user_id}',
        details=allowed,
    )
    user = user_model.find_by_id(user_id)
    return success_response({'user': user_model.serialize(user)}, 'User updated')


@admin_bp.route('/users/<user_id>', methods=['GET'])
@require_admin
def get_user(user_id):
    """Get a single user with their scan count."""
    user = user_model.find_by_id(user_id)
    if not user:
        return error_response('User not found', 404)
    data = user_model.serialize(user)
    data['total_scans'] = scans_col().count_documents({'user_id': ObjectId(user_id)})
    data['total_farms'] = farms_col().count_documents({'owner_id': ObjectId(user_id)})
    return success_response({'user': data})


# ── Scans (all users) ─────────────────────────────────────────────────────────

@admin_bp.route('/scans', methods=['GET'])
@require_admin
def list_all_scans():
    """Paginated list of all scans across every user."""
    page     = max(1, int(request.args.get('page', 1)))
    per_page = min(100, int(request.args.get('per_page', 20)))
    status   = request.args.get('status', '').strip()

    query = {}
    if status:
        query['status'] = status

    skip   = (page - 1) * per_page
    total  = scans_col().count_documents(query)
    scans  = list(scans_col().find(query).sort('created_at', -1).skip(skip).limit(per_page))

    return success_response({
        'scans': [serialize_scan(s) for s in scans],
        'total': total,
        'page': page,
        'per_page': per_page,
        'pages': -(-total // per_page),
    })


# ── Articles ──────────────────────────────────────────────────────────────────

@admin_bp.route('/articles', methods=['GET'])
@require_admin
def list_articles():
    page     = max(1, int(request.args.get('page', 1)))
    per_page = min(100, int(request.args.get('per_page', 20)))
    articles = article_model.get_all_articles(page, per_page)
    total    = article_model.count_articles()
    return success_response({
        'articles': [article_model.serialize(a) for a in articles],
        'total': total,
        'page': page,
        'pages': -(-total // per_page),
    })


@admin_bp.route('/articles', methods=['POST'])
@require_admin
def create_article():
    data = request.get_json(silent=True) or {}
    title = str(data.get('title', '')).strip()
    body  = str(data.get('body', '')).strip()

    if not title or not body:
        return error_response('title and body are required', 400)

    article = article_model.create_article(
        title=title,
        body=body,
        author_id=str(g.current_user['_id']),
        category=data.get('category', 'general'),
        image_url=data.get('image_url', ''),
        published=bool(data.get('published', False)),
    )
    return success_response({'article': article_model.serialize(article)}, 'Article created', 201)


@admin_bp.route('/articles/<article_id>', methods=['PUT'])
@require_admin
def update_article(article_id):
    data    = request.get_json(silent=True) or {}
    allowed = {}
    for field in ('title', 'body', 'category', 'image_url'):
        if field in data:
            allowed[field] = str(data[field]).strip()
    if 'published' in data:
        allowed['published'] = bool(data['published'])

    if not allowed:
        return error_response('Nothing to update', 400)

    article_model.update_article(article_id, allowed)
    article = article_model.get_article_by_id(article_id)
    return success_response({'article': article_model.serialize(article)}, 'Article updated')


@admin_bp.route('/articles/<article_id>', methods=['DELETE'])
@require_admin
def delete_article(article_id):
    if not article_model.delete_article(article_id):
        return error_response('Article not found', 404)
    return success_response(message='Article deleted')


# ── Broadcast notification ─────────────────────────────────────────────────────

@admin_bp.route('/notifications/broadcast', methods=['POST'])
@require_admin
def broadcast_notification():
    """Send a notification to all users (or a role segment)."""
    from datetime import datetime, timezone
    data    = request.get_json(silent=True) or {}
    title   = str(data.get('title', '')).strip()
    message = str(data.get('message', '')).strip()
    role    = data.get('role', '')   # '' = all users

    if not title or not message:
        return error_response('title and message are required', 400)

    query = {}
    if role:
        query['role'] = role

    user_ids = [str(u['_id']) for u in users_col().find(query, {'_id': 1})]

    docs = [
        {
            'user_id': ObjectId(uid),
            'title': title,
            'message': message,
            'type': 'broadcast',
            'is_read': False,
            'created_at': datetime.now(timezone.utc),
        }
        for uid in user_ids
    ]
    if docs:
        notifications_col().insert_many(docs)

    audit_model.log_action(
        str(g.current_user['_id']),
        'admin_broadcast',
        details={'title': title, 'recipients': len(docs)},
    )

    return success_response({'recipients': len(docs)}, 'Notification sent')


# ── Audit logs ────────────────────────────────────────────────────────────────

@admin_bp.route('/audit-logs', methods=['GET'])
@require_admin
def list_audit_logs():
    page     = max(1, int(request.args.get('page', 1)))
    per_page = min(100, int(request.args.get('per_page', 50)))
    skip     = (page - 1) * per_page
    total    = audit_col().count_documents({})
    logs     = list(audit_col().find().sort('timestamp', -1).skip(skip).limit(per_page))

    def _serialize(log):
        return {
            'id': str(log['_id']),
            'user_id': str(log.get('user_id', '')),
            'action': log.get('action', ''),
            'ip_address': log.get('ip_address', ''),
            'details': log.get('details', {}),
            'timestamp': log['timestamp'].isoformat() if log.get('timestamp') else None,
        }

    return success_response({
        'logs': [_serialize(l) for l in logs],
        'total': total,
        'page': page,
        'pages': -(-total // per_page),
    })
