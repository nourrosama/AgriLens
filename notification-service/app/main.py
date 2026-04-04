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


def create_app():
    app = Flask(__name__)
    CORS(app)

    app.config['RABBITMQ_URL'] = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
    app.config['MONGO_URI'] = os.getenv('MONGO_URI', '')
    app.config['TWILIO_ACCOUNT_SID'] = os.getenv('TWILIO_ACCOUNT_SID', '')
    app.config['TWILIO_AUTH_TOKEN'] = os.getenv('TWILIO_AUTH_TOKEN', '')
    app.config['FIREBASE_CREDENTIALS_PATH'] = os.getenv('FIREBASE_CREDENTIALS_PATH', '')

    from app.controllers.health_controller import health_bp
    from app.services.runtime import init_runtime

    app.register_blueprint(health_bp)
    init_runtime(app)

    from app.observers.event_consumer import start_consumer

    start_consumer(app)
    return app
