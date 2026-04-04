"""
Derived dashboard, weather, forecast, and chatbot helpers for the mobile app.
"""
from datetime import datetime, timedelta, timezone
import hashlib
from app.models import farm_model, notification_model, scan_model


def risk_level_from_score(score: float) -> str:
    """Map a numeric risk score to a labeled level."""
    if score >= 0.8:
        return 'critical'
    if score >= 0.6:
        return 'high'
    if score >= 0.35:
        return 'medium'
    return 'low'


def build_weather(location: dict = None, days: int = 7) -> dict:
    """Return a deterministic weather payload suitable for demo/mobile flows."""
    seed_source = str(location or 'agrilens-weather')
    digest = int(hashlib.md5(seed_source.encode('utf-8')).hexdigest()[:8], 16)
    base_temp = 21 + (digest % 8)
    base_humidity = 52 + (digest % 28)
    conditions = ['Sunny', 'Partly Cloudy', 'Cloudy', 'Rainy']
    forecast = []
    for index in range(days):
        temp = base_temp + ((digest >> (index % 8)) % 5) - 2
        humidity = min(95, max(35, base_humidity + ((index * 3) % 9) - 4))
        wind = 8 + ((digest >> ((index + 1) % 8)) % 10)
        condition = conditions[(digest + index) % len(conditions)]
        forecast.append({
            'day': (datetime.now(timezone.utc) + timedelta(days=index)).strftime('%a'),
            'temperature': temp,
            'humidity': humidity,
            'wind_kmh': wind,
            'condition': condition,
        })
    return {
        'temperature': forecast[0]['temperature'],
        'humidity': forecast[0]['humidity'],
        'wind_kmh': forecast[0]['wind_kmh'],
        'condition': forecast[0]['condition'],
        'forecast': forecast,
        'generated_at': datetime.now(timezone.utc).isoformat(),
    }


def compute_forecast(scans: list, weather: dict, days_ahead: int = 7) -> dict:
    """Create a derived forecast from scan history and weather."""
    severity_weights = {
        'none': 0.0,
        'low': 0.18,
        'medium': 0.38,
        'high': 0.62,
        'critical': 0.85,
    }
    risk_score = 0.12
    if scans:
        recent = scans[: min(10, len(scans))]
        weighted = []
        for scan in recent:
            det = scan.get('detection_result') or {}
            severity = det.get('severity', 'none')
            weighted.append(severity_weights.get(severity, 0.0))
        if weighted:
            risk_score += sum(weighted) / len(weighted)
    humidity_boost = max(0, weather.get('humidity', 50) - 55) / 100
    rain_boost = 0.15 if weather.get('condition') == 'Rainy' else 0.05 if weather.get('condition') == 'Cloudy' else 0
    risk_score = min(0.98, risk_score + humidity_boost + rain_boost)
    risk_level = risk_level_from_score(risk_score)
    forecast_points = []
    weather_days = weather.get('forecast', [])
    for index in range(days_ahead):
        weather_day = weather_days[index % len(weather_days)] if weather_days else weather
        daily_score = min(
            0.99,
            max(
                0.05,
                risk_score + (weather_day.get('humidity', 50) - 60) / 200 + (0.04 if weather_day.get('condition') == 'Rainy' else 0),
            ),
        )
        forecast_points.append({
            'day': weather_day.get('day', f'Day {index + 1}'),
            'risk_score': round(daily_score, 3),
            'risk_level': risk_level_from_score(daily_score),
        })
    return {
        'risk_score': round(risk_score, 3),
        'risk_level': risk_level,
        'spread_probability': round(min(0.99, risk_score * 0.82 + 0.08), 3),
        'forecast': forecast_points,
        'weather_impact': {
            'condition': weather.get('condition', 'Partly Cloudy'),
            'humidity': weather.get('humidity', 0),
            'temperature': weather.get('temperature', 0),
            'wind_kmh': weather.get('wind_kmh', 0),
        },
    }


def build_dashboard_summary(user_id: str) -> dict:
    """Return a dashboard summary payload for the mobile home screen."""
    farms = farm_model.get_farms_by_owner(user_id)
    scans = scan_model.get_scans_by_user(user_id, 1, 50)
    notifications = notification_model.list_notifications(user_id, 50)
    healthy_fields = 0
    total_fields = 0
    health_scores = []
    for farm in farms:
        for field in farm.get('fields', []):
            total_fields += 1
            score = field.get('health_score', 0) or 0
            health_scores.append(score)
            if score >= 75:
                healthy_fields += 1
    avg_health = round(sum(health_scores) / len(health_scores), 1) if health_scores else 0
    unread = sum(1 for item in notifications if not item.get('is_read'))
    latest_farm_location = farms[0].get('location', {}) if farms else {}
    weather = build_weather(latest_farm_location)
    current_risk = compute_forecast(scans, weather, 7)
    return {
        'total_farms': len(farms),
        'total_fields': total_fields,
        'healthy_fields': healthy_fields,
        'average_health_score': avg_health,
        'total_scans': len(scans),
        'active_alerts': unread,
        'current_risk': current_risk,
        'weather': weather,
    }


def build_chat_response(message: str) -> dict:
    """Generate a rule-based assistant response for the mobile chatbot."""
    normalized = (message or '').strip().lower()
    suggestions = [
        'What diseases affect tomatoes?',
        'How to prevent leaf blight?',
        'Best fertilizer for wheat?',
        'When should I water my crops?',
    ]
    if 'tomato' in normalized or 'طماطم' in normalized:
        reply = 'Tomatoes are commonly affected by early blight, late blight, and leaf spot. Scan suspicious leaves early and keep humidity under control.'
    elif 'blight' in normalized or 'لفحة' in normalized:
        reply = 'To reduce blight risk, improve airflow, avoid wet foliage at night, and remove infected leaves quickly. Forecast and humidity trends help plan prevention.'
    elif 'fertilizer' in normalized or 'سماد' in normalized:
        reply = 'Start with a balanced NPK plan and adjust by crop stage and soil test results. Excess nitrogen can increase disease susceptibility in some crops.'
    elif 'water' in normalized or 'irrig' in normalized or 'ري' in normalized:
        reply = 'Water early in the morning when possible, and avoid keeping foliage wet for long periods. Drip irrigation is preferred for disease-sensitive crops.'
    else:
        reply = 'I can help with disease detection follow-up, prevention tips, crop care basics, and how to interpret scan and forecast results.'
    return {
        'reply': reply,
        'suggestions': suggestions,
        'generated_at': datetime.now(timezone.utc).isoformat(),
    }
