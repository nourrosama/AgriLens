"""
Tests for scan upload and listing endpoints.
"""
import pytest
import json
import io
from unittest.mock import patch, MagicMock
from bson import ObjectId


@pytest.fixture
def app():
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


@pytest.fixture
def auth_headers(app):
    import jwt
    from datetime import datetime, timedelta, timezone
    user_id = str(ObjectId())
    token = jwt.encode(
        {'sub': user_id, 'iat': datetime.now(timezone.utc),
         'exp': datetime.now(timezone.utc) + timedelta(hours=1)},
        app.config['JWT_SECRET'], algorithm='HS256',
    )
    return {'Authorization': f'Bearer {token}'}, user_id


class TestScanUpload:
    @patch('app.models.user_model.find_by_id')
    def test_upload_no_image(self, mock_find, client, auth_headers):
        headers, user_id = auth_headers
        mock_find.return_value = {'_id': ObjectId(user_id), 'phone': '+201234567890',
                                  'name': 'Test', 'role': 'farmer', 'language': 'ar', 'farms': []}
        resp = client.post('/api/scans', headers=headers)
        assert resp.status_code == 400

    @patch('app.models.user_model.find_by_id')
    @patch('app.services.storage_service.upload_image', return_value='/uploads/test.jpg')
    @patch('app.models.scan_model.create_scan')
    @patch('app.observers.event_publisher.scan_created')
    @patch('app.models.audit_model.log_action')
    def test_upload_success(self, mock_audit, mock_event, mock_create, mock_upload, mock_find, client, auth_headers):
        headers, user_id = auth_headers
        mock_find.return_value = {'_id': ObjectId(user_id), 'phone': '+201234567890',
                                  'name': 'Test', 'role': 'farmer', 'language': 'ar', 'farms': []}
        scan_id = ObjectId()
        mock_create.return_value = {
            '_id': scan_id, 'user_id': ObjectId(user_id), 'farm_id': None,
            'field_id': None, 'image_url': '/uploads/test.jpg',
            'scan_type': 'image', 'status': 'pending',
            'detection_result': None, 'device_info': {}, 'created_at': None,
        }

        data = {'image': (io.BytesIO(b'fake image data'), 'test.jpg')}
        resp = client.post('/api/scans', headers=headers, data=data,
                           content_type='multipart/form-data')
        assert resp.status_code == 201


class TestScanListing:
    def test_list_unauthenticated(self, client):
        resp = client.get('/api/scans')
        assert resp.status_code == 401

    @patch('app.models.user_model.find_by_id')
    @patch('app.models.scan_model.get_scans_by_user', return_value=[])
    def test_list_empty(self, mock_scans, mock_find, client, auth_headers):
        headers, user_id = auth_headers
        mock_find.return_value = {'_id': ObjectId(user_id), 'phone': '+201234567890',
                                  'name': 'Test', 'role': 'farmer', 'language': 'ar', 'farms': []}
        resp = client.get('/api/scans', headers=headers)
        assert resp.status_code == 200
