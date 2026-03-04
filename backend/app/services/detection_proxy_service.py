"""
Detection proxy — forwards images to the detection-service microservice.
"""
import logging
import requests
from flask import current_app

logger = logging.getLogger(__name__)


def detect(image_path_or_url: str) -> dict | None:
    """Send image to detection service and return parsed result.

    Returns dict with: disease, confidence, severity, is_healthy, bbox,
    risk_level, recommendation, model_version  — or None on failure.
    """
    base = current_app.config.get('DETECTION_SERVICE_URL', 'http://localhost:5001')
    url = f'{base}/api/detect'

    try:
        # If local file, send as multipart
        if image_path_or_url.startswith('/') or image_path_or_url.startswith('uploads'):
            with open(image_path_or_url, 'rb') as f:
                resp = requests.post(url, files={'image': f}, timeout=30)
        else:
            # Remote URL — send as JSON
            resp = requests.post(url, json={'image_url': image_path_or_url}, timeout=30)

        if resp.status_code == 200:
            return resp.json()
        else:
            logger.warning(f'Detection service returned {resp.status_code}: {resp.text}')
            return None
    except requests.ConnectionError:
        logger.error('Detection service unreachable')
        return None
    except Exception as e:
        logger.error(f'Detection proxy error: {e}')
        return None
