"""
Forum controller — community feed, posts, comments, and Q&A endpoints.
"""
from bson import ObjectId
from flask import Blueprint, current_app, g, request

import html

from app.middleware.auth_middleware import require_auth
from app.models import notification_model, user_model
from app.models import forum_post as post_model
from app.models.db import forum_posts_col, forum_comments_col
from app.models import forum_question as question_model
from app.models import community as community_model
from app.services import feed_service, push_service, trending_service, storage_service
from app.utils.validators import is_valid_object_id
from app.views.responses import error_response, success_response
from app.controllers.scan_controller import _verify_magic_bytes

ALLOWED_MEDIA = {'jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'avi', 'mkv', 'pdf'}
_ALLOWED_IMG = {'jpg', 'jpeg', 'png', 'webp'}
_ALLOWED_VID = {'mp4', 'mov', 'avi', 'mkv'}

forum_bp = Blueprint('forum', __name__)


def _notify_forum_interaction(
    recipient_id: str,
    actor_id: str,
    title_en: str,
    message_en: str,
    title_ar: str,
    message_ar: str,
    metadata: dict,
) -> None:
    if not recipient_id or recipient_id == actor_id:
        return
    notification_model.create_notification(
        user_id=recipient_id,
        title=title_en,
        message=message_en,
        category='forum',
        metadata=metadata,
        title_en=title_en,
        message_en=message_en,
        title_ar=title_ar,
        message_ar=message_ar,
    )
    user = user_model.find_by_id(recipient_id)
    if not user:
        return
    lang = user.get('language', 'en')
    push_service.send_push_to_user(
        user=user,
        title=title_ar if lang == 'ar' else title_en,
        body=message_ar if lang == 'ar' else message_en,
        data={**metadata, 'category': 'forum'},
    )


# ── Media upload ─────────────────────────────────────────────────────────────

@forum_bp.route('/api/forum/upload', methods=['POST'])
@require_auth
def upload_media():
    """Upload an image, video or document for a forum post.
    Returns a media_url to embed in the post body.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    consumes:
      - multipart/form-data
    parameters:
      - in: formData
        name: file
        type: file
        required: true
    responses:
      200:
        description: Upload successful — returns media_url
    """
    if 'file' not in request.files or not request.files['file'].filename:
        return error_response('No file provided', 400)

    file = request.files['file']
    ext = file.filename.rsplit('.', 1)[-1].lower() if '.' in file.filename else ''
    if ext not in ALLOWED_MEDIA:
        return error_response(f'File type .{ext} not allowed', 400)

    if ext in _ALLOWED_IMG and not _verify_magic_bytes(file.stream, _ALLOWED_IMG):
        return error_response('File content does not match a supported image format', 400)
    if ext in _ALLOWED_VID and not _verify_magic_bytes(file.stream, _ALLOWED_VID):
        return error_response('File content does not match a supported video format', 400)

    try:
        if ext in {'mp4', 'mov', 'avi', 'mkv'}:
            media_url = storage_service.upload_video(file)
        else:
            media_url = storage_service.upload_image(file)
        return success_response({'media_url': media_url, 'file_type': ext})
    except Exception as exc:
        current_app.logger.exception('Forum media upload failed: %s', exc)
        return error_response('Upload failed — please try again', 503)


# ── Feed ──────────────────────────────────────────────────────────────────────

@forum_bp.route('/api/feed', methods=['GET'])
@require_auth
def get_feed():
    """Personalised ranked feed for the current user.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    parameters:
      - in: query
        name: page
        type: integer
        default: 1
      - in: query
        name: per_page
        type: integer
        default: 20
    responses:
      200:
        description: Paginated personalised feed
    """
    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 20, type=int), 50)
    user_id = str(g.current_user['_id'])
    posts = feed_service.get_personalised_feed(user_id, page=page, per_page=per_page)
    return success_response({'posts': posts, 'page': page, 'per_page': per_page})


@forum_bp.route('/api/feed/trending', methods=['GET'])
@require_auth
def get_trending():
    """Trending crops, diseases, and posts (cached 15 min).
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    responses:
      200:
        description: Trending data
    """
    data = trending_service.get_trending()
    return success_response(data)


@forum_bp.route('/api/feed/post-scan', methods=['GET'])
@require_auth
def get_post_scan_suggestions():
    """3 community posts relevant to a just-completed scan.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    parameters:
      - in: query
        name: crop_type
        type: string
      - in: query
        name: disease
        type: string
    responses:
      200:
        description: Up to 3 relevant posts
    """
    crop_type = request.args.get('crop_type', '').strip()
    disease = request.args.get('disease', '').strip()
    posts = feed_service.get_post_scan_suggestions(crop_type, disease)
    return success_response({'posts': posts})


# ── Posts ─────────────────────────────────────────────────────────────────────

