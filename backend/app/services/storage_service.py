"""
Scan media storage service.
Supports Cloudinary or explicit local-disk storage.
"""
import logging
import os
import re
import tempfile
import uuid
from urllib.parse import urlparse

import cloudinary
import cloudinary.uploader
from flask import current_app

logger = logging.getLogger(__name__)

_provider = 'local'
_cloudinary_ready = False


def init_storage(app):
    """Initialise the configured scan media storage backend."""
    global _provider, _cloudinary_ready

    _provider = (app.config.get('MEDIA_STORAGE_PROVIDER', 'local') or 'local').strip().lower()
    _cloudinary_ready = False

    if _provider == 'cloudinary':
        cloud_name = app.config.get('CLOUDINARY_CLOUD_NAME', '')
        api_key = app.config.get('CLOUDINARY_API_KEY', '')
        api_secret = app.config.get('CLOUDINARY_API_SECRET', '')
        if not (cloud_name and api_key and api_secret):
            app.logger.warning(
                'Cloudinary storage is selected but credentials are incomplete. '
                'Scan uploads will fail until CLOUDINARY_* vars are set.',
            )
            return

        cloudinary.config(
            cloud_name=cloud_name,
            api_key=api_key,
            api_secret=api_secret,
            secure=True,
        )
        _cloudinary_ready = True
        app.logger.info('Cloudinary scan storage initialized for cloud=%s', cloud_name)
        return

    os.makedirs(app.config.get('UPLOAD_FOLDER', 'uploads'), exist_ok=True)
    app.logger.info(
        'Local scan media storage enabled at %s',
        app.config.get('UPLOAD_FOLDER', 'uploads'),
    )


def uses_local_storage() -> bool:
    return _provider == 'local'


def get_storage_backend() -> str:
    return _provider


def is_cloudinary_ready() -> bool:
    return _provider == 'cloudinary' and _cloudinary_ready


def get_storage_status() -> dict:
    """Expose runtime media-storage state for health checks."""
    ready = uses_local_storage() or is_cloudinary_ready()
    return {
        'provider': _provider,
        'ready': ready,
        'cloudinary_ready': is_cloudinary_ready(),
        'local_storage_enabled': uses_local_storage(),
    }


def upload_image(file_obj, filename: str = None) -> str:
    """Upload an image file and return the public URL/path."""
    return _upload_media(
        file_obj,
        folder='agrilens/scans/images',
        default_ext='jpg',
        resource_type='image',
        filename=filename,
    )


def upload_profile_image(file_obj, filename: str = None) -> str:
    """Upload a profile image and return the public URL/path."""
    return _upload_media(
        file_obj,
        folder='agrilens/profiles',
        default_ext='jpg',
        resource_type='image',
        filename=filename,
    )


def upload_video(file_obj, filename: str = None) -> str:
    """Upload a video file and return the public URL/path."""
    return _upload_media(
        file_obj,
        folder='agrilens/scans/videos',
        default_ext='mp4',
        resource_type='video',
        filename=filename,
    )


def delete_image(url: str) -> bool:
    """Delete stored media by URL/path."""
    if not url:
        return False

    if url.startswith('/uploads/'):
        path = resolve_local_path(url)
        if path and os.path.exists(path):
            os.remove(path)
            return True
        return False

    if _provider != 'cloudinary' or not _cloudinary_ready:
        return False

    public_id, resource_type = _cloudinary_public_id(url)
    if not public_id:
        return False

    try:
        result = cloudinary.uploader.destroy(
            public_id,
            resource_type=resource_type,
            invalidate=True,
        )
        return result.get('result') in {'ok', 'not found'}
    except Exception as exc:  # pragma: no cover - runtime safety
        logger.warning('Failed to delete Cloudinary media %s: %s', url, exc)
        return False


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


def _upload_media(file_obj, folder: str, default_ext: str, resource_type: str, filename: str = None) -> str:
    if uses_local_storage():
        return _save_locally(file_obj, default_ext=default_ext)

    if not _cloudinary_ready:
        raise RuntimeError('Cloudinary storage is not ready')

    ext = _get_extension(getattr(file_obj, 'filename', '')) or default_ext
    if filename:
        public_id = os.path.splitext(filename.replace('\\', '/'))[0]
    else:
        public_id = f'{folder}/{uuid.uuid4().hex}'

    stream = getattr(file_obj, 'stream', file_obj)
    if hasattr(stream, 'seek'):
        stream.seek(0)

    upload_timeout = current_app.config.get('CLOUDINARY_UPLOAD_TIMEOUT', 30)

    try:
        if resource_type == 'video':
            # upload_large needs a real file path for reliable chunked transfer
            with tempfile.NamedTemporaryFile(suffix=f'.{ext}', delete=False) as tmp:
                tmp_path = tmp.name
                if hasattr(stream, 'read'):
                    tmp.write(stream.read())
                else:
                    tmp.write(stream)
            try:
                result = cloudinary.uploader.upload_large(
                    tmp_path,
                    public_id=public_id,
                    resource_type='video',
                    overwrite=False,
                    format=ext,
                    chunk_size=6 * 1024 * 1024,  # 6 MB chunks
                    timeout=60,
                )
            finally:
                try:
                    os.unlink(tmp_path)
                except OSError:
                    pass
        else:
            result = cloudinary.uploader.upload(
                stream,
                public_id=public_id,
                resource_type=resource_type,
                overwrite=False,
                format=ext,
                folder=None,
                timeout=upload_timeout,
            )
    except Exception as exc:  # pragma: no cover - runtime safety
        logger.warning('Cloudinary %s upload failed: %s', resource_type, exc)
        raise

    url = result.get('secure_url') or result.get('url')
    if not url:
        raise RuntimeError('Cloudinary upload did not return a public URL')
    logger.info('Uploaded %s media to Cloudinary: %s', resource_type, url)
    return url


def _cloudinary_public_id(url: str) -> tuple[str | None, str]:
    parsed = urlparse(url)
    parts = [part for part in parsed.path.split('/') if part]
    if 'upload' not in parts:
        return None, 'image'

    upload_index = parts.index('upload')
    resource_type = parts[upload_index - 1] if upload_index >= 1 else 'image'
    remainder = parts[upload_index + 1:]
    if remainder and re.fullmatch(r'v\d+', remainder[0]):
        remainder = remainder[1:]
    if not remainder:
        return None, resource_type

    remainder[-1] = os.path.splitext(remainder[-1])[0]
    return '/'.join(remainder), resource_type


def _save_locally(file_obj, default_ext: str) -> str:
    """Persist an uploaded file to the local uploads directory."""
    upload_dir = current_app.config.get('UPLOAD_FOLDER', 'uploads')
    os.makedirs(upload_dir, exist_ok=True)
    local_name = f'{uuid.uuid4().hex}.{_get_extension(file_obj.filename) or default_ext}'
    path = os.path.join(upload_dir, local_name)
    if hasattr(file_obj, 'stream'):
        file_obj.stream.seek(0)
    file_obj.save(path)
    logger.info('Saved locally: %s', path)
    return f'/uploads/{local_name}'
