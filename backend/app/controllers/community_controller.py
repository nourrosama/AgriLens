"""
Community controller — crop-centric communities.
"""
from flask import Blueprint, g

from app.middleware.auth_middleware import require_auth
from app.models import community as community_model
from app.views.responses import error_response, success_response

community_bp = Blueprint('community', __name__)


@community_bp.route('/api/communities', methods=['GET'])
@require_auth
def list_communities():
    """List all crop communities sorted by member count.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    responses:
      200:
        description: Communities list
    """
    communities = community_model.get_all_communities()
    return success_response({
        'communities': [community_model.serialize(c) for c in communities],
    })


@community_bp.route('/api/communities/<crop_slug>', methods=['GET'])
@require_auth
def get_community(crop_slug):
    """Get details of a single crop community.
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    responses:
      200:
        description: Community detail
      404:
        description: Community not found
    """
    community = community_model.get_community(crop_slug)
    if not community:
        return error_response('Community not found', 404)
    return success_response({'community': community_model.serialize(community)})


@community_bp.route('/api/communities/<crop_slug>/join', methods=['POST'])
@require_auth
def join_community(crop_slug):
    """Join a crop community (idempotent).
    ---
    tags:
      - Forum
    security:
      - Bearer: []
    responses:
      200:
        description: Joined successfully
    """
    user_id = str(g.current_user['_id'])
    community_model.auto_subscribe(user_id, crop_slug)
    return success_response(message='Joined community')
