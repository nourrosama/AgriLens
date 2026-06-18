"""
AgriLens Backend API - Application factory.
Initializes MongoDB, Redis, RabbitMQ, media storage, Swagger, and all blueprints.
"""
import logging

from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
from flasgger import Swagger

from dotenv import load_dotenv

load_dotenv()


def create_app():
    """Application factory pattern."""
    app = Flask(__name__)
    app.logger.setLevel(logging.INFO)
    CORS(app)

    # Allow the Flask admin panel to be embedded in an iframe from Flutter Web
    @app.after_request
    def _allow_iframe(response):
        response.headers.pop('X-Frame-Options', None)
        response.headers['Content-Security-Policy'] = "frame-ancestors *"
        return response

    from app.config.settings import Config
    app.config.from_object(Config)

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
                'description': 'JWT token - enter as: Bearer <token>',
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
            {'name': 'Forum', 'description': 'Community feed, posts, Q&A, communities'},
            {'name': 'Articles', 'description': 'Farmer-facing published articles'},
            {'name': 'Health', 'description': 'Service status'},
        ],
    }
    Swagger(app, config=swagger_config, template=swagger_template)

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
    from app.controllers.forum_controller import forum_bp
    from app.controllers.community_controller import community_bp
    from app.controllers.admin_controller import admin_bp
    from app.controllers.article_controller import article_bp
    from app.controllers.subscription_controller import subscription_bp
    from app.controllers.support_controller import support_bp

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
    app.register_blueprint(forum_bp)
    app.register_blueprint(community_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(article_bp)
    app.register_blueprint(subscription_bp)
    app.register_blueprint(support_bp)

    from app.services.push_service import init_push_service
    init_push_service(app)

    import os

    admin_static = os.path.join(os.path.dirname(__file__), 'static', 'admin')
    user_static  = os.path.join(os.path.dirname(__file__), 'static', 'user')

    @app.route('/admin/auto-login')
    def admin_auto_login():
        """
        Called by the Flutter mobile app after the user has already
        authenticated via the normal OTP flow.  Accepts the JWT token as a
        query parameter, validates it, and returns a tiny HTML page that
        writes the token into localStorage then redirects straight to the
        admin dashboard — skipping the web login screen entirely.
        """
        import jwt as _jwt
        from flask import request as _req, make_response

        token = _req.args.get('token', '').strip()
        error_html = lambda msg: (
            f'<html><body style="font-family:sans-serif;text-align:center;padding:60px">'
            f'<h2 style="color:#c62828">Access Denied</h2><p>{msg}</p></body></html>'
        )

        if not token:
            return make_response(error_html('No token provided.'), 400)

        try:
            payload = _jwt.decode(
                token,
                app.config['JWT_SECRET'],
                algorithms=['HS256'],
            )
            from app.models.user_model import find_by_id
            user = find_by_id(payload['sub'])
            if not user or user.get('role') != 'admin':
                return make_response(error_html('Admin access only.'), 403)
        except Exception:
            return make_response(error_html('Invalid or expired token.'), 401)

        # Return HTML that sets the token in localStorage (same origin as the
        # admin panel) and immediately redirects to the dashboard.
        html = f"""<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<title>Signing in…</title></head>
<body>
<script>
  localStorage.setItem('admin_token', {repr(token)});
  window.location.replace('/admin/dashboard.html');
</script>
<p style="font-family:sans-serif;text-align:center;padding:40px">Signing in…</p>
</body></html>"""
        return make_response(html, 200)

    @app.route('/admin/', defaults={'filename': 'login.html'})
    @app.route('/admin/<path:filename>')
    def serve_admin(filename):
        """Serve the admin HTML dashboard."""
        return send_from_directory(admin_static, filename)

    # ── User Portal (subscription-aware web UI) ────────────────────────────
    USER_PAGES = {
        'login':     'login.html',
        'dashboard': 'dashboard.html',
        'scan':      'scan.html',
        'articles':  'articles.html',
        'chatbot':   'chatbot.html',
        'farm':      'farm.html',
        'reports':   'reports.html',
    }

    @app.route('/app/')
    @app.route('/app/dashboard')
    def user_dashboard():
        return send_from_directory(user_static, 'dashboard.html')

    @app.route('/app/login')
    def user_login():
        return send_from_directory(user_static, 'login.html')

    @app.route('/app/scan')
    def user_scan():
        return send_from_directory(user_static, 'scan.html')

    @app.route('/app/articles')
    def user_articles():
        return send_from_directory(user_static, 'articles.html')

    @app.route('/app/chatbot')
    def user_chatbot():
        return send_from_directory(user_static, 'chatbot.html')

    @app.route('/app/farm')
    def user_farm():
        return send_from_directory(user_static, 'farm.html')

    @app.route('/app/reports')
    def user_reports():
        return send_from_directory(user_static, 'reports.html')


    @app.route('/app/static/<path:filename>')
    def serve_user_static(filename):
        """Serve shared CSS/JS assets for the user portal."""
        return send_from_directory(user_static, filename)

    from app.services import storage_service

    if storage_service.uses_local_storage():
        @app.route('/uploads/<path:filename>', methods=['GET'])
        def serve_upload(filename):
            """Serve locally stored uploads for development/demo use."""
            return send_from_directory(app.config.get('UPLOAD_FOLDER', 'uploads'), filename)

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

    @app.errorhandler(503)
    def service_unavailable(e):
        return jsonify({'status': 'error', 'message': str(e.description)}), 503

    @app.errorhandler(RuntimeError)
    def db_not_ready(e):
        msg = str(e)
        if 'Database not initialised' in msg or 'call init_db' in msg:
            return jsonify({'status': 'error', 'message': 'Database unavailable. Please try again shortly.'}), 503
        return jsonify({'status': 'error', 'message': 'Internal server error'}), 500

    @app.errorhandler(500)
    def server_error(e):
        return jsonify({'status': 'error', 'message': 'Internal server error'}), 500

    return app
