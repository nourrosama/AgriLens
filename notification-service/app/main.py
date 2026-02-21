"""
AgriLens Notification Service
Listens for high-risk detection events via RabbitMQ (Observer pattern)
and dispatches alerts through SMS/Push channels.
"""
from flask import Flask
from flask_cors import CORS


def create_app():
    app = Flask(__name__)
    CORS(app)

    from app.controllers.health_controller import health_bp
    app.register_blueprint(health_bp)

    return app
