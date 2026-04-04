"""
Storage service — uploads images/videos to Cloudinary.
Falls back to local disk when Cloudinary creds are not configured.
"""
import os
import uuid
import logging
from flask import current_app

logger = logging.getLogger(__name__)

_cloudinary_configured = False


def init_storage(app):
    """Initialise Cloudinary."""
    global _cloudinary_configured

    cloud_name = app.config.get('CLOUDINARY_CLOUD_NAME', '')
    api_key = app.config.get('CLOUDINARY_API_KEY', '')
    api_secret = app.config.get('CLOUDINARY_API_SECRET', '')

    if cloud_name and api_key and api_secret:
        try:
            import cloudinary
            cloudinary.config(
                cloud_name=cloud_name,
                api_key=api_key,
                api_secret=api_secret,
                secure=True
            )
            _cloudinary_configured = True
            app.logger.info('✅ Cloudinary Storage initialised')
        except Exception as e:
            app.logger.warning(f'⚠️  Cloudinary init failed: {e} — using local storage')
    else:
        app.logger.info('ℹ️  Cloudinary not configured — using local file storage')


def upload_image(file_obj, filename: str = None) -> str:
    """Upload an image file. Returns the public URL."""
    if _cloudinary_configured:
        try:
            import cloudinary.uploader
            public_id = f'agrilens/scans/{uuid.uuid4().hex}'
            result = cloudinary.uploader.upload(
                file_obj,
                public_id=public_id,
                resource_type='auto',
                folder='agrilens'
            )
            url = result.get('secure_url')
            logger.info(f'Uploaded to Cloudinary: {url}')
            return url
        except Exception as e:
            logger.warning(f'Cloudinary upload failed: {e} — falling back to local')

    # Local fallback
    upload_dir = current_app.config.get('UPLOAD_FOLDER', 'uploads')
    os.makedirs(upload_dir, exist_ok=True)
    ext = _get_extension(file_obj.filename) if hasattr(file_obj, 'filename') else 'jpg'
    local_name = f'{uuid.uuid4().hex}.{ext or "jpg"}'
    path = os.path.join(upload_dir, local_name)
    file_obj.save(path)
    logger.info(f'Saved locally: {path}')
    return f'/uploads/{local_name}'


def delete_image(url: str) -> bool:
    """Delete an image by URL."""
    if _cloudinary_configured and url.startswith('https://res.cloudinary.com'):
        try:
            import cloudinary.uploader
            public_id = url.split('/')[-1].split('.')[0]
            cloudinary.uploader.destroy(f'agrilens/{public_id}')
            return True
        except Exception as e:
            logger.warning(f'Failed to delete from Cloudinary: {e}')
            return False
    else:
        if url.startswith('/uploads/'):
            path = os.path.join(
                current_app.config.get('UPLOAD_FOLDER', 'uploads'),
                url.split('/')[-1]
            )
            if os.path.exists(path):
                os.remove(path)
                return True
    return False

def resolve_local_path(url: str) -> str:
    """Convert a local /uploads/ URL to a filesystem path, or return None for cloud URLs."""
    if url and url.startswith('/uploads/'):
        upload_dir = current_app.config.get('UPLOAD_FOLDER', 'uploads')
        return os.path.join(upload_dir, url.split('/')[-1])
    return None

def _get_extension(filename: str) -> str:
    if filename and '.' in filename:
        return filename.rsplit('.', 1)[1].lower()
    return ''