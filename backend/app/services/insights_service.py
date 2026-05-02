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


def _parse_openweather_free(current_payload: dict, forecast_payload: dict, days: int) -> dict:
    current_weather = current_payload.get('weather') or [{}]
    current_main = current_payload.get('main') or {}
    current_wind = current_payload.get('wind') or {}
    grouped = {}

    for entry in forecast_payload.get('list', []):
        timestamp = entry.get('dt')
        if timestamp is None:
            continue
        day_key = datetime.fromtimestamp(timestamp, tz=timezone.utc).strftime('%Y-%m-%d')
        grouped.setdefault(day_key, []).append(entry)

    forecast = []
    for day_key, entries in list(grouped.items())[:days]:
        representative = min(
            entries,
            key=lambda item: abs(
                datetime.fromtimestamp(item.get('dt', 0), tz=timezone.utc).hour - 12
            ),
        )
        main = representative.get('main') or {}
        wind = representative.get('wind') or {}
        weather_items = representative.get('weather') or current_weather
        forecast.append({
            'day': datetime.fromisoformat(day_key).strftime('%a'),
            'temperature': round(float(main.get('temp', current_main.get('temp', 0)))),
            'humidity': round(float(main.get('humidity', current_main.get('humidity', 0)))),
            'wind_kmh': round(float(wind.get('speed', current_wind.get('speed', 0))) * 3.6),
            'condition': _normalize_condition(weather_items[0].get('main', 'Clouds')),
        })

    if not forecast:
        forecast = [{
            'day': datetime.now(timezone.utc).strftime('%a'),
            'temperature': round(float(current_main.get('temp', 0))),
            'humidity': round(float(current_main.get('humidity', 0))),
            'wind_kmh': round(float(current_wind.get('speed', 0)) * 3.6),
            'condition': _normalize_condition(current_weather[0].get('main', 'Clouds')),
        }]

    return {
        'temperature': round(float(current_main.get('temp', forecast[0]['temperature']))),
        'humidity': round(float(current_main.get('humidity', forecast[0]['humidity']))),
        'wind_kmh': round(float(current_wind.get('speed', 0)) * 3.6),
        'condition': _normalize_condition(current_weather[0].get('main', forecast[0]['condition'])),
        'forecast': forecast[:days],
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'source': 'openweather',
    }


def _build_openweather_free(lat: float, lng: float, api_key: str, days: int) -> dict | None:
    params = {
        'lat': lat,
        'lon': lng,
        'appid': api_key,
        'units': 'metric',
    }
    try:
        current = requests.get(
            'https://api.openweathermap.org/data/2.5/weather',
            params=params,
            timeout=10,
        )
        forecast = requests.get(
            'https://api.openweathermap.org/data/2.5/forecast',
            params=params,
            timeout=10,
        )
        if current.ok and forecast.ok:
            return _parse_openweather_free(current.json(), forecast.json(), days)
        logger.warning(
            'OpenWeather free endpoints failed current=%s forecast=%s',
            current.status_code,
            forecast.status_code,
        )
    except requests.RequestException as exc:
        logger.warning('OpenWeather free endpoint error: %s', exc)
    return None


def build_weather(location: dict | None = None, days: int = 7) -> dict:
    """Return normalized weather data, preferring free OpenWeather endpoints."""
    coords = _extract_coordinates(location)
    api_key = current_app.config.get('OPENWEATHER_API_KEY', '')
    if not coords or not api_key:
        return _fallback_weather(location, days)

    lat, lng = coords

    free_weather = _build_openweather_free(lat, lng, api_key, days)
    if free_weather:
        current_app.logger.info(
            'Weather provider source=%s lat=%.4f lon=%.4f forecast_days=%s',
            free_weather.get('source'),
            lat,
            lng,
            len(free_weather.get('forecast', [])),
        )
        return free_weather

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


