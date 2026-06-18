"""
AI-powered chatbot service using Groq API.
"""
import logging
import os
from datetime import datetime, timezone

from groq import Groq

logger = logging.getLogger(__name__)

_client = None


def _fallback_response(message: str, lang: str) -> dict:
    from app.services.insights_service import build_chat_response

    return build_chat_response(message, lang)


def _get_client():
    global _client
    if _client is None:
        api_key = os.getenv('GROQ_API_KEY', '')
        if not api_key:
            logger.warning('GROQ_API_KEY not set')
            return None
        _client = Groq(api_key=api_key)
    return _client


def get_ai_response(message: str, lang: str = 'en') -> dict:
    """Get AI response from Groq API."""
    is_arabic = lang == 'ar' or any('\u0600' <= c <= '\u06ff' for c in message)

    system_prompt = (
        'أنت AgriBot، مساعد زراعي ذكاء اصطناعي متخصص ومحترف. '
        'تساعد المزارعين بنصائح خبراء في أمراض المحاصيل والأسمدة والري ومكافحة الآفات والممارسات الزراعية. '
        'أجب دائماً بأسلوب احترافي ومنظم ومفيد باللغة العربية الفصحى البسيطة. '
        'التزم بتنسيق Markdown بشكل صارم في كل إجاباتك: '
        '- ابدأ بعنوان ## يلخص الموضوع بوضوح '
        '- استخدم **نص عريض** لجميع المصطلحات الرئيسية وأسماء الأمراض والنقاط المهمة '
        '- استخدم قوائم نقطية (- ) لجميع التعدادات، لا تستخدم أرقاماً أبداً '
        '- أضف قسم ### نصائح عملية أو ### طرق الوقاية عند الاقتضاء '
        '- اختم دائماً بجملة تشجيعية إيجابية '
        '- اجعل الإجابات موجزة وشاملة في آنٍ واحد '
        '- افصل الأقسام دائماً بأسطر فارغة'
        if is_arabic else
        'You are AgriBot, a professional agricultural AI assistant. '
        'You help farmers with expert advice on crop diseases, fertilizers, irrigation, pest control, and farming best practices. '
        'Always respond in a professional, structured, and helpful tone in clear English. '
        'You MUST strictly use Markdown formatting in every response: '
        '- Start with a ## heading that clearly summarizes the topic '
        '- Use **bold** for ALL key terms, disease names, chemicals, and important points '
        '- Use bullet lists (- ) for ALL enumerations, NEVER use numbered lists '
        '- Add a ### Practical Tips or ### Prevention section when relevant '
        '- Always end with a positive encouraging closing sentence '
        '- Keep responses concise yet comprehensive '
        '- Always separate sections with blank lines'
    )

    suggestions_ar = [
        'ما هي الأمراض التي تصيب الطماطم؟',
        'كيف أمنع لفحة الأوراق؟',
        'أفضل سماد للقمح؟',
        'متى أسقي محاصيلي؟',
    ]
    suggestions_en = [
        'What diseases affect tomatoes?',
        'How to prevent leaf blight?',
        'Best fertilizer for wheat?',
        'When should I water my crops?',
    ]

    client = _get_client()
    if client is None:
        return _fallback_response(message, lang)

    try:
        completion = client.chat.completions.create(
            model='llama-3.3-70b-versatile',
            messages=[
                {'role': 'system', 'content': system_prompt},
                {'role': 'user', 'content': message},
            ],
            max_tokens=800,
            temperature=0.5,
        )
        reply = completion.choices[0].message.content.strip()
    except Exception as e:
        logger.error('Groq API error: %s', e)
        return _fallback_response(message, lang)

    return {
        'reply': reply,
        'suggestions': suggestions_ar if is_arabic else suggestions_en,
        'generated_at': datetime.now(timezone.utc).isoformat(),
    }
