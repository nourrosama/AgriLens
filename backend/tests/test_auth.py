"""
Tests for auth endpoints — send-otp, verify-otp, profile.
Uses Flask test client with mocked MongoDB and mock Twilio.
"""
import pytest
import json
from unittest.mock import patch, MagicMock
from bson import ObjectId


@pytest.fixture
def app():
    """Create test app with mocked DB."""
    with patch('app.models.db.init_db') as mock_init:
        mock_init.return_value = MagicMock()
        with patch('app.services.auth_service.init_auth_service'):
            with patch('app.services.storage_service.init_storage'):
                with patch('app.services.cache.init_cache'):
                    with patch('app.observers.event_publisher.init_publisher'):
                        from app.main import create_app
                        app = create_app()
                        app.config['TESTING'] = True
                        yield app


@pytest.fixture
def client(app):
    return app.test_client()


class TestSendOTP:
    def test_missing_phone(self, client):
        resp = client.post('/api/auth/send-otp',
                           data=json.dumps({}),
                           content_type='application/json')
        assert resp.status_code == 400

    def test_invalid_phone(self, client):
        resp = client.post('/api/auth/send-otp',
                           data=json.dumps({'phone': '12345'}),
                           content_type='application/json')
        assert resp.status_code == 400

    @patch('app.services.auth_service.check_otp_rate_limit', return_value=True)
    @patch('app.services.auth_service.send_otp', return_value={'status': 'pending'})
    @patch('app.models.user_model.find_by_phone', return_value=None)
    def test_valid_phone(self, mock_find, mock_send, mock_rate, client):
        resp = client.post('/api/auth/send-otp',
                           data=json.dumps({'phone': '+201234567890'}),
                           content_type='application/json')
        assert resp.status_code == 200
        data = json.loads(resp.data)
        assert data['status'] == 'ok'

    @patch('app.services.auth_service.check_otp_rate_limit', return_value=False)
    def test_rate_limited(self, mock_rate, client):
        resp = client.post('/api/auth/send-otp',
                           data=json.dumps({'phone': '+201234567890'}),
                           content_type='application/json')
        assert resp.status_code == 429


class TestVerifyOTP:
    @patch('app.services.auth_service.check_verify_rate_limit', return_value=True)
    @patch('app.services.auth_service.verify_otp', return_value=True)
    @patch('app.services.auth_service.generate_token', return_value='test-jwt-token')
    @patch('app.models.user_model.find_by_phone')
    @patch('app.models.audit_model.log_action')
    def test_successful_verify_existing_user(self, mock_audit, mock_find, mock_gen, mock_verify, mock_rate, client):
        user_doc = {
            '_id': ObjectId(),
            'phone': '+201234567890',
            'name': 'Test',
            'language': 'ar',
            'role': 'farmer',
            'farms': [],
            'created_at': None,
        }
        mock_find.return_value = user_doc

        resp = client.post('/api/auth/verify-otp',
                           data=json.dumps({'phone': '+201234567890', 'code': '123456'}),
                           content_type='application/json')
        assert resp.status_code == 200
        data = json.loads(resp.data)
        assert 'token' in data['data']

    @patch('app.services.auth_service.check_verify_rate_limit', return_value=True)
    @patch('app.services.auth_service.verify_otp', return_value=False)
    def test_invalid_otp(self, mock_verify, mock_rate, client):
        resp = client.post('/api/auth/verify-otp',
                           data=json.dumps({'phone': '+201234567890', 'code': '000000'}),
                           content_type='application/json')
        assert resp.status_code == 401


class TestProfile:
    def test_get_profile_unauthenticated(self, client):
        resp = client.get('/api/auth/me')
        assert resp.status_code == 401
