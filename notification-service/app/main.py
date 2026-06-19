"""
AgriLens Notification Service
Listens for high-risk detection events via RabbitMQ (Observer pattern)
and dispatches alerts through SMS/Push channels.
"""
import os

from dotenv import load_dotenv
from flask import Flask
from flask_cors import CORS

load_dotenv()


def _cors_allowed_origins() -> list[str]:
    return [
        origin.strip()
        for origin in os.getenv(
            'CORS_ALLOWED_ORIGINS',
            'http://localhost:5000,http://127.0.0.1:5000,'
            'http://localhost:8080,http://127.0.0.1:8080',
        ).split(',')
        if origin.strip()
    ]


def create_app():
    app = Flask(__name__)
    CORS(
        app,
        resources={r"/*": {"origins": _cors_allowed_origins()}},
        supports_credentials=True,
    )

    app.config['RABBITMQ_URL'] = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
    app.config['MONGO_URI'] = os.getenv('MONGO_URI', '')
    app.config['TWILIO_ACCOUNT_SID'] = os.getenv('TWILIO_ACCOUNT_SID', '')
    app.config['TWILIO_AUTH_TOKEN'] = os.getenv('TWILIO_AUTH_TOKEN', '')
    app.config['FIREBASE_CREDENTIALS_PATH'] = os.getenv('FIREBASE_CREDENTIALS_PATH', '')

    from app.controllers.health_controller import health_bp
    from app.services.runtime import init_runtime

    app.register_blueprint(health_bp)
    init_runtime(app)
    return app
