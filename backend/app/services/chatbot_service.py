"""
AI-powered chatbot service using Groq API.
"""
import logging
import os
from datetime import datetime, timezone

from groq import Groq

logger = logging.getLogger(__name__)

_client = None


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
        'أنت مساعد زراعي ذكي متخصص في مساعدة المزارعين العرب. '
        'أجب دائماً باللغة العربية الفصحى البسيطة. '
        'تخصصك في: أمراض المحاصيل، الأسمدة، الري، مكافحة الآفات، والزراعة العامة. '
        'اجعل إجاباتك عملية ومباشرة ومناسبة للمزارعين. '
        'يجب أن تلتزم بتنسيق Markdown بشكل صارم في كل إجاباتك: '
        '- ابدأ دائماً بعنوان رئيسي باستخدام ## '
        '- استخدم **نص عريض** لكل المصطلحات والنقاط المهمة '
        '- استخدم قوائم نقطية تبدأ بـ - لكل تعداد '
        '- لا تستخدم أرقاماً عادية للتعداد أبداً '
        '- افصل بين الأقسام بسطر فارغ '
        '- اجعل الإجابة منظمة وجميلة وسهلة القراءة'
        if is_arabic else
        'You are an expert agricultural assistant helping farmers. '
        'Always respond in clear English. '
        'You specialize in: crop diseases, fertilizers, irrigation, pest control, and general farming. '
        'Keep answers practical and suitable for farmers. '
        'You MUST strictly use Markdown formatting in every response: '
        '- Always start with a main heading using ## '
        '- Use **bold** for ALL important terms and key points '
        '- Use bullet lists starting with - for ALL enumerations '
        '- NEVER use numbered lists '
        '- Separate sections with a blank line '
        '- Keep responses well organized and visually clean'
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
        reply = (
            'عذراً، خدمة الذكاء الاصطناعي غير متاحة حالياً. تحقق من إعداد GROQ_API_KEY.'
            if is_arabic else
            'Sorry, AI service is unavailable. Please check GROQ_API_KEY configuration.'
        )
        return {
            'reply': reply,
            'suggestions': suggestions_ar if is_arabic else suggestions_en,
            'generated_at': datetime.now(timezone.utc).isoformat(),
        }

    try:
        completion = client.chat.completions.create(
            model='llama-3.3-70b-versatile',
            messages=[
                {'role': 'system', 'content': system_prompt},
                {'role': 'user', 'content': message},
            ],
            max_tokens=700,
            temperature=0.6,
        )
        reply = completion.choices[0].message.content.strip()
    except Exception as e:
        logger.error('Groq API error: %s', e)
        reply = (
            'عذراً، حدث خطأ في الاتصال بخدمة الذكاء الاصطناعي. حاول مرة أخرى.'
            if is_arabic else
            'Sorry, an error occurred connecting to the AI service. Please try again.'
        )

    return {
        'reply': reply,
        'suggestions': suggestions_ar if is_arabic else suggestions_en,
        'generated_at': datetime.now(timezone.utc).isoformat(),
    }