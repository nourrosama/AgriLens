"""
AI-powered disease report service using Groq API.
Generates a structured, farmer-friendly JSON report for any detected disease.
"""
import json
import logging
import os
import re

from groq import Groq

logger = logging.getLogger(__name__)

_client = None


def _get_client():
    global _client
    if _client is None:
        api_key = os.getenv('GROQ_API_KEY', '')
        if not api_key:
            logger.warning('GROQ_API_KEY not set — disease reports will use fallback')
            return None
        _client = Groq(api_key=api_key)
    return _client


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

def generate_disease_report(
    disease: str,
    crop_type: str,
    severity: str,
    confidence: float,
    scientific_name: str = '',
    lang: str = 'en',
) -> dict:
    """Return a structured disease report dict.

    Keys returned:
        what_is_it, confidence_note, urgency_label, urgency_level,
        estimated_impact, how_spreads, symptoms (list),
        immediate_actions (list), treatment_chemical (list),
        treatment_organic (list), prevention (list),
        scan_again_recommended (bool)
    """
    is_arabic = lang == 'ar'
    confidence_pct = round(confidence * 100)

    prompt = _build_prompt(
        disease, crop_type, severity, confidence_pct, scientific_name, is_arabic
    )
    client = _get_client()
    if client is None:
        return _fallback(disease, severity, confidence_pct, is_arabic)

    try:
        completion = client.chat.completions.create(
            model='llama-3.3-70b-versatile',
            messages=[
                {
                    'role': 'system',
                    'content': (
                        'أنت خبير زراعي. أعد دائماً JSON صحيحاً فقط بدون أي نص إضافي.'
                        if is_arabic else
                        'You are an agricultural expert. '
                        'Return ONLY a valid JSON object — no markdown fences, no extra text.'
                    ),
                },
                {'role': 'user', 'content': prompt},
            ],
            max_tokens=1000,
            temperature=0.3,
        )
        raw = completion.choices[0].message.content.strip()
        # Strip markdown code fences if the model adds them
        raw = re.sub(r'^```(?:json)?\s*', '', raw, flags=re.IGNORECASE)
        raw = re.sub(r'\s*```$', '', raw)
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        logger.warning('Disease report JSON parse error: %s', exc)
        return _fallback(disease, severity, confidence_pct, is_arabic)
    except Exception as exc:
        logger.error('Disease report Groq error: %s', exc)
        return _fallback(disease, severity, confidence_pct, is_arabic)


# ─────────────────────────────────────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────────────────────────────────────

def _build_prompt(
    disease, crop_type, severity, confidence_pct, scientific_name, is_arabic
) -> str:
    sci = f' ({scientific_name})' if scientific_name else ''
    if is_arabic:
        return f"""
تم اكتشاف مرض "{disease}"{sci} في محصول {crop_type}.
نسبة الثقة: {confidence_pct}٪   |   درجة الخطورة: {severity}

أنشئ تقريراً زراعياً منظماً للمزارع. أعد JSON صحيحاً فقط بهذه المفاتيح بالضبط:
{{
  "what_is_it": "شرح واضح للمرض في جملتين أو ثلاث",
  "confidence_note": "تقييم صادق لنسبة الثقة {confidence_pct}٪ — هل هي كافية للتصرف؟",
  "urgency_label": "تصرف فوراً (24-48 ساعة)" أو "تصرف هذا الأسبوع" أو "راقب الوضع",
  "urgency_level": "high" أو "medium" أو "low",
  "estimated_impact": "تقدير نسبة الخسائر إذا لم يُعالج",
  "how_spreads": "كيف ينتشر المرض (الرياح والماء والأدوات...)",
  "symptoms": ["3-4 أعراض مرئية يستطيع المزارع التحقق منها"],
  "immediate_actions": ["2-3 إجراءات فورية اليوم"],
  "treatment_chemical": ["1-2 مبيدات فطرية أو بكتيرية آمنة وشائعة"],
  "treatment_organic": ["1-2 بدائل عضوية طبيعية"],
  "prevention": ["2-3 نصائح عملية للوقاية"],
  "scan_again_recommended": true أو false
}}
"""
    return f"""
A crop disease AI identified "{disease}"{sci} in a {crop_type} crop.
Confidence: {confidence_pct}%  |  Severity: {severity}

Generate a structured farmer-decision report. Return ONLY valid JSON with exactly these keys:
{{
  "what_is_it": "2-3 sentence plain-English explanation of the disease",
  "confidence_note": "honest assessment — is {confidence_pct}% enough to act or should they verify?",
  "urgency_label": "Immediate action (24-48h)" or "Act this week" or "Monitor closely",
  "urgency_level": "high" or "medium" or "low",
  "estimated_impact": "% crop loss estimate if untreated",
  "how_spreads": "brief explanation of spread vectors (wind, water, tools…)",
  "symptoms": ["3-4 visible symptoms the farmer can verify on their plants"],
  "immediate_actions": ["2-3 concrete actions to take today"],
  "treatment_chemical": ["1-2 safe and common fungicide/bactericide examples"],
  "treatment_organic": ["1-2 organic/natural alternatives"],
  "prevention": ["2-3 practical prevention tips"],
  "scan_again_recommended": true or false
}}
"""


