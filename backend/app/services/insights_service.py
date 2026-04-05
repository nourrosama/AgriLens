"""
Derived dashboard, weather, forecast, and chatbot helpers for the mobile app.
"""
from datetime import datetime, timedelta, timezone
import hashlib
import logging

import requests
from flask import current_app

from app.models import farm_model, notification_model, scan_model

logger = logging.getLogger(__name__)


def risk_level_from_score(score: float) -> str:
    """Map a numeric risk score to a labeled level."""
    if score >= 0.8:
        return 'critical'
    if score >= 0.6:
        return 'high'
    if score >= 0.35:
        return 'medium'
    return 'low'


def _best_location(farms: list[dict]) -> dict:
    for farm in farms:
        location = farm.get('location') or {}
        if _extract_coordinates(location):
            return location
        for field in farm.get('fields', []):
            field_location = field.get('location') or {}
            if _extract_coordinates(field_location):
                return field_location
    return {}


def _extract_coordinates(location: dict | None) -> tuple[float, float] | None:
    if not isinstance(location, dict):
        return None
    lat = location.get('lat', location.get('latitude'))
    lng = location.get('lng', location.get('lon', location.get('longitude')))
    if lat is None or lng is None:
        return None
    try:
        return float(lat), float(lng)
    except (TypeError, ValueError):
        return None


def _normalize_condition(value: str) -> str:
    mapping = {
        'clear': 'Sunny',
        'clouds': 'Cloudy',
        'mist': 'Cloudy',
        'fog': 'Cloudy',
        'haze': 'Cloudy',
        'drizzle': 'Rainy',
        'rain': 'Rainy',
        'thunderstorm': 'Rainy',
    }
    return mapping.get((value or '').strip().lower(), 'Partly Cloudy')


def _fallback_weather(location: dict | None = None, days: int = 7) -> dict:
    """Return deterministic weather data when the live API is unavailable."""
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
        'source': 'fallback',
    }


def _parse_openweather(payload: dict, days: int) -> dict:
    current = payload.get('current') or {}
    daily = payload.get('daily') or []
    forecast = []

    for index, entry in enumerate(daily[:days]):
        temp_source = entry.get('temp')
        if isinstance(temp_source, dict):
            temperature = temp_source.get('day', current.get('temp', 0))
        else:
            temperature = temp_source if temp_source is not None else current.get('temp', 0)
        weather_items = entry.get('weather') or current.get('weather') or [{}]
        condition = _normalize_condition(weather_items[0].get('main', 'Clouds'))
        wind_speed = entry.get('wind_speed', current.get('wind_speed', 0))
        forecast.append({
            'day': datetime.fromtimestamp(
                entry.get('dt', int(datetime.now(timezone.utc).timestamp())),
                tz=timezone.utc,
            ).strftime('%a'),
            'temperature': round(float(temperature)),
            'humidity': round(float(entry.get('humidity', current.get('humidity', 0)))),
            'wind_kmh': round(float(wind_speed) * 3.6),
            'condition': condition,
        })

    if not forecast:
        condition = _normalize_condition(
            ((current.get('weather') or [{}])[0]).get('main', 'Clouds')
        )
        forecast = [{
            'day': datetime.now(timezone.utc).strftime('%a'),
            'temperature': round(float(current.get('temp', 0))),
            'humidity': round(float(current.get('humidity', 0))),
            'wind_kmh': round(float(current.get('wind_speed', 0)) * 3.6),
            'condition': condition,
        }]

    return {
        'temperature': forecast[0]['temperature'],
        'humidity': forecast[0]['humidity'],
        'wind_kmh': forecast[0]['wind_kmh'],
        'condition': forecast[0]['condition'],
        'forecast': forecast,
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'source': 'openweather',
    }


