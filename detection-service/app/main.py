"""
AgriLens Detection Service
Provides disease detection from plant images.
Currently returns mock data — DSAI team will integrate real CNN/YOLO models.
"""
from flask import Flask
from flask_cors import CORS


def create_app():
    app = Flask(__name__)
    CORS(app)

    from app.controllers.detection_controller import detection_bp
    from app.controllers.health_controller import health_bp

    app.register_blueprint(health_bp)
    app.register_blueprint(detection_bp)

    return app
