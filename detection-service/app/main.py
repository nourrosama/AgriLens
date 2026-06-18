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
    app.config["GRAPE_MODEL_PATH"] = os.getenv("GRAPE_MODEL_PATH", "")
    app.config["WHEAT_MODEL_PATH"] = os.getenv("WHEAT_MODEL_PATH", "")
    app.config["CORN_MODEL_PATH"] = os.getenv("CORN_MODEL_PATH", "")
    app.config["CORN_LABELS_PATH"] = os.getenv("CORN_LABELS_PATH", "")
    app.config["SUGARCANE_MODEL_PATH"] = os.getenv("SUGARCANE_MODEL_PATH", "")
    app.config["SUGARCANE_LABELS_PATH"] = os.getenv("SUGARCANE_LABELS_PATH", "")
    app.config["COTTON_MODEL_PATH"] = os.getenv("COTTON_MODEL_PATH", "")
    app.config["COTTON_TFLITE_MODEL_PATH"] = os.getenv("COTTON_TFLITE_MODEL_PATH", "")
    app.config["COTTON_LABELS_PATH"] = os.getenv("COTTON_LABELS_PATH", "")
    app.config["CROP_VALIDATOR_MODEL_PATH"] = os.getenv("CROP_VALIDATOR_MODEL_PATH", "")
    app.config["CROP_VALIDATOR_LABELS_PATH"] = os.getenv("CROP_VALIDATOR_LABELS_PATH", "")
    app.config["CROP_VALIDATOR_ENABLED"] = (
        os.getenv("CROP_VALIDATOR_ENABLED", "true").lower() == "true"
    )
    app.config["CROP_VALIDATOR_NOT_PLANT_THRESHOLD"] = float(
        os.getenv("CROP_VALIDATOR_NOT_PLANT_THRESHOLD", "0.35")
    )
    app.config["CROP_VALIDATOR_SUPPORTED_THRESHOLD"] = float(
        os.getenv("CROP_VALIDATOR_SUPPORTED_THRESHOLD", "0.65")
    )
    app.config["VIDEO_MODEL_PATH"] = os.getenv("VIDEO_MODEL_PATH", "")
    app.config["VIDEO_LABELS_PATH"] = os.getenv("VIDEO_LABELS_PATH", "")
    app.config["VIDEO_KEYFRAME_TARGET_FPS"] = float(os.getenv("VIDEO_KEYFRAME_TARGET_FPS", "10"))
    app.config["VIDEO_KEYFRAME_WINDOW"] = int(os.getenv("VIDEO_KEYFRAME_WINDOW", "64"))
    app.config["VIDEO_KEYFRAME_STRIDE"] = int(os.getenv("VIDEO_KEYFRAME_STRIDE", "32"))
    app.config["VIDEO_KEYFRAME_THRESHOLD"] = float(os.getenv("VIDEO_KEYFRAME_THRESHOLD", "0.5"))
    app.config["VIDEO_KEYFRAME_MIN_DISTANCE"] = int(os.getenv("VIDEO_KEYFRAME_MIN_DISTANCE", "5"))
    app.config["VIDEO_KEYFRAME_MAX_SOURCE_FRAMES"] = int(
        os.getenv("VIDEO_KEYFRAME_MAX_SOURCE_FRAMES", "600")
    )
    app.config["VIDEO_KEYFRAME_MAX_SELECTED"] = int(os.getenv("VIDEO_KEYFRAME_MAX_SELECTED", "20"))
    app.config["MODEL_FORCE_CPU"] = os.getenv("MODEL_FORCE_CPU", "true").lower() == "true"

    from app.controllers.detection_controller import detection_bp
    from app.controllers.health_controller import health_bp
    from app.utils.model_loader import init_model_loader

    app.register_blueprint(health_bp)
    app.register_blueprint(detection_bp)
    init_model_loader(app)

    return app
