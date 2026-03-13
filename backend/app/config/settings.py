"""
Application configuration — loads from environment variables.
"""
import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    """Central configuration pulled from .env or defaults."""

    # ── MongoDB ──
    MONGO_URI = os.getenv('MONGO_URI', 'mongodb://localhost:27017/agrilens')

    # ── Security ──
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key')
    JWT_SECRET = os.getenv('JWT_SECRET', 'jwt-dev-secret')
    JWT_EXPIRY_HOURS = int(os.getenv('JWT_EXPIRY_HOURS', '24'))

    # ── Twilio Verify ──
    TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', '')
    TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', '')
    TWILIO_VERIFY_SERVICE_SID = os.getenv('TWILIO_VERIFY_SERVICE_SID', '')
    TWILIO_MOCK_MODE = os.getenv('TWILIO_MOCK_MODE', 'true').lower() == 'true'

    # ── Firebase Storage ──
    FIREBASE_CREDENTIALS_PATH = os.getenv('FIREBASE_CREDENTIALS_PATH', '')
    FIREBASE_STORAGE_BUCKET = os.getenv('FIREBASE_STORAGE_BUCKET', '')

    # ── Uploads ──
    UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', 'uploads')
    MAX_CONTENT_LENGTH = 50 * 1024 * 1024  # 50 MB

    # ── Inter-service URLs ──
    DETECTION_SERVICE_URL = os.getenv('DETECTION_SERVICE_URL', 'http://localhost:5001')
    FORECAST_SERVICE_URL = os.getenv('FORECAST_SERVICE_URL', 'http://localhost:5002')

    # ── RabbitMQ ──
    RABBITMQ_URL = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')

    # ── Redis ──
    REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')

    # ── Rate Limiting ──
    OTP_RATE_LIMIT_MAX = int(os.getenv('OTP_RATE_LIMIT_MAX', '3'))          # per window
    OTP_RATE_LIMIT_WINDOW = int(os.getenv('OTP_RATE_LIMIT_WINDOW', '600'))  # 10 min
    VERIFY_RATE_LIMIT_MAX = int(os.getenv('VERIFY_RATE_LIMIT_MAX', '5'))
    VERIFY_RATE_LIMIT_WINDOW = int(os.getenv('VERIFY_RATE_LIMIT_WINDOW', '600'))
