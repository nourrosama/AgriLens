"""
Seed script -- populates MongoDB with sample data for development.
Run: python seed.py
"""
import os
import sys
from datetime import datetime, timezone

from bson import ObjectId
from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.errors import ConfigurationError

load_dotenv()

MONGO_URI = os.getenv('MONGO_URI', '').strip()
if not MONGO_URI:
    raise RuntimeError('MONGO_URI is required. Set your Atlas connection string in backend/.env.')

client = MongoClient(MONGO_URI)
try:
    db = client.get_default_database()
except ConfigurationError:
    db = client['agrilens']


def seed():
    print('Seeding AgriLens database...')

    db.users.delete_many({})
    db.farms.delete_many({})
    db.scans.delete_many({})
    db.audit_logs.delete_many({})

    user_id = ObjectId()
    db.users.insert_one({
        '_id': user_id,
        'phone': '+201234567890',
        'name': 'Ahmed (Demo)',
        'language': 'ar',
        'role': 'farmer',
        'farms': [],
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    })
    print(f'User created: +201234567890 (id: {user_id})')

    farm_id = ObjectId()
    field_id = ObjectId()
    db.farms.insert_one({
        '_id': farm_id,
        'owner_id': user_id,
        'name': 'Demo Farm',
        'location': {'label': 'Giza', 'lat': 29.987, 'lng': 31.2118},
        'fields': [{
            'field_id': field_id,
            'name': 'Tomato Field A',
            'crop_type': 'tomato',
            'location': {'label': 'North Plot', 'lat': 29.987, 'lng': 31.2118},
            'area_hectares': 1.2,
            'soil_type': 'loamy',
            'irrigation_type': 'drip',
            'season': 'spring',
            'health_score': 82,
            'risk_level': 'medium',
        }],
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    })
    print(f'Farm created: Demo Farm (id: {farm_id})')

    db.scans.insert_one({
        'user_id': user_id,
        'farm_id': farm_id,
        'field_id': field_id,
        'media_url': '/uploads/demo-tomato.jpg',
        'image_url': '/uploads/demo-tomato.jpg',
        'storage_backend': 'local',
        'scan_type': 'image',
        'crop_type': 'tomato',
        'media_type': 'image',
        'status': 'completed',
        'detection_result': {
            'crop_type': 'tomato',
            'disease': 'Early blight',
            'scientific_name': 'Alternaria solani',
            'confidence': 0.91,
            'severity': 'medium',
            'is_healthy': False,
            'risk_level': 'medium',
            'recommendation': 'Remove affected leaves and monitor humidity closely.',
            'model_version': 'demo-seed',
        },
        'device_info': {'device_type': 'seed', 'app_version': '1.0.0'},
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    })
    print('Scan created')

    print(f'Seed completed in database: {db.name}')


if __name__ == '__main__':
    try:
        seed()
    except Exception as exc:
        print(f'Seed failed: {exc}')
        sys.exit(1)
