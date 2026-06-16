"""
Subscription service — plan feature gating and scan quota management.
Checks the user's plan and enforces limits before premium/professional features are served.
"""
from datetime import datetime, timezone
from bson import ObjectId
from app.models.db import scans_col

# ── Plan hierarchy ────────────────────────────────────────────────────────────
PLAN_HIERARCHY = {'free': 0, 'premium': 1, 'professional': 2}
FREE_SCAN_LIMIT = 5

# ── Feature matrix ────────────────────────────────────────────────────────────
PLAN_FEATURES = {
    'free': {
        'scan_limit':         FREE_SCAN_LIMIT,
        'unlimited_scans':    False,
        'detailed_report':    False,
        'severity':           False,
        'symptoms_causes':    False,
        'recovery_timeline':  False,
        'preventive_measures': False,
        'weather_risk':       False,
        'personalized_recs':  False,
        'chatbot':            False,
        'pdf_reports':        False,
        'disease_history':    False,
        'farm_dashboard':     False,
        'trend_analytics':    False,
        'yield_impact':       False,
        'cost_estimation':    False,
        'farm_insights':      False,
        'articles_depth':     'basic',   # truncated body
    },
    'premium': {
        'scan_limit':         None,
        'unlimited_scans':    True,
        'detailed_report':    True,
        'severity':           True,
        'symptoms_causes':    True,
        'recovery_timeline':  True,
        'preventive_measures': True,
        'weather_risk':       True,
        'personalized_recs':  True,
        'chatbot':            True,
        'pdf_reports':        False,
        'disease_history':    False,
        'farm_dashboard':     False,
        'trend_analytics':    False,
        'yield_impact':       False,
        'cost_estimation':    False,
        'farm_insights':      False,
        'articles_depth':     'detailed',  # full body
    },
    'professional': {
        'scan_limit':         None,
        'unlimited_scans':    True,
        'detailed_report':    True,
        'severity':           True,
        'symptoms_causes':    True,
        'recovery_timeline':  True,
        'preventive_measures': True,
        'weather_risk':       True,
        'personalized_recs':  True,
        'chatbot':            True,
        'pdf_reports':        True,
        'disease_history':    True,
        'farm_dashboard':     True,
        'trend_analytics':    True,
        'yield_impact':       True,
        'cost_estimation':    True,
        'farm_insights':      True,
        'articles_depth':     'full',  # full body + downloadable
    },
}

UPGRADE_MESSAGES = {
    'premium': 'This feature requires a Premium plan. Upgrade to unlock detailed reports, severity analysis, AI chatbot, and unlimited scans.',
    'professional': 'This feature requires a Professional plan. Upgrade to unlock PDF reports, farm dashboard, disease tracking, and yield impact analysis.',
}


# ── Public helpers ────────────────────────────────────────────────────────────

def get_plan(user: dict) -> str:
    return user.get('plan', 'free')


def has_feature(user: dict, feature: str) -> bool:
    plan = get_plan(user)
    return PLAN_FEATURES.get(plan, PLAN_FEATURES['free']).get(feature, False)


def plan_meets_minimum(user: dict, required_plan: str) -> bool:
    user_level = PLAN_HIERARCHY.get(get_plan(user), 0)
    required_level = PLAN_HIERARCHY.get(required_plan, 0)
    return user_level >= required_level


def get_monthly_scan_count(user_id: str) -> int:
    now = datetime.now(timezone.utc)
    start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    return scans_col().count_documents({
        'user_id': ObjectId(user_id),
        'created_at': {'$gte': start_of_month},
    })


def can_scan(user: dict) -> tuple[bool, str]:
    """Returns (allowed, error_message). error_message is '' when allowed."""
    if has_feature(user, 'unlimited_scans'):
        return True, ''
    used = get_monthly_scan_count(str(user['_id']))
    if used >= FREE_SCAN_LIMIT:
        return False, (
            f'You have used all {FREE_SCAN_LIMIT} free scans this month. '
            'Upgrade to Premium for unlimited scans.'
        )
    return True, ''


