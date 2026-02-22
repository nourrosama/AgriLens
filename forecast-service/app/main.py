"""
AgriLens Forecast Service
Predicts disease spread risk using time-series models.
Currently returns mock data — DSAI team will integrate LSTM/Prophet/ARIMA models.
"""
from flask import Flask
from flask_cors import CORS


def create_app():
    app = Flask(__name__)
    CORS(app)

    from app.controllers.forecast_controller import forecast_bp
    from app.controllers.health_controller import health_bp

    app.register_blueprint(health_bp)
    app.register_blueprint(forecast_bp)

    return app
