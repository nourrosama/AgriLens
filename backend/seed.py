"""
Seed script — populates MongoDB with sample data for development.
Run: python seed.py
"""
import os
import sys
from datetime import datetime, timezone
from bson import ObjectId
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()

MONGO_URI = os.getenv('MONGO_URI', 'mongodb://localhost:27017/agrilens')
client = MongoClient(MONGO_URI)
db = client.get_default_database()


def seed():
    print('🌱 Seeding AgriLens database...')

    # ── Clear existing data ───────────────────────────────────
    db.users.delete_many({})
    db.farms.delete_many({})
    db.scans.delete_many({})
    db.audit_logs.delete_many({})

    # ── Demo User ─────────────────────────────────────────────
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
    print(f'  ✅ User created: +201234567890 (id: {user_id})')

    # ── Demo Farm ─────────────────────────────────────────────
    farm_id = ObjectId()
    field_a_id = ObjectId()
    field_b_id = ObjectId()
    db.farms.insert_one({
        '_id': farm_id,
        'owner_id': user_id,
        'name': 'المزرعة الرئيسية',
        'location': {'lat': 30.0444, 'lng': 31.2357},
        'fields': [
            {
                'field_id': field_a_id,
                'name': 'الحقل أ',
                'crop_type': 'tomato',
                'area_hectares': 2.5,
            },
            {
                'field_id': field_b_id,
                'name': 'الحقل ب',
                'crop_type': 'potato',
                'area_hectares': 1.8,
            },
        ],
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    })
    db.users.update_one({'_id': user_id}, {'$push': {'farms': farm_id}})
    print(f'  ✅ Farm created: المزرعة الرئيسية (id: {farm_id})')

    # ── Demo Scans ────────────────────────────────────────────
    scan1_id = ObjectId()
    db.scans.insert_one({
        '_id': scan1_id,
        'user_id': user_id,
        'farm_id': farm_id,
        'field_id': field_a_id,
        'image_url': '/uploads/sample_tomato_leaf.jpg',
        'scan_type': 'image',
        'status': 'completed',
        'detection_result': {
            'disease': 'Tomato___Early_blight',
            'confidence': 0.92,
            'severity': 'medium',
            'is_healthy': False,
            'bbox': [45, 60, 210, 190],
            'risk_level': 'medium',
            'recommendation': 'Apply copper-based fungicide within 72 hours',
            'model_version': 'v1.0.0',
        },
        'device_info': {
            'device_type': 'mobile',
            'app_version': '1.0.0',
        },
        'created_at': datetime.now(timezone.utc),
    })

    scan2_id = ObjectId()
    db.scans.insert_one({
        '_id': scan2_id,
        'user_id': user_id,
        'farm_id': farm_id,
        'field_id': field_b_id,
        'image_url': '/uploads/sample_healthy_leaf.jpg',
        'scan_type': 'image',
        'status': 'completed',
        'detection_result': {
            'disease': 'Tomato___healthy',
            'confidence': 0.98,
            'severity': 'none',
            'is_healthy': True,
            'bbox': [30, 40, 200, 180],
            'risk_level': 'low',
            'recommendation': 'No action needed — plant is healthy',
            'model_version': 'v1.0.0',
        },
        'device_info': {
            'device_type': 'mobile',
            'app_version': '1.0.0',
        },
        'created_at': datetime.now(timezone.utc),
    })
    print(f'  ✅ 2 scans created')

    # ── Researcher user ───────────────────────────────────────
    researcher_id = ObjectId()
    db.users.insert_one({
        '_id': researcher_id,
        'phone': '+201098765432',
        'name': 'Dr. Researcher',
        'language': 'en',
        'role': 'researcher',
        'farms': [],
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    })
    print(f'  ✅ Researcher user created: +201098765432')

    print('\n🎉 Seed complete! Database ready for development.')
    print(f'   Demo farmer phone: +201234567890')
    print(f'   Demo researcher phone: +201098765432')
    print(f'   Mock OTP code: 123456')


if __name__ == '__main__':
    seed()
