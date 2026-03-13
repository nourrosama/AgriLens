"""
Tests for farm CRUD endpoints.
"""
import pytest
import json
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
    """Generate a valid JWT for testing."""
    import jwt
    from datetime import datetime, timedelta, timezone
    user_id = str(ObjectId())
    token = jwt.encode(
        {'sub': user_id, 'iat': datetime.now(timezone.utc),
         'exp': datetime.now(timezone.utc) + timedelta(hours=1)},
        app.config['JWT_SECRET'], algorithm='HS256',
    )
    return {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, user_id


class TestFarmCRUD:
    @patch('app.models.user_model.find_by_id')
    @patch('app.models.farm_model.create_farm')
    @patch('app.models.user_model.add_farm_ref')
    @patch('app.services.cache.delete')
    @patch('app.models.audit_model.log_action')
    def test_create_farm(self, mock_audit, mock_cache, mock_ref, mock_create, mock_find, client, auth_headers):
        headers, user_id = auth_headers
        farm_id = ObjectId()
        mock_find.return_value = {'_id': ObjectId(user_id), 'phone': '+201234567890',
                                  'name': 'Test', 'role': 'farmer', 'language': 'ar', 'farms': []}
        mock_create.return_value = {
            '_id': farm_id, 'owner_id': ObjectId(user_id), 'name': 'My Farm',
            'location': {}, 'fields': [], 'created_at': None, 'updated_at': None,
        }

        resp = client.post('/api/farms',
                           data=json.dumps({'name': 'My Farm'}),
                           headers=headers)
        assert resp.status_code == 201

    def test_create_farm_unauthenticated(self, client):
        resp = client.post('/api/farms',
                           data=json.dumps({'name': 'Test'}),
                           content_type='application/json')
        assert resp.status_code == 401

    @patch('app.models.user_model.find_by_id')
    @patch('app.models.farm_model.get_farms_by_owner', return_value=[])
    @patch('app.services.cache.get', return_value=None)
    @patch('app.services.cache.set')
    def test_list_farms_empty(self, mock_set, mock_get, mock_farms, mock_find, client, auth_headers):
        headers, user_id = auth_headers
        mock_find.return_value = {'_id': ObjectId(user_id), 'phone': '+201234567890',
                                  'name': 'Test', 'role': 'farmer', 'language': 'ar', 'farms': []}

        resp = client.get('/api/farms', headers=headers)
        assert resp.status_code == 200
        data = json.loads(resp.data)
        assert data['data']['farms'] == []
