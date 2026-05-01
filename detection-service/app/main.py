"""
AgriLens Detection Service
Provides disease detection from plant images.
"""
import os

from dotenv import load_dotenv
from flask import Flask
from flask_cors import CORS

load_dotenv()


def create_app():
    app = Flask(__name__)
    CORS(app)
    app.config["MODEL_PATH"] = os.getenv("MODEL_PATH", "")
    app.config["TOMATO_MODEL_PATH"] = os.getenv("TOMATO_MODEL_PATH", "")
    app.config["POTATO_MODEL_PATH"] = os.getenv("POTATO_MODEL_PATH", "")
    app.config["APPLE_MODEL_PATH"] = os.getenv("APPLE_MODEL_PATH", "")
    app.config["MODEL_FORCE_CPU"] = os.getenv("MODEL_FORCE_CPU", "true").lower() == "true"

    from app.controllers.detection_controller import detection_bp
    from app.controllers.health_controller import health_bp
    from app.utils.model_loader import init_model_loader

    app.register_blueprint(health_bp)
    app.register_blueprint(detection_bp)
    init_model_loader(app)

    return app
