"""
Scan model -- MongoDB CRUD for image/video scans and detection results.
Status lifecycle: pending -> processing -> completed | failed | expired
"""
from datetime import datetime, timezone

from bson import ObjectId

from app.models.db import scans_col

VALID_STATUSES = ('pending', 'processing', 'completed', 'failed', 'expired')


def create_scan(
    user_id: str,
    farm_id: str = None,
    field_id: str = None,
    media_url: str = '',
    image_url: str = '',
    storage_backend: str = 'local',
    scan_type: str = 'image',
    crop_type: str = '',
    media_type: str = 'image',
    device_info: dict = None,
) -> dict:
    """Create a new scan record with status='pending'."""
    doc = {
        'user_id': ObjectId(user_id),
        'farm_id': ObjectId(farm_id) if farm_id else None,
        'field_id': ObjectId(field_id) if field_id else None,
        'media_url': media_url or image_url,
        'image_url': image_url or media_url,
        'storage_backend': storage_backend,
        'scan_type': scan_type,       # image | video
        'crop_type': crop_type,
        'media_type': media_type,     # image | video
        'status': 'pending',
        'detection_result': None,
        'device_info': device_info or {},
        'created_at': datetime.now(timezone.utc),
        'updated_at': datetime.now(timezone.utc),
    }
    result = scans_col().insert_one(doc)
    doc['_id'] = result.inserted_id
    return doc


def update_status(scan_id: str, status: str) -> bool:
    """Transition scan status."""
    if status not in VALID_STATUSES:
        raise ValueError(f'Invalid status: {status}')
    result = scans_col().update_one(
        {'_id': ObjectId(scan_id)},
        {'$set': {'status': status, 'updated_at': datetime.now(timezone.utc)}},
    )
    return result.modified_count > 0


def update_detection_result(scan_id: str, detection: dict) -> bool:
    """Store detection result and mark scan completed."""
    result = scans_col().update_one(
        {'_id': ObjectId(scan_id)},
        {'$set': {
            'detection_result': detection,
            'status': 'completed',
            'updated_at': datetime.now(timezone.utc),
        }},
    )
    return result.modified_count > 0


def update_scan(scan_id: str, updates: dict) -> bool:
    """Update arbitrary scan fields."""
    updates = dict(updates)
    updates['updated_at'] = datetime.now(timezone.utc)
    result = scans_col().update_one(
        {'_id': ObjectId(scan_id)},
        {'$set': updates},
    )
    return result.modified_count > 0


def get_scan_by_id(scan_id: str) -> dict | None:
    return scans_col().find_one({'_id': ObjectId(scan_id)})


def get_scans_by_user(user_id: str, page: int = 1, per_page: int = 20) -> list:
    """Paginated list of scans for a user, newest first."""
    return get_scans_filtered(user_id, page=page, per_page=per_page)


def count_scans_by_user(user_id: str) -> int:
    """Return the total number of scans for a user (no pagination)."""
    return scans_col().count_documents({'user_id': ObjectId(user_id)})


def get_scans_by_farm(farm_id: str, page: int = 1, per_page: int = 20) -> list:
    skip = (page - 1) * per_page
    return list(
        scans_col()
        .find({'farm_id': ObjectId(farm_id)})
        .sort('created_at', -1)
        .skip(skip)
        .limit(per_page)
    )


def get_scans_by_crop(user_id: str, crop_type: str, page: int = 1, per_page: int = 20) -> list:
    """Filter scans by crop type for a given user."""
    return get_scans_filtered(user_id, crop_type=crop_type, page=page, per_page=per_page)


def get_scans_filtered(
    user_id: str,
    farm_id: str = None,
    field_id: str = None,
    crop_type: str = '',
    page: int = 1,
    per_page: int = 20,
) -> list:
    """Paginated scan list for a user with optional farm, field, and crop filters."""
    skip = (page - 1) * per_page
    query = {'user_id': ObjectId(user_id)}
    if farm_id:
        query['farm_id'] = ObjectId(farm_id)
    if field_id:
        query['field_id'] = ObjectId(field_id)
    if crop_type:
        query['crop_type'] = crop_type
    return list(
        scans_col()
        .find(query)
        .sort('created_at', -1)
        .skip(skip)
        .limit(per_page)
    )


def serialize(scan: dict) -> dict:
    """Convert scan document to JSON-safe dict."""
    if scan is None:
        return None
    det = scan.get('detection_result')
    media_url = scan.get('media_url') or scan.get('image_url', '')
    image_url = scan.get('image_url') or media_url
    storage_backend = scan.get('storage_backend') or _infer_storage_backend(media_url)
    return {
        'id': str(scan['_id']),
        'user_id': str(scan.get('user_id', '')),
        'farm_id': str(scan['farm_id']) if scan.get('farm_id') else None,
        'field_id': str(scan['field_id']) if scan.get('field_id') else None,
        'media_url': media_url,
        'image_url': image_url,
        'storage_backend': storage_backend,
        'scan_type': scan.get('scan_type', 'image'),
        'crop_type': scan.get('crop_type', ''),
        'media_type': scan.get('media_type', 'image'),
        'status': scan.get('status', 'pending'),
        'detection_result': det,
        'device_info': scan.get('device_info', {}),
        'created_at': scan.get('created_at', '').isoformat() if scan.get('created_at') else None,
        'updated_at': scan.get('updated_at', '').isoformat() if scan.get('updated_at') else None,
    }


def _infer_storage_backend(media_url: str) -> str:
    if not media_url or media_url.startswith('/uploads/'):
        return 'local'
    if 'res.cloudinary.com' in media_url:
        return 'cloudinary'
    if media_url.startswith('http://') or media_url.startswith('https://'):
        return 'remote'
    return 'local'
