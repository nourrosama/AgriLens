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
            max_tokens=2000,
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

أنشئ تقريراً زراعياً تفصيلياً ومخصصاً لهذا المرض تحديداً. أعد JSON صحيحاً فقط بهذه المفاتيح بالضبط:
{{
  "what_is_it": "شرح واضح ومفصّل للمرض في 3-4 جمل يشمل طبيعة العامل الممرض وكيف يُلحق الضرر بالمحصول",
  "pathogen_type": "نوع العامل الممرض: فطري أو بكتيري أو فيروسي أو أومايسيت",
  "confidence_note": "تقييم صادق لنسبة الثقة {confidence_pct}٪ — هل هي كافية للتصرف أم يجب التحقق؟",
  "urgency_label": "تصرف فوراً (24-48 ساعة)" أو "تصرف هذا الأسبوع" أو "راقب الوضع",
  "urgency_level": "high" أو "medium" أو "low",
  "estimated_impact": "تقدير دقيق لنسبة الخسائر في المحصول إذا لم يُعالج مع ذكر المرحلة الأكثر خطورة",
  "favorable_conditions": "الظروف المناخية والبيئية التي تساعد على انتشار هذا المرض تحديداً (درجة حرارة، رطوبة، إلخ)",
  "economic_threshold": "الحد الاقتصادي للإصابة الذي يستوجب التدخل بالمبيدات",
  "how_spreads": "كيف ينتشر هذا المرض تحديداً مع ذكر المسافة والسرعة",
  "symptoms": ["5-6 أعراض مرئية دقيقة ومخصصة لهذا المرض يستطيع المزارع التحقق منها على النباتات"],
  "look_alike_diseases": ["1-2 أمراض تشبه هذا المرض في الأعراض مع ذكر الفارق التشخيصي الأساسي"],
  "immediate_actions": ["4-5 إجراءات فورية مرتبة بالأولوية يجب تنفيذها اليوم أو خلال 48 ساعة"],
  "treatment_chemical": ["2-3 مبيدات محددة بأسمائها التجارية وجرعة الاستخدام وطريقة التطبيق"],
  "treatment_organic": ["2-3 بدائل عضوية طبيعية مع طريقة التحضير والتطبيق"],
  "when_to_apply": "أفضل وقت وظروف لتطبيق العلاج (صباحاً/مساءً، درجة الحرارة، عدد مرات التطبيق)",
  "prevention": ["4-5 نصائح وقائية عملية ومحددة لمنع عودة هذا المرض"],
  "scan_again_recommended": true أو false
}}
"""
    return f"""
A crop disease AI identified "{disease}"{sci} in a {crop_type} crop.
Confidence: {confidence_pct}%  |  Severity: {severity}