def build_weather(location: dict | None = None, days: int = 7) -> dict:
    """Return normalized weather data, preferring OpenWeather when configured."""
    coords = _extract_coordinates(location)
    api_key = current_app.config.get('OPENWEATHER_API_KEY', '')
    if not coords or not api_key:
        return _fallback_weather(location, days)

    lat, lng = coords
    params = {
        'lat': lat,
        'lon': lng,
        'appid': api_key,
        'units': 'metric',
        'exclude': 'minutely,hourly,alerts',
    }
    urls = []
    primary = current_app.config.get('OPENWEATHER_API_URL', '')
    fallback = current_app.config.get('OPENWEATHER_FALLBACK_URL', '')
    if primary:
        urls.append(primary)
    if fallback and fallback not in urls:
        urls.append(fallback)

    for url in urls:
        try:
            response = requests.get(url, params=params, timeout=10)
            if response.ok:
                return _parse_openweather(response.json(), days)
            logger.warning('OpenWeather request failed (%s): %s', response.status_code, response.text)
        except requests.RequestException as exc:
            logger.warning('OpenWeather request error: %s', exc)

    return _fallback_weather(location, days)


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
            'source': weather.get('source', 'fallback'),
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
    weather = build_weather(_best_location(farms))
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
    
    # Define knowledge base for various topics
    knowledge_base = {
        'disease': {
            'tomato': 'Tomatoes are commonly affected by:\n• Early Blight: Brown spots with concentric rings on lower leaves\n• Late Blight: Water-soaked spots and white mold on leaf undersides\n• Leaf Mold: Yellow patches on upper leaf, gray mold below\n• Viral Infections: Mosaic patterns, yellowing, stunted growth\n\nPrevention: Keep humidity controlled, improve airflow, avoid wet foliage, remove infected leaves quickly.',
            'paddy': 'Paddy (Rice) is affected by:\n• Blast: Gray lesions on leaves and stems\n• Brown Spot: Reddish-brown spots on leaves\n• Sheath Blight: Water-soaked spots on leaf sheaths\n• Bacterial Leaf Blight: Yellow-white stripes\n\nPrevention: Use resistant varieties, proper water management, balanced fertilization, and timely fungicide application.',
            'wheat': 'Wheat diseases include:\n• Leaf Rust: Orange pustules on leaves\n• Stripe Rust: Yellow pustules in stripes\n• Powdery Mildew: White powder on leaves\n• Septoria: Brown spots with dark rings\n\nPrevention: Crop rotation, resistant varieties, fungicide spraying at boot stage.',
            'potato': 'Potato diseases:\n• Late Blight: Water-soaked spots, white mold, rapid spread\n• Early Blight: Concentric rings on leaves\n• Scab: Raised corky lesions on tubers\n• Verticillium Wilt: Yellow/brown wilting from bottom\n\nPrevention: Proper spacing, fungicide application, remove volunteers, use quality seed.',
        },
        'prevention': {
            'blight': 'To reduce blight risk:\n1. Improve airflow: Proper spacing between plants\n2. Avoid wet foliage at night: Water early morning, use drip irrigation\n3. Remove infected leaves quickly to prevent spread\n4. Use fungicides: Apply preventively in humid conditions\n5. Monitor weather: Use forecast to plan fungicide timing',
            'disease': 'General disease prevention:\n1. Scout your fields regularly for early detection\n2. Use the AgriLens scanner for quick disease identification\n3. Practice crop rotation (3+ year rotation)\n4. Remove crop residues from previous season\n5. Maintain proper plant spacing for airflow\n6. Follow integrated pest management (IPM) practices',
            'pest': 'Pest prevention strategies:\n1. Use insect scouts/traps to monitor populations\n2. Introduce natural predators\n3. Remove weeds that harbor pests\n4. Time plantings to avoid pest peaks\n5. Use recommended insecticides when threshold is reached',
        },
        'fertilizer': {
            'nitrogen': 'Nitrogen tips:\n• Promotes leaf and stem growth\n• Use at vegetative stage (V4-V10)\n• Split applications for better uptake\n• Too much increases disease susceptibility\n• Typical: 100-150 kg/ha for cereals, 150-200 for vegetables',
            'phosphorus': 'Phosphorus benefits:\n• Promotes root development\n• Important for flowering and grain fill\n• Apply at planting or early season\n• Typical: 40-80 kg/ha P2O5',
            'potassium': 'Potassium improves:\n• Disease resistance and plant strength\n• Fruit quality and shelf life\n• Stress tolerance (drought, cold)\n• Typical: 60-150 kg/ha K2O depending on crop',
            'balanced': 'For most crops, use NPK ratios:\n• Leafy vegetables: 20-10-10\n• Fruiting crops: 10-10-20\n• Root crops: 15-20-20\n• Cereals: 15-10-10\nAdjust based on soil test results.',
        },
        'watering': {
            'irrigation': 'Water management tips:\n1. Water early morning (5-8 AM) to minimize disease\n2. Use drip irrigation when possible\n3. Avoid wetting foliage late afternoon\n4. Monitor soil moisture: 60-70% field capacity ideal\n5. Adjust for rainfall and weather forecasts\n6. Young plants need more frequent, lighter watering',
            'schedule': 'General watering schedule:\n• Vegetables: 25-50 mm/week (depends on rainfall)\n• Small grains: 1-2 irrigation cycles\n• Paddy: 5-7 cm water depth maintained\n• Potatoes: 400-600 mm total season\n• Check soil before each irrigation',
            'drainage': 'Drainage importance:\n• Poor drainage causes root diseases\n• Leads to nutrient deficiencies\n• Increases pest and disease pressure\n• Ensure fields slope for water runoff\n• Consider raised beds in wet areas',
        },
    }
    
    # Check for specific topics and keywords
    reply = None
    
    # Disease-related queries
    if any(word in normalized for word in ['disease', 'blight', 'rot', 'wilt', 'spot', 'مرض', 'آفة', 'لفحة']):
        if 'tomato' in normalized or 'طماطم' in normalized:
            reply = knowledge_base['disease'].get('tomato')
        elif 'paddy' in normalized or 'rice' in normalized or 'أرز' in normalized:
            reply = knowledge_base['disease'].get('paddy')
        elif 'wheat' in normalized or 'قمح' in normalized:
            reply = knowledge_base['disease'].get('wheat')
        elif 'potato' in normalized or 'بطاطس' in normalized:
            reply = knowledge_base['disease'].get('potato')
        elif 'blight' in normalized or 'لفحة' in normalized:
            reply = knowledge_base['prevention'].get('blight')
        else:
            reply = 'Tell me which crop you\'re asking about (tomato, paddy, wheat, potato) so I can provide specific disease information.'
    
    # Prevention-related queries
    elif any(word in normalized for word in ['prevent', 'prevent', 'control', 'manage', 'protection', 'الوقاية', 'منع']):
        if 'blight' in normalized or 'لفحة' in normalized:
            reply = knowledge_base['prevention'].get('blight')
        elif 'pest' in normalized or 'آفة' in normalized:
            reply = knowledge_base['prevention'].get('pest')
        else:
            reply = knowledge_base['prevention'].get('disease')
    
    # Fertilizer-related queries
    elif any(word in normalized for word in ['fertiliz', 'nutrient', 'npk', 'nitrogen', 'phosphorus', 'potassium', 'سماد', 'غذاء']):
        if 'nitrogen' in normalized or 'n ' in normalized or 'نيتروجين' in normalized:
            reply = knowledge_base['fertilizer'].get('nitrogen')
        elif 'phosphorus' in normalized or 'p ' in normalized or 'فسفور' in normalized:
            reply = knowledge_base['fertilizer'].get('phosphorus')
        elif 'potassium' in normalized or 'k ' in normalized or 'بوتاسيوم' in normalized:
            reply = knowledge_base['fertilizer'].get('potassium')
        elif 'balance' in normalized or 'npk' in normalized:
            reply = knowledge_base['fertilizer'].get('balanced')
        else:
            reply = 'Ask about nitrogen (N), phosphorus (P), potassium (K), or balanced fertilizer recommendations.'
    
    # Watering-related queries
    elif any(word in normalized for word in ['water', 'irrig', 'drain', 'moisture', 'ري', 'سقاية', 'الماء']):
        if 'schedule' in normalized or 'timer' in normalized or 'when' in normalized or 'جدول' in normalized:
            reply = knowledge_base['watering'].get('schedule')
        elif 'drain' in normalized or 'تصريف' in normalized:
            reply = knowledge_base['watering'].get('drainage')
        else:
            reply = knowledge_base['watering'].get('irrigation')
    
    # Default response if no specific topic matched
    if not reply:
        reply = 'I can help you with:\n• Disease identification and prevention\n• Fertilizer and nutrient management\n• Watering and irrigation scheduling\n• Pest and disease control tips\n• Crop-specific care advice\n\nTry asking about a specific crop (tomato, wheat, paddy, potato) or management topic!'
    
    return {
        'reply': reply,
        'suggestions': suggestions,
        'generated_at': datetime.now(timezone.utc).isoformat(),
    }