def build_chat_response(message: str, lang: str = 'en') -> dict:
    """Generate a rule-based assistant response for the mobile chatbot."""
    normalized = (message or '').strip().lower()
    is_arabic = lang == 'ar' or any('\u0600' <= c <= '\u06ff' for c in message)

    suggestions_en = [
        'What diseases affect tomatoes?',
        'How to prevent leaf blight?',
        'Best fertilizer for wheat?',
        'When should I water my crops?',
    ]
    suggestions_ar = [
        'ما هي الأمراض التي تصيب الطماطم؟',
        'كيف أمنع لفحة الأوراق؟',
        'أفضل سماد للقمح؟',
        'متى أسقي محاصيلي؟',
    ]
    suggestions = suggestions_ar if is_arabic else suggestions_en

    knowledge_base = {
        'disease': {
            'tomato': {
                'en': 'Tomatoes are commonly affected by:\n• Early Blight: Brown spots with concentric rings\n• Late Blight: Water-soaked spots and white mold\n• Leaf Mold: Yellow patches on upper leaf\n• Viral Infections: Mosaic patterns, yellowing\n\nPrevention: Control humidity, improve airflow, remove infected leaves quickly.',
                'ar': 'الطماطم تتأثر عادةً بـ:\n• اللفحة المبكرة: بقع بنية بحلقات متحدة المركز\n• اللفحة المتأخرة: بقع مبللة وعفن أبيض\n• عفن الأوراق: بقع صفراء على الجانب العلوي\n• الإصابات الفيروسية: تبرقش وصفار وتقزم\n\nالوقاية: تحكم في الرطوبة، حسّن التهوية، أزل الأوراق المصابة فوراً.',
            },
            'paddy': {
                'en': 'Paddy (Rice) is affected by:\n• Blast: Gray lesions on leaves and stems\n• Brown Spot: Reddish-brown spots\n• Sheath Blight: Water-soaked spots on sheaths\n• Bacterial Leaf Blight: Yellow-white stripes\n\nPrevention: Use resistant varieties, proper water management.',
                'ar': 'الأرز يتأثر بـ:\n• الانفجار: آفات رمادية على الأوراق والسيقان\n• البقعة البنية: بقع بنية محمرة\n• لفحة الغمد: بقع مبللة على الأغماد\n• التبقع البكتيري: خطوط صفراء-بيضاء\n\nالوقاية: استخدم أصنافاً مقاومة، إدارة مياه جيدة.',
            },
            'wheat': {
                'en': 'Wheat diseases include:\n• Leaf Rust: Orange pustules on leaves\n• Stripe Rust: Yellow pustules in stripes\n• Powdery Mildew: White powder on leaves\n• Septoria: Brown spots with dark rings\n\nPrevention: Crop rotation, resistant varieties, fungicide at boot stage.',
                'ar': 'أمراض القمح تشمل:\n• صدأ الأوراق: بثرات برتقالية\n• الصدأ الأصفر: بثرات صفراء في خطوط\n• البياض الدقيقي: مسحوق أبيض على الأوراق\n• السبتوريا: بقع بنية بحلقات داكنة\n\nالوقاية: دورة زراعية، أصناف مقاومة، مبيد فطري.',
            },
            'potato': {
                'en': 'Potato diseases:\n• Late Blight: Water-soaked spots, white mold\n• Early Blight: Concentric rings on leaves\n• Scab: Raised corky lesions on tubers\n• Verticillium Wilt: Yellow/brown wilting\n\nPrevention: Proper spacing, fungicide, use quality seed.',
                'ar': 'أمراض البطاطس:\n• اللفحة المتأخرة: بقع مبللة وعفن أبيض\n• اللفحة المبكرة: حلقات متحدة المركز\n• الجرب: آفات فلينية على الدرنات\n• ذبول فيرتيسيليوم: ذبول أصفر/بني\n\nالوقاية: تباعد جيد، مبيد فطري، بذور عالية الجودة.',
            },
        },
        'prevention': {
            'blight': {
                'en': 'To reduce blight risk:\n1. Improve airflow with proper plant spacing\n2. Water early morning, use drip irrigation\n3. Remove infected leaves quickly\n4. Apply fungicides preventively in humid conditions\n5. Monitor weather forecasts for timing',
                'ar': 'للحد من خطر اللفحة:\n1. حسّن التهوية بالتباعد الجيد بين النباتات\n2. اسقِ في الصباح الباكر، استخدم الري بالتنقيط\n3. أزل الأوراق المصابة فوراً\n4. طبق المبيدات الفطرية وقائياً في الظروف الرطبة\n5. راقب توقعات الطقس',
            },
            'disease': {
                'en': 'General disease prevention:\n1. Scout fields regularly for early detection\n2. Use AgriLens scanner for quick identification\n3. Practice crop rotation (3+ years)\n4. Remove crop residues after harvest\n5. Maintain proper plant spacing\n6. Follow integrated pest management (IPM)',
                'ar': 'الوقاية العامة من الأمراض:\n1. افحص الحقول بانتظام للكشف المبكر\n2. استخدم ماسح AgriLens للتعرف السريع\n3. طبق دورة زراعية (3+ سنوات)\n4. أزل بقايا المحاصيل بعد الحصاد\n5. حافظ على تباعد مناسب بين النباتات\n6. اتبع الإدارة المتكاملة للآفات',
            },
            'pest': {
                'en': 'Pest prevention:\n1. Use traps to monitor populations\n2. Introduce natural predators\n3. Remove weeds that harbor pests\n4. Time plantings to avoid pest peaks\n5. Use insecticides when threshold is reached',
                'ar': 'الوقاية من الآفات:\n1. استخدم مصائد لمراقبة الأعداد\n2. أدخل المفترسات الطبيعية\n3. أزل الأعشاب التي تأوي الآفات\n4. نظّم مواعيد الزراعة لتجنب ذروة الآفات\n5. استخدم المبيدات عند الوصول للعتبة الحرجة',
            },
        },
        'fertilizer': {
            'nitrogen': {
                'en': 'Nitrogen tips:\n• Promotes leaf and stem growth\n• Apply at vegetative stage\n• Split applications for better uptake\n• Too much increases disease risk\n• Typical: 100-150 kg/ha for cereals',
                'ar': 'نصائح النيتروجين:\n• يعزز نمو الأوراق والسيقان\n• يُطبق في مرحلة النمو الخضري\n• قسّم الجرعات لامتصاص أفضل\n• الزيادة ترفع خطر الأمراض\n• النموذجي: 100-150 كجم/هكتار للحبوب',
            },
            'phosphorus': {
                'en': 'Phosphorus benefits:\n• Promotes root development\n• Important for flowering and grain fill\n• Apply at planting\n• Typical: 40-80 kg/ha P2O5',
                'ar': 'فوائد الفوسفور:\n• يعزز نمو الجذور\n• مهم للتزهير وامتلاء الحبوب\n• يُطبق عند الزراعة\n• النموذجي: 40-80 كجم/هكتار',
            },
            'potassium': {
                'en': 'Potassium improves:\n• Disease resistance and plant strength\n• Fruit quality and shelf life\n• Stress tolerance\n• Typical: 60-150 kg/ha K2O',
                'ar': 'البوتاسيوم يحسّن:\n• مقاومة الأمراض وقوة النبات\n• جودة الثمار ومدة صلاحيتها\n• تحمل الإجهاد\n• النموذجي: 60-150 كجم/هكتار',
            },
            'balanced': {
                'en': 'For most crops, use NPK ratios:\n• Leafy vegetables: 20-10-10\n• Fruiting crops: 10-10-20\n• Root crops: 15-20-20\n• Cereals: 15-10-10\nAdjust based on soil test.',
                'ar': 'لمعظم المحاصيل استخدم نسب NPK:\n• الخضار الورقية: 20-10-10\n• محاصيل الثمار: 10-10-20\n• محاصيل الجذور: 15-20-20\n• الحبوب: 15-10-10\nعدّل بناءً على تحليل التربة.',
            },
        },
        'watering': {
            'irrigation': {
                'en': 'Water management tips:\n1. Water early morning (5-8 AM)\n2. Use drip irrigation when possible\n3. Avoid wetting foliage late afternoon\n4. Keep soil moisture at 60-70% field capacity\n5. Adjust for rainfall and weather forecasts',
                'ar': 'نصائح إدارة المياه:\n1. اسقِ في الصباح الباكر (5-8 صباحاً)\n2. استخدم الري بالتنقيط قدر الإمكان\n3. تجنب ترطيب الأوراق في المساء\n4. حافظ على رطوبة التربة عند 60-70%\n5. عدّل حسب الأمطار وتوقعات الطقس',
            },
            'schedule': {
                'en': 'General watering schedule:\n• Vegetables: 25-50 mm/week\n• Small grains: 1-2 irrigation cycles\n• Paddy: 5-7 cm water depth\n• Potatoes: 400-600 mm total season',
                'ar': 'جدول الري العام:\n• الخضروات: 25-50 مم/أسبوع\n• الحبوب الصغيرة: 1-2 دورة ري\n• الأرز: عمق ماء 5-7 سم\n• البطاطس: 400-600 مم للموسم كله',
            },
            'drainage': {
                'en': 'Drainage importance:\n• Poor drainage causes root diseases\n• Leads to nutrient deficiencies\n• Ensure fields slope for water runoff\n• Consider raised beds in wet areas',
                'ar': 'أهمية الصرف:\n• ضعف الصرف يسبب أمراض الجذور\n• يؤدي إلى نقص العناصر الغذائية\n• تأكد من انحدار الحقول لتصريف المياه\n• فكر في الأسرّة المرتفعة في المناطق الرطبة',
            },
        },
    }

    def get(obj, key):
        return obj[key]['ar'] if is_arabic else obj[key]['en']

    reply = None

    if any(word in normalized for word in ['disease', 'blight', 'rot', 'wilt', 'spot', 'مرض', 'آفة', 'لفحة', 'أمراض']):
        if 'tomato' in normalized or 'طماطم' in normalized:
            reply = get(knowledge_base['disease'], 'tomato')
        elif 'paddy' in normalized or 'rice' in normalized or 'أرز' in normalized:
            reply = get(knowledge_base['disease'], 'paddy')
        elif 'wheat' in normalized or 'قمح' in normalized:
            reply = get(knowledge_base['disease'], 'wheat')
        elif 'potato' in normalized or 'بطاطس' in normalized:
            reply = get(knowledge_base['disease'], 'potato')
        elif 'blight' in normalized or 'لفحة' in normalized:
            reply = get(knowledge_base['prevention'], 'blight')
        else:
            reply = 'أخبرني عن أي محصول تسأل (طماطم، أرز، قمح، بطاطس) لأقدم معلومات محددة.' if is_arabic else 'Tell me which crop you\'re asking about (tomato, paddy, wheat, potato).'

    elif any(word in normalized for word in ['prevent', 'control', 'manage', 'protect', 'الوقاية', 'منع']):
        if 'blight' in normalized or 'لفحة' in normalized:
            reply = get(knowledge_base['prevention'], 'blight')
        elif 'pest' in normalized or 'آفة' in normalized:
            reply = get(knowledge_base['prevention'], 'pest')
        else:
            reply = get(knowledge_base['prevention'], 'disease')

    elif any(word in normalized for word in ['fertiliz', 'nutrient', 'npk', 'nitrogen', 'phosphorus', 'potassium', 'سماد', 'غذاء', 'تسميد']):
        if 'nitrogen' in normalized or 'نيتروجين' in normalized:
            reply = get(knowledge_base['fertilizer'], 'nitrogen')
        elif 'phosphorus' in normalized or 'فسفور' in normalized:
            reply = get(knowledge_base['fertilizer'], 'phosphorus')
        elif 'potassium' in normalized or 'بوتاسيوم' in normalized:
            reply = get(knowledge_base['fertilizer'], 'potassium')
        elif 'balance' in normalized or 'npk' in normalized:
            reply = get(knowledge_base['fertilizer'], 'balanced')
        else:
            reply = 'اسأل عن النيتروجين أو الفوسفور أو البوتاسيوم أو السماد المتوازن.' if is_arabic else 'Ask about nitrogen (N), phosphorus (P), potassium (K), or balanced fertilizer.'

    elif any(word in normalized for word in ['water', 'irrig', 'drain', 'moisture', 'ري', 'سقاية', 'الماء', 'تصريف']):
        if any(w in normalized for w in ['schedule', 'when', 'timer', 'جدول', 'متى']):
            reply = get(knowledge_base['watering'], 'schedule')
        elif 'drain' in normalized or 'تصريف' in normalized:
            reply = get(knowledge_base['watering'], 'drainage')
        else:
            reply = get(knowledge_base['watering'], 'irrigation')

    if not reply:
        reply = (
            'يمكنني مساعدتك في:\n• التعرف على الأمراض والوقاية منها\n• إدارة الأسمدة والعناصر الغذائية\n• جدول الري والسقاية\n• نصائح مكافحة الآفات\n• رعاية المحاصيل المحددة\n\nجرب السؤال عن محصول معين (طماطم، قمح، أرز، بطاطس)!'
            if is_arabic else
            'I can help you with:\n• Disease identification and prevention\n• Fertilizer and nutrient management\n• Watering and irrigation scheduling\n• Pest and disease control tips\n• Crop-specific care advice\n\nTry asking about a specific crop (tomato, wheat, paddy, potato)!'
        )

    return {
        'reply': reply,
        'suggestions': suggestions,
        'generated_at': datetime.now(timezone.utc).isoformat(),
    }