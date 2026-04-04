"""
AgriLens Backend API â€” Application factory.
Initialises MongoDB, Redis, RabbitMQ, Firebase, Swagger, and all blueprints.
"""
import os
from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
from flasgger import Swagger
from dotenv import load_dotenv

load_dotenv(override=True)


def create_app():
    """Application factory pattern."""
    app = Flask(__name__)
    CORS(app)

    # â”€â”€ Load configuration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    from app.config.settings import Config
    app.config.from_object(Config)

    # Ensure upload directory exists (local fallback)
    os.makedirs(app.config.get('UPLOAD_FOLDER', 'uploads'), exist_ok=True)

    # â”€â”€ Initialise services â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    from app.models.db import init_db
    init_db(app)

    from app.services.auth_service import init_auth_service
    init_auth_service(app)

    from app.services.storage_service import init_storage
    init_storage(app)

    from app.services.cache import init_cache
    init_cache(app)

    from app.observers.event_publisher import init_publisher
    init_publisher(app)

    # â”€â”€ Swagger / OpenAPI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    swagger_config = {
        'headers': [],
        'specs': [{
            'endpoint': 'apispec',
            'route': '/apispec.json',
            'rule_filter': lambda rule: True,
            'model_filter': lambda tag: True,
        }],
        'static_url_path': '/flasgger_static',
        'swagger_ui': True,
        'specs_route': '/api/docs',
    }
    swagger_template = {
        'info': {
            'title': 'AgriLens API',
            'description': 'AI-based crop disease detection & forecasting platform',
            'version': '1.0.0',
        },
        'securityDefinitions': {
            'Bearer': {
                'type': 'apiKey',
                'name': 'Authorization',
                'in': 'header',
                'description': 'JWT token â€” enter as: Bearer <token>',
            },
        },
        'tags': [
            {'name': 'Auth', 'description': 'OTP login & user profile'},
            {'name': 'Farms', 'description': 'Farm & field management'},
            {'name': 'Scans', 'description': 'Image upload & detection'},
            {'name': 'Forecast', 'description': 'Disease forecasting'},
            {'name': 'Notifications', 'description': 'User alerts and notification state'},
            {'name': 'Weather', 'description': 'Current and forecast weather'},
            {'name': 'Dashboard', 'description': 'Mobile dashboard summaries'},
            {'name': 'Reports', 'description': 'Report export'},
            {'name': 'Chatbot', 'description': 'Farmer assistant'},
            {'name': 'Health', 'description': 'Service status'},
        ],
    }
    Swagger(app, config=swagger_config, template=swagger_template)

    # â”€â”€ Register blueprints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    from app.controllers.health_controller import health_bp
    from app.controllers.auth_controller import auth_bp
    from app.controllers.farm_controller import farm_bp
    from app.controllers.scan_controller import scan_bp
    from app.controllers.forecast_controller import forecast_bp
    from app.controllers.notification_controller import notifications_bp
    from app.controllers.weather_controller import weather_bp
    from app.controllers.dashboard_controller import dashboard_bp
    from app.controllers.report_controller import reports_bp
    from app.controllers.chatbot_controller import chatbot_bp

    app.register_blueprint(health_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(farm_bp)
    app.register_blueprint(scan_bp)
    app.register_blueprint(forecast_bp)
    app.register_blueprint(notifications_bp)
    app.register_blueprint(weather_bp)
    app.register_blueprint(dashboard_bp)
    app.register_blueprint(reports_bp)
    app.register_blueprint(chatbot_bp)

    @app.route('/uploads/<path:filename>', methods=['GET'])
    def serve_upload(filename):
        """Serve locally stored uploads for development/demo use."""
        return send_from_directory(app.config.get('UPLOAD_FOLDER', 'uploads'), filename)

    # â”€â”€ Global error handlers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    @app.errorhandler(400)
    def bad_request(e):
        return jsonify({'status': 'error', 'message': str(e)}), 400

    @app.errorhandler(404)
    def not_found(e):
        return jsonify({'status': 'error', 'message': 'Resource not found'}), 404

    @app.errorhandler(413)
    def too_large(e):
        return jsonify({'status': 'error', 'message': 'File too large (max 50 MB)'}), 413

    @app.errorhandler(429)
    def rate_limited(e):
        return jsonify({'status': 'error', 'message': 'Rate limit exceeded'}), 429

    @app.errorhandler(500)
    def server_error(e):
        return jsonify({'status': 'error', 'message': 'Internal server error'}), 500

    return app
