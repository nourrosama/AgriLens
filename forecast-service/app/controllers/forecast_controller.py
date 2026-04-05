"""
Forecasting Controller.
Returns deterministic demo forecasts until the production model is integrated.
"""
import hashlib
from flask import Blueprint, request, jsonify

forecast_bp = Blueprint('forecast', __name__)


@forecast_bp.route('/api/forecast', methods=['POST'])
def get_forecast():
    """
    Returns disease spread forecast for a given farm/field.

    Request JSON: { "farm_id": str, "days_ahead": int }
    Response: {
        "risk_score": float (0-1),
        "risk_level": str,
        "forecast": [ { "day": int, "risk": float } ],
        "spread_probability": float
    }
    """
    data = request.get_json() or {}
    days_ahead = data.get('days_ahead', 7)

    seed_input = f"{data.get('farm_id', '')}:{data.get('field_id', '')}:{days_ahead}:{data.get('disease_count', 0)}"
    digest = int(hashlib.md5(seed_input.encode('utf-8')).hexdigest()[:8], 16)
    risk_score = round(0.18 + ((digest % 63) / 100), 3)

    risk_levels = {
        (0.0, 0.3): 'low',
        (0.3, 0.6): 'medium',
        (0.6, 0.8): 'high',
        (0.8, 1.0): 'critical',
    }
    risk_level = 'medium'
    for (low, high), level in risk_levels.items():
        if low <= risk_score < high:
            risk_level = level
            break

    forecast = []
    for i in range(days_ahead):
        daily_risk = round(
            min(0.98, max(0.08, risk_score + (((digest >> (i % 8)) % 9) - 4) / 100)),
            3,
        )
        forecast.append({'day': i + 1, 'risk': daily_risk})

    return jsonify({
        'risk_score': risk_score,
        'risk_level': risk_level,
        'forecast': forecast,
        'spread_probability': round(min(0.95, risk_score * 0.8 + 0.06), 3),
    }), 200