def _fallback(disease: str, severity: str, confidence_pct: int, is_arabic: bool) -> dict:
    """Minimal fallback when Groq is unavailable."""
    urgency_map = {'high': 'high', 'medium': 'medium'}
    level = urgency_map.get(severity, 'low')

    if is_arabic:
        urgency_labels = {'high': 'تصرف فوراً (24-48 ساعة)', 'medium': 'تصرف هذا الأسبوع', 'low': 'راقب الوضع'}
        return {
            'what_is_it': f'{disease} مرض نباتي يصيب المحاصيل ويحتاج إلى متابعة دقيقة.',
            'confidence_note': f'نسبة الثقة {confidence_pct}٪. يُنصح بمراجعة خبير زراعي للتأكيد.',
            'urgency_label': urgency_labels.get(severity, 'راقب الوضع'),
            'urgency_level': level,
            'estimated_impact': 'خسائر محتملة إذا لم يُعالج في الوقت المناسب.',
            'how_spreads': 'ينتشر عبر الرياح والماء والأدوات الملوثة.',
            'symptoms': ['بقع داكنة على الأوراق', 'اصفرار الأوراق', 'ذبول الأفرع', 'نمو فطري على السطح'],
            'immediate_actions': ['أزل الأوراق المصابة فوراً', 'تجنب الري من الأعلى', 'اعزل النباتات المصابة'],
            'treatment_chemical': ['مبيدات فطرية نحاسية', 'مانكوزيب'],
            'treatment_organic': ['رش زيت النيم', 'محلول بيكربونات الصوديوم'],
            'prevention': ['تحسين التهوية بين النباتات', 'تباعد النباتات', 'تجنب الري المفرط'],
            'scan_again_recommended': confidence_pct < 80,
        }

    urgency_labels = {'high': 'Immediate action (24-48h)', 'medium': 'Act this week', 'low': 'Monitor closely'}
    return {
        'what_is_it': f'{disease} is a plant disease that requires prompt attention and monitoring.',
        'confidence_note': (
            f'{confidence_pct}% confidence is moderately high — still worth confirming with an agronomist.'
            if confidence_pct >= 75 else
            f'{confidence_pct}% confidence is relatively low. Strongly consider retaking the image or consulting an expert.'
        ),
        'urgency_label': urgency_labels.get(severity, 'Monitor closely'),
        'urgency_level': level,
        'estimated_impact': 'Potential significant crop losses if left untreated.',
        'how_spreads': 'Spreads via wind, water splashing, infected tools, and close plant contact.',
        'symptoms': ['Dark spots or lesions on leaves', 'Yellowing foliage', 'Wilting stems', 'Mold or powdery coating'],
        'immediate_actions': ['Remove and dispose of infected leaves', 'Avoid overhead watering', 'Isolate affected plants'],
        'treatment_chemical': ['Copper-based fungicide', 'Mancozeb or Chlorothalonil'],
        'treatment_organic': ['Neem oil spray (every 7 days)', 'Baking soda + water solution'],
        'prevention': ['Improve airflow between plants', 'Space plants properly', 'Avoid excessive irrigation'],
        'scan_again_recommended': confidence_pct < 80,
    }
