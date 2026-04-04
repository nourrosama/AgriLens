"""
AgriLens Notification Service
Listens for high-risk detection events via RabbitMQ (Observer pattern)
and dispatches alerts through SMS/Push channels.
"""
import os
from flask import Flask
from flask_cors import CORS


def create_app():
    app = Flask(__name__)
    CORS(app)

    from app.controllers.health_controller import health_bp
    app.register_blueprint(health_bp)

    app.config['RABBITMQ_URL'] = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')

    from app.observers.event_consumer import start_consumer
    start_consumer(app)

    return app