def get_scan_quota(user: dict) -> dict:
    """Return quota info for the current user."""
    plan = get_plan(user)
    used = get_monthly_scan_count(str(user['_id']))
    if PLAN_FEATURES.get(plan, {}).get('unlimited_scans'):
        return {'used': used, 'limit': None, 'remaining': None, 'unlimited': True}
    return {
        'used': used,
        'limit': FREE_SCAN_LIMIT,
        'remaining': max(0, FREE_SCAN_LIMIT - used),
        'unlimited': False,
    }


def get_articles_depth(user: dict) -> str:
    """Return 'basic' | 'detailed' | 'full' based on plan."""
    return PLAN_FEATURES.get(get_plan(user), PLAN_FEATURES['free']).get('articles_depth', 'basic')


def build_scan_response(detection: dict, report: dict | None, user: dict) -> dict:
    """
    Build a plan-gated scan result dict.

    Everyone gets:   disease_name, confidence_score, is_healthy, basic_summary, basic_treatment
    Premium+  adds:  severity, symptoms, causes, detailed treatment, prevention,
                     recovery_timeline, urgency, full AI report
    Professional+ adds: yield_impact, cost_estimation, farm_insights
    """
    plan = get_plan(user)
    r = report or {}

    # ── Tier 0 — Free ────────────────────────────────────────────────────────
    basic_treatment = []
    if r.get('immediate_actions'):
        basic_treatment = r['immediate_actions'][:2]
    elif detection.get('recommendation'):
        basic_treatment = [detection['recommendation']]

    response = {
        'disease_name':     detection.get('disease', 'Unknown'),
        'scientific_name':  detection.get('scientific_name', ''),
        'confidence_score': round(detection.get('confidence', 0) * 100, 1),
        'is_healthy':       detection.get('is_healthy', False),
        'basic_summary':    (r.get('what_is_it') or detection.get('recommendation', ''))[:300],
        'basic_treatment':  basic_treatment,
        'plan':             plan,
    }

    # ── Tier 1 — Premium ────────────────────────────────────────────────────
    if plan in ('premium', 'professional'):
        response['severity']            = detection.get('severity', 'unknown')
        response['urgency']             = r.get('urgency_label', '')
        response['urgency_level']       = r.get('urgency_level', '')
        response['symptoms']            = r.get('symptoms', [])
        response['causes']              = {
            'how_spreads':          r.get('how_spreads', ''),
            'favorable_conditions': r.get('favorable_conditions', ''),
            'pathogen_type':        r.get('pathogen_type', ''),
        }
        response['treatment_plan']      = {
            'immediate_actions': r.get('immediate_actions', []),
            'chemical':          r.get('treatment_chemical', []),
            'organic':           r.get('treatment_organic', []),
            'when_to_apply':     r.get('when_to_apply', ''),
        }
        response['preventive_measures'] = r.get('prevention', [])
        response['recovery_timeline']   = (
            'Re-scan recommended within 2 weeks to confirm treatment response.'
            if r.get('scan_again_recommended')
            else 'Monitor weekly and re-scan if symptoms persist beyond 3 weeks.'
        )
        response['look_alike_diseases'] = r.get('look_alike_diseases', [])
        response['confidence_note']     = r.get('confidence_note', '')
        response['full_report']         = r  # full AI report for Premium+

    # ── Tier 2 — Professional ────────────────────────────────────────────────
    if plan == 'professional':
        response['yield_impact']    = r.get('estimated_impact', 'Data unavailable — consult agronomist.')
        response['cost_estimation'] = (
            'Estimated chemical treatment: $30–80/acre. '
            'Organic alternatives: $15–40/acre. '
            'Consult local supplier for exact pricing.'
        )
        response['farm_insights']   = (
            f"Disease detected: {detection.get('disease', 'Unknown')}. "
            'Scout adjacent fields and monitor for spread. '
            'Consider weather-based spray scheduling.'
        )
        response['economic_threshold'] = r.get('economic_threshold', '')

    # ── Upgrade hints for lower tiers ───────────────────────────────────────
    if plan == 'free':
        response['upgrade_hint'] = {
            'title': 'Unlock Detailed Analysis',
            'message': 'Upgrade to Premium to see severity assessment, symptoms, treatment plans, and AI recommendations.',
            'features': [
                'Disease severity (Low / Medium / High)',
                'Symptoms & root causes',
                'Step-by-step treatment plan',
                'Preventive measures',
                'Recovery timeline',
                'AI agricultural chatbot',
                'Unlimited scans',
            ],
        }

    return response
