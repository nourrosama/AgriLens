"""
Forecasting Controller (STUB)
Returns mock forecast data.
DSAI team will replace with LSTM/Prophet/ARIMA models.
"""
import random
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

    # STUB: Mock forecast
    # TODO: Replace with real LSTM/Prophet forecasting
    risk_score = round(random.uniform(0.1, 0.9), 3)

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

    forecast = [
        {'day': i + 1, 'risk': round(random.uniform(0.1, 0.9), 3)}
        for i in range(days_ahead)
    ]

    return jsonify({
        'risk_score': risk_score,
        'risk_level': risk_level,
        'forecast': forecast,
        'spread_probability': round(random.uniform(0.05, 0.7), 3),
    }), 200