@forum_bp.route('/api/posts', methods=['GET'])
@require_auth
def list_posts():
    """List posts, optionally filtered by content_type / crop / disease tag.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    parameters:
      - in: query
        name: content_type
        type: string
        enum: [post, video, article, blog]
      - in: query
        name: crop
        type: string
      - in: query
        name: disease
        type: string
      - in: query
        name: page
        type: integer
        default: 1
      - in: query
        name: per_page
        type: integer
        default: 20
    responses:
      200:
        description: Filtered posts list
    """
    content_type = request.args.get('content_type', '').strip() or None
    crop        = request.args.get('crop', '').strip()
    disease     = request.args.get('disease', '').strip()
    page        = request.args.get('page', 1, type=int)
    per_page    = min(request.args.get('per_page', 20, type=int), 50)
    user_id     = str(g.current_user['_id'])

    posts = post_model.get_posts_by_tags(
        crop_tags=[crop] if crop else None,
        disease_tags=[disease] if disease else None,
        content_type=content_type,
        page=page,
        per_page=per_page,
    )
    return success_response({
        'posts': [post_model.serialize_post(p, user_id) for p in posts],
        'page': page,
        'per_page': per_page,
    })


@forum_bp.route('/api/posts', methods=['POST'])
@require_auth
def create_post():
    """Create a community post.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          required: [body]
          properties:
            body:
              type: string
            content_type:
              type: string
              enum: [post, video, article, blog]
            media_url:
              type: string
            crop_tags:
              type: array
              items:
                type: string
            disease_tags:
              type: array
              items:
                type: string
    responses:
      201:
        description: Post created
    """
    data = request.get_json(silent=True) or {}
    body = (data.get('body') or '').strip()
    if not body:
        return error_response('Post body is required', 400)

    body = html.escape(body)

    user_id = str(g.current_user['_id'])
    crop_tags = data.get('crop_tags') or []
    post = post_model.create_post(
        author_id=user_id,
        body=body,
        content_type=data.get('content_type', 'post'),
        media_url=data.get('media_url', ''),
        crop_tags=crop_tags,
        disease_tags=data.get('disease_tags') or [],
    )

    # Auto-subscribe the author to each crop community they tag
    for crop in crop_tags:
        community_model.auto_subscribe(user_id, crop)

    return success_response(
        {'post': post_model.serialize_post(post, user_id)},
        'Post created',
        201,
    )


@forum_bp.route('/api/posts/<post_id>', methods=['DELETE'])
@require_auth
def delete_post(post_id):
    """Delete a post. Only the post author may delete it."""
    user_id = str(g.current_user['_id'])
    try:
        oid = ObjectId(post_id)
    except Exception:
        return error_response('Invalid post ID', 400)

    col = forum_posts_col()
    post = col.find_one({'_id': oid})
    if not post:
        return error_response('Post not found', 404)
    if str(post.get('author_id', '')) != user_id:
        return error_response('You can only delete your own posts', 403)

    col.delete_one({'_id': oid})
    # Remove associated comments
    forum_comments_col().delete_many({'post_id': post_id})
    return success_response({'deleted': True})


@forum_bp.route('/api/posts/<post_id>/like', methods=['POST'])
@require_auth
def toggle_like(post_id):
    """Toggle like on a post.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    responses:
      200:
        description: Like toggled — returns liked status and new count
    """
    if not is_valid_object_id(post_id):
        return error_response('Invalid post ID', 400)
    user_id = str(g.current_user['_id'])
    result = post_model.toggle_like(post_id, user_id)
    if result is None:
        return error_response('Post not found', 404)
    return success_response(result)


@forum_bp.route('/api/posts/<post_id>/comments', methods=['GET'])
@require_auth
def get_comments(post_id):
    """List comments for a post.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    parameters:
      - in: query
        name: page
        type: integer
        default: 1
    responses:
      200:
        description: Comments list
    """
    if not is_valid_object_id(post_id):
        return error_response('Invalid post ID', 400)
    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 20, type=int), 50)
    comments = post_model.get_comments(post_id, page=page, per_page=per_page)
    return success_response({
        'comments': [post_model.serialize_comment(c) for c in comments],
        'page': page,
    })


@forum_bp.route('/api/posts/<post_id>/comments', methods=['POST'])
@require_auth
def add_comment(post_id):
    """Add a comment to a post.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          required: [body]
          properties:
            body:
              type: string
    responses:
      201:
        description: Comment added
    """
    if not is_valid_object_id(post_id):
        return error_response('Invalid post ID', 400)
    data = request.get_json(silent=True) or {}
    body = (data.get('body') or '').strip()
    if not body:
        return error_response('Comment body is required', 400)
    body = html.escape(body)
    user_id = str(g.current_user['_id'])
    comment = post_model.add_comment(post_id, user_id, body)
    post = post_model.get_post_by_id(post_id)
    if post:
        _notify_forum_interaction(
            recipient_id=str(post.get('author_id', '')),
            actor_id=user_id,
            title_en='New comment',
            message_en='Someone commented on your forum post.',
            title_ar='تعليق جديد',
            message_ar='قام أحد المستخدمين بالتعليق على منشورك في المنتدى.',
            metadata={'post_id': post_id, 'comment_id': str(comment.get('_id', ''))},
        )
    return success_response(
        {'comment': post_model.serialize_comment(comment)},
        'Comment added',
        201,
    )


