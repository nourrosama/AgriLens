"""
Subscription controller — plan status, quota, and plan management.
"""
from flask import Blueprint, g, request
from app.middleware.auth_middleware import require_auth
from app.services.subscription_service import (
    get_plan, get_scan_quota, PLAN_FEATURES, PLAN_HIERARCHY
)
from app.models import user_model
from app.views.responses import success_response, error_response

subscription_bp = Blueprint('subscription', __name__)

VALID_PLANS = ('free', 'premium', 'professional')

PLAN_INFO = {
    'free': {
        'name': 'Free',
        'price': '$0/month',
        'highlights': [
            'Disease detection from image',
            'Confidence score',
            'Basic disease description',
            'Basic treatment recommendations',
            '5 scans per month',
        ],
    },
    'premium': {
        'name': 'Premium',
        'price': '$19/month',
        'highlights': [
            'Everything in Free',
            'Detailed AI disease reports',
            'Severity assessment',
            'Symptoms & causes analysis',
            'Recovery timeline',
            'Preventive measures',
            'Weather-based risk assessment',
            'Personalized recommendations',
            'Unlimited scans',
            'AI agricultural chatbot',
        ],
    },
    'professional': {
        'name': 'Professional',
        'price': '$49/month',
        'highlights': [
            'Everything in Premium',
            'PDF report generation & export',
            'Disease history tracking',
            'Farm dashboard',
            'Disease trend analytics',
            'Yield impact estimation',
            'Treatment cost estimation',
            'Farm-wide health insights',
        ],
    },
}


@subscription_bp.route('/api/subscription/status', methods=['GET'])
@require_auth
def get_status():
    """Return the current user's plan, quota, and feature flags.
    ---
    tags:
      - Subscription
    security:
      - Bearer: []
    responses:
      200:
        description: Subscription status
    """
    user = g.current_user
    plan = get_plan(user)
    quota = get_scan_quota(user)
    features = PLAN_FEATURES.get(plan, PLAN_FEATURES['free'])

    return success_response({
        'plan':     plan,
        'plan_info': PLAN_INFO.get(plan, {}),
        'quota':    quota,
        'features': features,
    })


@subscription_bp.route('/api/subscription/plans', methods=['GET'])
def list_plans():
    """Return all available plans and their features (public endpoint).
    ---
    tags:
      - Subscription
    responses:
      200:
        description: List of plans
    """
    plans = []
    for plan_id in ('free', 'premium', 'professional'):
        plans.append({
            'id':       plan_id,
            'info':     PLAN_INFO[plan_id],
            'features': PLAN_FEATURES[plan_id],
        })
    return success_response({'plans': plans})


@subscription_bp.route('/api/subscription/upgrade', methods=['POST'])
@require_auth
def upgrade_plan():
    """Change the current user's subscription plan.
    ---
    tags:
      - Subscription
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - plan
          properties:
            plan:
              type: string
              enum: [free, premium, professional]
    responses:
      200:
        description: Plan updated
      400:
        description: Invalid plan
    """
    data = request.get_json(silent=True) or {}
    new_plan = (data.get('plan') or '').strip().lower()

    if new_plan not in VALID_PLANS:
        return error_response(f'Invalid plan. Choose from: {", ".join(VALID_PLANS)}', 400)

    user = g.current_user
    current_plan = get_plan(user)

    if new_plan == current_plan:
        return error_response(f'You are already on the {current_plan} plan.', 400)

    user_model.update_user(str(user['_id']), {'plan': new_plan})

    action = 'upgraded' if PLAN_HIERARCHY[new_plan] > PLAN_HIERARCHY[current_plan] else 'downgraded'
    return success_response(
        {'plan': new_plan, 'previous_plan': current_plan},
        f'Plan {action} to {PLAN_INFO[new_plan]["name"]} successfully.',
    )
