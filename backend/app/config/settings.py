"""
Application configuration loaded from environment variables.
"""
import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    """Central configuration pulled from .env or defaults."""

    # MongoDB
    MONGO_URI = os.getenv('MONGO_URI', '').strip()

    # Security
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key')
    JWT_SECRET = os.getenv('JWT_SECRET', 'jwt-dev-secret')
    JWT_EXPIRY_HOURS = int(os.getenv('JWT_EXPIRY_HOURS', '720'))

    # Twilio Verify
    TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', '')
    TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', '')
    TWILIO_VERIFY_SERVICE_SID = os.getenv('TWILIO_VERIFY_SERVICE_SID', '')
    TWILIO_MOCK_MODE = os.getenv('TWILIO_MOCK_MODE', 'true').lower() == 'true'

    # Scan media storage
    MEDIA_STORAGE_PROVIDER = os.getenv(
        'MEDIA_STORAGE_PROVIDER',
        'cloudinary' if os.getenv('CLOUDINARY_CLOUD_NAME', '') else 'local',
    ).strip().lower()
    CLOUDINARY_CLOUD_NAME = os.getenv('CLOUDINARY_CLOUD_NAME', '').strip()
    CLOUDINARY_API_KEY = os.getenv('CLOUDINARY_API_KEY', '').strip()
    CLOUDINARY_API_SECRET = os.getenv('CLOUDINARY_API_SECRET', '').strip()
    CLOUDINARY_UPLOAD_TIMEOUT = int(os.getenv('CLOUDINARY_UPLOAD_TIMEOUT', '30'))

    # Uploads
    UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', 'uploads')
    MAX_CONTENT_LENGTH = 50 * 1024 * 1024  # 50 MB

    # Inter-service URLs
    DETECTION_SERVICE_URL = os.getenv('DETECTION_SERVICE_URL', 'http://localhost:5001')
    FORECAST_SERVICE_URL = os.getenv('FORECAST_SERVICE_URL', 'http://localhost:5002')
    DETECTION_MOCK_FALLBACK = os.getenv('DETECTION_MOCK_FALLBACK', 'false').lower() == 'true'

    # RabbitMQ
    RABBITMQ_URL = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')

    # Redis
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

    # Rate limiting
    OTP_RATE_LIMIT_MAX = int(os.getenv('OTP_RATE_LIMIT_MAX', '3'))
    OTP_RATE_LIMIT_WINDOW = int(os.getenv('OTP_RATE_LIMIT_WINDOW', '600'))
    VERIFY_RATE_LIMIT_MAX = int(os.getenv('VERIFY_RATE_LIMIT_MAX', '5'))
    VERIFY_RATE_LIMIT_WINDOW = int(os.getenv('VERIFY_RATE_LIMIT_WINDOW', '600'))