# ── Q&A ───────────────────────────────────────────────────────────────────────

@forum_bp.route('/api/forum/questions', methods=['GET'])
@require_auth
def list_questions():
    """List Q&A questions, filterable by crop / disease tag.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    parameters:
      - in: query
        name: crop
        type: string
      - in: query
        name: disease
        type: string
      - in: query
        name: page
        type: integer
        default: 1
    responses:
      200:
        description: Questions list
    """
    crop = request.args.get('crop', '').strip()
    disease = request.args.get('disease', '').strip()
    filter_key = request.args.get('filter', '').strip()
    page = request.args.get('page', 1, type=int)
    user_id = str(g.current_user['_id'])
    questions = question_model.get_questions(
        crop_tags=[crop] if crop else None,
        disease_tags=[disease] if disease else None,
        author_id=user_id if filter_key == 'my_questions' else '',
        answered_by=user_id if filter_key == 'answered_by_me' else '',
        page=page,
    )
    return success_response({
        'questions': [question_model.serialize_question(q) for q in questions],
        'page': page,
    })


@forum_bp.route('/api/forum/questions', methods=['POST'])
@require_auth
def ask_question():
    """Post a new Q&A question.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          required: [title, body]
          properties:
            title:
              type: string
            body:
              type: string
            crop_tags:
              type: array
              items:
                type: string
            disease_tags:
              type: array
              items:
                type: string
    responses:
      201:
        description: Question posted
    """
    data = request.get_json(silent=True) or {}
    title = (data.get('title') or '').strip()
    body = (data.get('body') or '').strip()
    if not title or not body:
        return error_response('title and body are required', 400)

    title = html.escape(title)
    body = html.escape(body)
    user_id = str(g.current_user['_id'])
    question = question_model.create_question(
        author_id=user_id,
        title=title,
        body=body,
        crop_tags=data.get('crop_tags') or [],
        disease_tags=data.get('disease_tags') or [],
    )
    return success_response(
        {'question': question_model.serialize_question(question)},
        'Question posted',
        201,
    )


@forum_bp.route('/api/forum/questions/<question_id>', methods=['GET'])
@require_auth
def get_question(question_id):
    """Get a question and all its answers.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    responses:
      200:
        description: Question with sorted answers
    """
    if not is_valid_object_id(question_id):
        return error_response('Invalid question ID', 400)
    question = question_model.get_question_by_id(question_id)
    if not question:
        return error_response('Question not found', 404)
    answers = question_model.get_answers(question_id)
    return success_response({
        'question': question_model.serialize_question(question),
        'answers': [question_model.serialize_answer(a) for a in answers],
    })


@forum_bp.route('/api/forum/questions/<question_id>/answers', methods=['POST'])
@require_auth
def post_answer(question_id):
    """Post an answer to a question.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          required: [body]
          properties:
            body:
              type: string
    responses:
      201:
        description: Answer posted
    """
    if not is_valid_object_id(question_id):
        return error_response('Invalid question ID', 400)
    data = request.get_json(silent=True) or {}
    body = (data.get('body') or '').strip()
    if not body:
        return error_response('Answer body is required', 400)
    body = html.escape(body)
    question = question_model.get_question_by_id(question_id)
    if not question:
        return error_response('Question not found', 404)

    user_id = str(g.current_user['_id'])
    answer = question_model.create_answer(question_id, user_id, body)
    _notify_forum_interaction(
        recipient_id=str(question.get('author_id', '')),
        actor_id=user_id,
        title_en='New answer',
        message_en='Someone answered your question.',
        title_ar='إجابة جديدة',
        message_ar='قام أحد المستخدمين بالإجابة على سؤالك.',
        metadata={'question_id': question_id, 'answer_id': str(answer.get('_id', ''))},
    )
    return success_response(
        {'answer': question_model.serialize_answer(answer)},
        'Answer posted',
        201,
    )


@forum_bp.route('/api/forum/answers/<answer_id>/accept', methods=['PATCH'])
@require_auth
def accept_answer(answer_id):
    """Mark an answer as accepted (question author only).
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          required: [question_id]
          properties:
            question_id:
              type: string
    responses:
      200:
        description: Answer accepted
      403:
        description: Not the question author
    """
    if not is_valid_object_id(answer_id):
        return error_response('Invalid answer ID', 400)
    data = request.get_json(silent=True) or {}
    question_id = (data.get('question_id') or '').strip()
    if not question_id or not is_valid_object_id(question_id):
        return error_response('question_id is required', 400)

    user_id = str(g.current_user['_id'])
    ok = question_model.accept_answer(answer_id, question_id, user_id)
    if not ok:
        return error_response('Not authorised or question not found', 403)
    return success_response(message='Answer marked as accepted')
