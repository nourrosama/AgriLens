"""
Scan media storage service.
Supports Cloudinary or explicit local-disk storage.
"""
from contextlib import contextmanager
from io import BytesIO
import logging
import os
import re
import tempfile
import uuid
from urllib.parse import urlparse

import cloudinary
import cloudinary.uploader
from flask import current_app
import requests

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


def upload_video_from_path(file_path: str) -> str:
    """Upload a video that is already on disk to Cloudinary and return the URL.

    Designed for background-thread calls where a 300 s timeout is acceptable.
    Avoids Docker SSL write-timeout issues that occur when uploading large files
    on the main request thread.
    """
    if not _cloudinary_ready:
        raise RuntimeError('Cloudinary storage is not ready')

    public_id = f'agrilens/scans/videos/{uuid.uuid4().hex}'
    file_size = os.path.getsize(file_path)

    if file_size < 95 * 1024 * 1024:
        result = cloudinary.uploader.upload(
            file_path,
            public_id=public_id,
            resource_type='video',
            overwrite=True,
            timeout=None,  # background thread — no user waiting
        )
    else:
        result = cloudinary.uploader.upload_large(
            file_path,
            public_id=public_id,
            resource_type='video',
            overwrite=True,
            chunk_size=4 * 1024 * 1024,
            timeout=None,  # background thread — no user waiting
        )

    url = result.get('secure_url') or result.get('url')
    if not url:
        raise RuntimeError('Cloudinary upload did not return a public URL')
    logger.info('Uploaded video to Cloudinary (background): %s', url)
    return url


def upload_scan_frame_bytes(data: bytes, scan_id: str, frame_index: int) -> str:
    """Persist a generated selected video frame and return its URL/path."""
    return _upload_bytes(
        data,
        folder=f'agrilens/scans/frames/{scan_id}',
        default_ext='jpg',
        resource_type='image',
        filename=f'frame_{frame_index:04d}',
    )


def upload_scan_gradcam_bytes(data: bytes, scan_id: str, frame_index: int) -> str:
    """Persist a generated Grad-CAM frame image and return its URL/path."""
    return _upload_bytes(
        data,
        folder=f'agrilens/scans/gradcam/{scan_id}',
        default_ext='jpg',
        resource_type='image',
        filename=f'frame_{frame_index:04d}_gradcam',
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


@contextmanager
def materialize_media(media_url: str, default_ext: str = ''):
    """Yield a local file path for local or remote media, deleting temp downloads."""
    local_path = resolve_local_path(media_url)
    if local_path and os.path.exists(local_path):
        yield local_path
        return

    if not (media_url.startswith('http://') or media_url.startswith('https://')):
        yield media_url
        return

    parsed = urlparse(media_url)
    ext = os.path.splitext(parsed.path)[1] or default_ext
    temp_path = ''
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as temp_file:
            temp_path = temp_file.name
            with requests.get(
                media_url,
                stream=True,
                timeout=current_app.config.get('CLOUDINARY_UPLOAD_TIMEOUT', 30),
            ) as response:
                response.raise_for_status()
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if chunk:
                        temp_file.write(chunk)
        yield temp_path
    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)


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
            # Write to a temp file first so we know the exact size.
            video_timeout = current_app.config.get('CLOUDINARY_VIDEO_UPLOAD_TIMEOUT', 120)
            with tempfile.NamedTemporaryFile(suffix=f'.{ext}', delete=False) as tmp:
                tmp_path = tmp.name
                if hasattr(stream, 'read'):
                    tmp.write(stream.read())
                else:
                    tmp.write(stream)
            try:
                file_size = os.path.getsize(tmp_path)
                # Under 95 MB: use a single-request upload to avoid Docker NAT
                # dropping the SSL connection between upload_large chunks.
                # Over 95 MB: chunked upload with smaller 4 MB chunks.
                if file_size < 95 * 1024 * 1024:
                    result = cloudinary.uploader.upload(
                        tmp_path,
                        public_id=public_id,
                        resource_type='video',
                        overwrite=True,
                        timeout=video_timeout,
                    )
                else:
                    result = cloudinary.uploader.upload_large(
                        tmp_path,
                        public_id=public_id,
                        resource_type='video',
                        overwrite=True,
                        chunk_size=4 * 1024 * 1024,  # 4 MB to reduce NAT idle gaps
                        timeout=video_timeout,
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


def _upload_bytes(
    data: bytes,
    folder: str,
    default_ext: str,
    resource_type: str,
    filename: str = None,
) -> str:
    if uses_local_storage():
        return _save_bytes_locally(data, default_ext=default_ext)

    if not _cloudinary_ready:
        raise RuntimeError('Cloudinary storage is not ready')

    ext = _get_extension(filename or '') or default_ext
    public_id = f'{folder}/{os.path.splitext(filename)[0]}' if filename else f'{folder}/{uuid.uuid4().hex}'

    try:
        result = cloudinary.uploader.upload(
            BytesIO(data),
            public_id=public_id,
            resource_type=resource_type,
            overwrite=True,
            format=ext,
            folder=None,
            timeout=current_app.config.get('CLOUDINARY_UPLOAD_TIMEOUT', 30),
        )
    except Exception as exc:  # pragma: no cover - runtime safety
        logger.warning('Cloudinary generated %s upload failed: %s', resource_type, exc)
        raise

    url = result.get('secure_url') or result.get('url')
    if not url:
        raise RuntimeError('Cloudinary upload did not return a public URL')
    logger.info('Uploaded generated %s media to Cloudinary: %s', resource_type, url)
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


def _save_bytes_locally(data: bytes, default_ext: str) -> str:
    upload_dir = current_app.config.get('UPLOAD_FOLDER', 'uploads')
    os.makedirs(upload_dir, exist_ok=True)
    local_name = f'{uuid.uuid4().hex}.{default_ext}'
    path = os.path.join(upload_dir, local_name)
    with open(path, 'wb') as file_obj:
        file_obj.write(data)
    logger.info('Saved generated media locally: %s', path)
    return f'/uploads/{local_name}'
