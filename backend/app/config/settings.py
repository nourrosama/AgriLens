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

    # Video analysis pipeline (FR-5)
    VIDEO_FRAME_INTERVAL_SEC = float(os.getenv('VIDEO_FRAME_INTERVAL_SEC', 2))
    VIDEO_MAX_FRAMES = int(os.getenv('VIDEO_MAX_FRAMES', 20))
    VIDEO_BLUR_THRESHOLD = float(os.getenv('VIDEO_BLUR_THRESHOLD', 80.0))
    VIDEO_MIN_FRAMES_REQUIRED = int(os.getenv('VIDEO_MIN_FRAMES_REQUIRED', 1))
    VIDEO_SAVE_DEBUG_FRAMES = os.getenv('VIDEO_SAVE_DEBUG_FRAMES', 'false').lower() == 'true'
    VIDEO_KEYFRAME_MODEL_ENABLED = os.getenv('VIDEO_KEYFRAME_MODEL_ENABLED', 'true').lower() == 'true'
    VIDEO_KEYFRAME_TARGET_FPS = float(os.getenv('VIDEO_KEYFRAME_TARGET_FPS', 10))

    # Inter-service URLs
    DETECTION_PROVIDER = os.getenv('DETECTION_PROVIDER', 'local').strip().lower()
    DETECTION_SERVICE_URL = os.getenv('DETECTION_SERVICE_URL', 'http://localhost:5001')
    DETECTION_CONNECT_TIMEOUT = float(os.getenv('DETECTION_CONNECT_TIMEOUT', '5'))
    DETECTION_REQUEST_TIMEOUT = float(os.getenv('DETECTION_REQUEST_TIMEOUT', '120'))
    SAGEMAKER_REGION = os.getenv('SAGEMAKER_REGION', os.getenv('AWS_REGION', 'us-east-1')).strip()
    SAGEMAKER_ENDPOINT_NAME = os.getenv('SAGEMAKER_ENDPOINT_NAME', '').strip()
    SAGEMAKER_ENDPOINTS = os.getenv('SAGEMAKER_ENDPOINTS', '').strip()
    SAGEMAKER_PROFILE = os.getenv('SAGEMAKER_PROFILE', '').strip()
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

    # Gmail SMTP (email OTP + support notifications)
    GMAIL_USER = os.getenv('GMAIL_USER', '')
    GMAIL_APP_PASSWORD = os.getenv('GMAIL_APP_PASSWORD', '')

    # Support — where user messages are emailed
    SUPPORT_EMAIL = os.getenv('SUPPORT_EMAIL', '')

    # Firebase (FCM push notifications)
    FIREBASE_CREDENTIALS_PATH = os.getenv('FIREBASE_CREDENTIALS_PATH', '')
