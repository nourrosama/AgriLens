"""
Firebase Storage service â€” uploads and manages images/scans.
Falls back to local disk when Firebase creds are not configured.
"""
import os
import uuid
import logging
from flask import current_app

logger = logging.getLogger(__name__)

_bucket = None


def init_storage(app):
    """Initialise Firebase Storage bucket."""
    global _bucket
    creds_path = app.config.get('FIREBASE_CREDENTIALS_PATH', '')
    bucket_name = app.config.get('FIREBASE_STORAGE_BUCKET', '')

    if creds_path and bucket_name and os.path.exists(creds_path):
        try:
            import firebase_admin
            from firebase_admin import credentials, storage
            if not firebase_admin._apps:
                cred = credentials.Certificate(creds_path)
                firebase_admin.initialize_app(cred, {'storageBucket': bucket_name})
            _bucket = storage.bucket()
            app.logger.info(f'Firebase Storage initialised with bucket: {_bucket.name}')
        except Exception as e:
            app.logger.warning(f'Firebase init failed: {e}. Using local storage.')
            _bucket = None
    else:
        app.logger.info('Firebase not configured. Using local file storage.')


def is_firebase_ready() -> bool:
    """Return True when Firebase Storage is configured and initialized."""
    return _bucket is not None


def upload_image(file_obj, filename: str = None) -> str:
    """Upload an image file. Returns the public/local URL.

    - If Firebase is configured â†’ uploads to Firebase Storage.
    - Else â†’ saves to local uploads/ folder.
    """
    if filename is None:
        ext = _get_extension(file_obj.filename) or 'jpg'
        filename = f'scans/{uuid.uuid4().hex}.{ext}'

    if _bucket:
        try:
            if hasattr(file_obj, 'stream'):
                file_obj.stream.seek(0)
            blob = _bucket.blob(filename)
            blob.upload_from_file(file_obj, content_type=file_obj.content_type)
            blob.make_public()
            logger.info(f'Uploaded to Firebase: {blob.public_url}')
            return blob.public_url
        except Exception as e:
            logger.warning(f'Firebase image upload failed: {e}. Falling back to local storage.')

    return _save_locally(file_obj, default_ext='jpg')


def delete_image(url: str) -> bool:
    """Delete an image by URL."""
    if _bucket and url.startswith('http'):
        try:
            # Extract blob name from URL
            blob_name = url.split(f'{_bucket.name}/')[-1]
            _bucket.blob(blob_name).delete()
            return True
        except Exception as e:
            logger.warning(f'Failed to delete from Firebase: {e}')
            return False
    else:
        # Local delete
        if url.startswith('/uploads/'):
            path = os.path.join(current_app.config.get('UPLOAD_FOLDER', 'uploads'), url.split('/')[-1])
            if os.path.exists(path):
                os.remove(path)
                return True
    return False


def upload_video(file_obj, filename: str = None) -> str:
    """Upload a video file. Returns the public/local URL.

    - If Firebase is configured -> uploads to Firebase Storage.
    - Else -> saves to local uploads/ folder.
    """
    if filename is None:
        ext = _get_extension(file_obj.filename) or 'mp4'
        filename = f'videos/{uuid.uuid4().hex}.{ext}'

    if _bucket:
        try:
            if hasattr(file_obj, 'stream'):
                file_obj.stream.seek(0)
            blob = _bucket.blob(filename)
            blob.upload_from_file(file_obj, content_type=file_obj.content_type)
            blob.make_public()
            logger.info(f'Uploaded video to Firebase: {blob.public_url}')
            return blob.public_url
        except Exception as e:
            logger.warning(f'Firebase video upload failed: {e}. Falling back to local storage.')

    return _save_locally(file_obj, default_ext='mp4')


def resolve_local_path(url: str) -> str | None:
    """Resolve a local upload URL to an on-disk path."""
    if not url.startswith('/uploads/'):
        return None
    filename = url.split('/')[-1]
    return os.path.join(current_app.config.get('UPLOAD_FOLDER', 'uploads'), filename)


def _get_extension(filename: str) -> str:
    if filename and '.' in filename:
        return filename.rsplit('.', 1)[1].lower()
    return ''


def _save_locally(file_obj, default_ext: str) -> str:
    """Persist an uploaded file to the local uploads directory."""
    upload_dir = current_app.config.get('UPLOAD_FOLDER', 'uploads')
    os.makedirs(upload_dir, exist_ok=True)
    local_name = f'{uuid.uuid4().hex}.{_get_extension(file_obj.filename) or default_ext}'
    path = os.path.join(upload_dir, local_name)
    if hasattr(file_obj, 'stream'):
        file_obj.stream.seek(0)
    file_obj.save(path)
    logger.info(f'Saved locally: {path}')
    return f'/uploads/{local_name}'
