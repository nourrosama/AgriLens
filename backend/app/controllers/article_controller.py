"""
Article controller — public/farmer-facing endpoints.
Content depth is gated by subscription plan:
  Free         -> truncated body (first 300 chars) + upgrade prompt
  Premium      -> full body
  Professional -> full body + can_download flag
"""
from flask import Blueprint, request, g
from app.middleware.auth_middleware import require_auth
from app.models import article_model
from app.services.subscription_service import get_articles_depth, get_plan
from app.views.responses import success_response, error_response

article_bp = Blueprint('articles', __name__)

_PREVIEW_LENGTH = 300


def _apply_depth(article, depth):
    serialized = article_model.serialize(article)
    body = serialized.get('body', '')

    if depth == 'basic':
        if len(body) > _PREVIEW_LENGTH:
            serialized['body'] = body[:_PREVIEW_LENGTH].rstrip() + '…'
            serialized['body_truncated'] = True
            serialized['upgrade_prompt'] = (
                'Upgrade to Premium to read the full article, including detailed treatment guides, '
                'prevention strategies, and expert agronomic insights.'
            )
        else:
            serialized['body_truncated'] = False
        serialized['can_download'] = False
    elif depth == 'detailed':
        serialized['body_truncated'] = False
        serialized['can_download'] = False
    else:
        serialized['body_truncated'] = False
        serialized['can_download'] = True

    serialized['reader_depth'] = depth
    return serialized


@article_bp.route('/api/articles', methods=['GET'])
@require_auth
def list_articles():
    """Return published articles. Body depth is gated by subscription plan.
    ---
    tags:
      - Articles
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
      - in: query
        name: category
        type: string
        enum: [general, disease, tips, weather]
    responses:
      200:
        description: List of published articles (depth varies by plan)
    """
    page     = max(1, int(request.args.get('page', 1)))
    per_page = min(50, int(request.args.get('per_page', 20)))
    category = request.args.get('category', '').strip()

    depth    = get_articles_depth(g.current_user)
    articles = article_model.get_published_articles(page, per_page, category)
    total    = article_model.count_articles(published_only=True)

    return success_response({
        'articles':     [_apply_depth(a, depth) for a in articles],
        'total':        total,
        'page':         page,
        'pages':        -(-total // per_page),
        'reader_plan':  get_plan(g.current_user),
        'reader_depth': depth,
    })


@article_bp.route('/api/articles/<article_id>', methods=['GET'])
@require_auth
def get_article(article_id):
    """Get a single published article. Content depth depends on the reader plan.
    ---
    tags:
      - Articles
    security:
      - Bearer: []
    responses:
      200:
        description: Article detail (depth varies by plan)
      404:
        description: Not found
    """
    article = article_model.get_article_by_id(article_id)
    if not article or not article.get('published'):
        return error_response('Article not found', 404)

    depth = get_articles_depth(g.current_user)
    return success_response({'article': _apply_depth(article, depth)})