Generate a detailed, disease-specific farmer decision report for THIS exact disease — not a generic template.
Return ONLY valid JSON with exactly these keys:
{{
  "what_is_it": "3-4 sentence explanation covering what the pathogen is, how it infects the plant, and the damage mechanism specific to {disease}",
  "pathogen_type": "Fungal / Bacterial / Viral / Oomycete / Nematode",
  "confidence_note": "honest assessment — is {confidence_pct}% confidence sufficient to act on, or should the farmer verify first?",
  "urgency_label": "Immediate action (24-48h)" or "Act this week" or "Monitor closely",
  "urgency_level": "high" or "medium" or "low",
  "estimated_impact": "specific % crop loss range for {disease} if untreated, mentioning which growth stage is most vulnerable",
  "favorable_conditions": "the specific temperature range, humidity, and environmental conditions that favour {disease} spread and development",
  "economic_threshold": "the infestation level at which chemical treatment becomes economically justified for {disease}",
  "how_spreads": "exactly how {disease} spreads — specific vectors (wind, rain splash, insects, tools, soil), speed, and distance",
  "symptoms": ["5-6 precise, disease-specific visible symptoms the farmer can verify — be specific to {disease}, not generic"],
  "look_alike_diseases": ["1-2 diseases that look similar to {disease} with the key distinguishing diagnostic difference"],
  "immediate_actions": ["4-5 prioritised concrete actions to take within 24-48h — specific to {disease}, not generic advice"],
  "treatment_chemical": ["2-3 specific fungicide/bactericide product names with dosage (e.g. Mancozeb 80WP at 2g/L) and application method"],
  "treatment_organic": ["2-3 organic alternatives with preparation method and application frequency"],
  "when_to_apply": "best time of day, weather conditions, and number of applications for treating {disease} effectively",
  "prevention": ["4-5 specific, practical prevention tips to stop {disease} from recurring"],
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
            'what_is_it': f'{disease} مرض نباتي يُلحق الضرر بالمحصول ويحتاج إلى متابعة وعلاج دقيقَين للحدّ من الخسائر.',
            'pathogen_type': 'فطري',
            'confidence_note': f'نسبة الثقة {confidence_pct}٪. يُنصح بمراجعة خبير زراعي للتأكيد قبل اتخاذ إجراءات مكلفة.',
            'urgency_label': urgency_labels.get(severity, 'راقب الوضع'),
            'urgency_level': level,
            'estimated_impact': 'خسائر محتملة تتراوح بين 20-40٪ في المحصول إذا لم يُعالج في الوقت المناسب.',
            'favorable_conditions': 'درجات حرارة معتدلة مع رطوبة عالية تزيد عن 80٪ تُشجّع على انتشار المرض.',
            'economic_threshold': 'عند إصابة 10٪ أو أكثر من النباتات يصبح التدخل الكيميائي مبرراً اقتصادياً.',
            'how_spreads': 'ينتشر عبر الرياح وبرذاذ الماء والأدوات الملوثة والتلامس بين النباتات المتجاورة.',
            'symptoms': [
                'بقع داكنة أو فاتحة على الأوراق بشكل غير منتظم',
                'اصفرار الأوراق يبدأ من الحواف ثم ينتشر',
                'ذبول الأفرع والبراعم الطرفية',
                'نمو فطري أو طبقة مسحوقية على سطح الأوراق',
                'تساقط مبكر للأوراق المصابة',
                'تلون الثمار أو تشوّهها في حالات الإصابة الشديدة',
            ],
            'look_alike_diseases': [
                'الندوة المتأخرة — تختلف بوجود هالة صفراء واضحة حول البقع وانتشار أسرع',
            ],
            'immediate_actions': [
                'أزل وتخلص من جميع الأوراق والأجزاء المصابة بعيداً عن الحقل فوراً',
                'أوقف الري من الأعلى وانتقل إلى الري بالتنقيط لتقليل الرطوبة',
                'اعزل النباتات المصابة بشدة لمنع انتقال المرض',
                'عقّم أدوات الزراعة بمحلول مطهر قبل وبعد الاستخدام',
                'ابدأ برنامج رش وقائي على النباتات المجاورة السليمة',
            ],
            'treatment_chemical': [
                'مانكوزيب 80% WP بمعدل 2.5 جم/لتر — رش كل 7 أيام',
                'مبيدات نحاسية (أوكسي كلوريد النحاس) بمعدل 3 جم/لتر — آمن وفعّال',
                'كلوروثالونيل بمعدل 2 مل/لتر للإصابات الشديدة',
            ],
            'treatment_organic': [
                'زيت النيم 2٪ — رش كل 5-7 أيام صباحاً أو مساءً',
                'محلول بيكربونات الصوديوم (5 جم/لتر + قطرات صابون سائل) — رش أسبوعي',
                'مستخلص الثوم المخفف — يمنع تطور الجراثيم الفطرية',
            ],
            'when_to_apply': 'الرش صباحاً باكراً أو بعد الغروب عند درجة حرارة أقل من 30°م وبدون رياح. تُكرَّر الجرعة كل 7-10 أيام.',
            'prevention': [
                'حافظ على مسافات كافية بين النباتات لضمان التهوية الجيدة',
                'اختر أصناف مقاومة للمرض عند الزراعة الجديدة',
                'دوّر المحاصيل ولا تزرع نفس العائلة النباتية في نفس المكان أكثر من موسمَين',
                'تخلص من بقايا المحصول السابق بعمق في التربة أو أحرقها',
                'راقب الحقل أسبوعياً لاكتشاف الإصابة مبكراً قبل انتشارها',
            ],
            'scan_again_recommended': confidence_pct < 80,
        }

    urgency_labels = {'high': 'Immediate action (24-48h)', 'medium': 'Act this week', 'low': 'Monitor closely'}
    return {
        'what_is_it': f'{disease} is a plant disease that damages crop tissue and reduces yield. Prompt identification and treatment are key to limiting losses.',
        'pathogen_type': 'Fungal',
        'confidence_note': (
            f'{confidence_pct}% confidence is moderately high — still worth confirming with an agronomist before costly treatment.'
            if confidence_pct >= 75 else
            f'{confidence_pct}% confidence is relatively low. Strongly consider retaking the scan in better light or consulting an expert.'
        ),
        'urgency_label': urgency_labels.get(severity, 'Monitor closely'),
        'urgency_level': level,
        'estimated_impact': 'Potential 20–40% crop losses if left untreated — higher in humid, warm conditions.',
        'favorable_conditions': 'Warm temperatures (20–30°C) combined with high humidity above 80% favour rapid disease spread.',
        'economic_threshold': 'Chemical treatment is justified when 10% or more of plants show visible infection symptoms.',
        'how_spreads': 'Spreads via wind-borne spores, rain splash, infected tools, and direct contact between neighbouring plants.',
        'symptoms': [
            'Dark or pale irregular spots or lesions on leaf surfaces',
            'Yellowing (chlorosis) starting at leaf edges and spreading inward',
            'Wilting of shoots and terminal buds',
            'Powdery, fuzzy, or water-soaked coating on leaf undersides',
            'Early and excessive leaf drop on affected plants',
            'Discolouration or deformation of fruit in severe cases',
        ],
        'look_alike_diseases': [
            'Late Blight — distinguished by rapid spread and a clear yellow halo around dark lesions',
        ],
        'immediate_actions': [
            'Remove and destroy all visibly infected leaves and plant parts — bag them away from the field',
            'Switch from overhead irrigation to drip irrigation immediately to reduce leaf wetness',
            'Isolate the most severely affected plants to prevent spread to healthy neighbours',
            'Disinfect all tools with bleach solution (1:10) before and after use in the field',
            'Begin a protective spray programme on surrounding healthy plants as a precaution',
        ],
        'treatment_chemical': [
            'Mancozeb 80WP at 2.5 g/L water — spray every 7 days, 3–4 applications',
            'Copper oxychloride at 3 g/L — broad-spectrum, safe residue profile',
            'Chlorothalonil at 2 mL/L — for severe infections, rotate with copper to prevent resistance',
        ],
        'treatment_organic': [
            'Neem oil 2% solution — spray every 5–7 days in early morning or evening',
            'Baking soda (5 g/L) + a few drops of liquid soap — weekly spray, disrupts spore germination',
            'Diluted garlic extract spray — apply every 5 days as a preventive and curative option',
        ],
        'when_to_apply': 'Spray early morning or after sunset when temperature is below 30°C and wind is calm. Repeat every 7–10 days. Avoid spraying before rain.',
        'prevention': [
            'Maintain proper plant spacing to ensure good air circulation through the canopy',
            'Choose disease-resistant varieties when replanting',
            'Rotate crops — avoid planting the same plant family in the same field two seasons in a row',
            'Remove and bury or burn all crop residues after harvest to eliminate overwintering inoculum',
            'Scout the field weekly so early infections are caught before they spread',
        ],
        'scan_again_recommended': confidence_pct < 80,
    }
