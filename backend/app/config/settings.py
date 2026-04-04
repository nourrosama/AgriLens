"""
Application configuration â€” loads from environment variables.
"""
import os
from dotenv import load_dotenv

load_dotenv(override=True)


class Config:
    """Central configuration pulled from .env or defaults."""

    # â”€â”€ MongoDB â”€â”€
    MONGO_URI = os.getenv('MONGO_URI', 'mongodb://localhost:27017/agrilens')

    # â”€â”€ Security â”€â”€
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key')
    JWT_SECRET = os.getenv('JWT_SECRET', 'jwt-dev-secret')
    JWT_EXPIRY_HOURS = int(os.getenv('JWT_EXPIRY_HOURS', '24'))

    # â”€â”€ Twilio Verify â”€â”€
    TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', '')
    TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', '')
    TWILIO_VERIFY_SERVICE_SID = os.getenv('TWILIO_VERIFY_SERVICE_SID', '')
    TWILIO_MOCK_MODE = os.getenv('TWILIO_MOCK_MODE', 'true').lower() == 'true'

    # â”€â”€ Firebase Storage â”€â”€
    FIREBASE_CREDENTIALS_PATH = os.getenv('FIREBASE_CREDENTIALS_PATH', '')
    FIREBASE_STORAGE_BUCKET = os.getenv('FIREBASE_STORAGE_BUCKET', '')

    # ── Cloudinary ──
    CLOUDINARY_CLOUD_NAME = os.getenv('CLOUDINARY_CLOUD_NAME', '')
    CLOUDINARY_API_KEY = os.getenv('CLOUDINARY_API_KEY', '')
    CLOUDINARY_API_SECRET = os.getenv('CLOUDINARY_API_SECRET', '')

    # â”€â”€ Uploads â”€â”€
    UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', 'uploads')
    MAX_CONTENT_LENGTH = 50 * 1024 * 1024  # 50 MB

    # â”€â”€ Inter-service URLs â”€â”€
    DETECTION_SERVICE_URL = os.getenv('DETECTION_SERVICE_URL', 'http://localhost:5001')
    FORECAST_SERVICE_URL = os.getenv('FORECAST_SERVICE_URL', 'http://localhost:5002')
    DETECTION_MOCK_FALLBACK = os.getenv('DETECTION_MOCK_FALLBACK', 'false').lower() == 'true'

    # â”€â”€ RabbitMQ â”€â”€
    RABBITMQ_URL = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')

    # â”€â”€ Redis â”€â”€
    REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')

    OPENWEATHER_API_KEY = os.getenv('OPENWEATHER_API_KEY', '')
    OPENWEATHER_API_URL = os.getenv(
        'OPENWEATHER_API_URL',
        'https://api.openweathermap.org/data/3.0/onecall',
    )
    OPENWEATHER_FALLBACK_URL = os.getenv(
        'OPENWEATHER_FALLBACK_URL',
        'https://api.openweathermap.org/data/2.5/onecall',
    )

    # â”€â”€ Rate Limiting â”€â”€
    OTP_RATE_LIMIT_MAX = int(os.getenv('OTP_RATE_LIMIT_MAX', '3'))          # per window
    OTP_RATE_LIMIT_WINDOW = int(os.getenv('OTP_RATE_LIMIT_WINDOW', '600'))  # 10 min
    VERIFY_RATE_LIMIT_MAX = int(os.getenv('VERIFY_RATE_LIMIT_MAX', '5'))
    VERIFY_RATE_LIMIT_WINDOW = int(os.getenv('VERIFY_RATE_LIMIT_WINDOW', '600'))
