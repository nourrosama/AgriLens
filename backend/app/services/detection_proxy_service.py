"""
Detection proxy for the crop detection microservice.

Mock fallback is available only when explicitly enabled by configuration.
"""
import hashlib
import json
import logging
import os

import requests
from flask import current_app

logger = logging.getLogger(__name__)


VALIDATION_ERROR_CODES = {'NOT_A_PLANT', 'UNSUPPORTED_CROP', 'CROP_MISMATCH'}


class DetectionValidationError(ValueError):
    """Structured validation failure returned by the detection provider."""

    def __init__(self, payload: dict, status_code: int = 422):
        self.payload = payload
        self.status_code = status_code
        super().__init__(payload.get('message') or payload.get('error') or 'Detection validation failed')


CATALOG = {
    'tomato': [
        {
            'disease': 'Tomato Early Blight',
            'scientific_name': 'Alternaria solani',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Remove affected leaves and start preventive fungicide coverage.',
        },
        {
            'disease': 'Tomato Late Blight',
            'scientific_name': 'Phytophthora infestans',
            'severity': 'high',
            'risk_level': 'high',
            'recommendation': 'Act quickly, isolate infected plants, and reduce leaf wetness.',
        },
        {
            'disease': 'Tomato Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Keep monitoring and maintain balanced irrigation.',
        },
    ],
    'apple': [
        {
            'disease': 'Apple Scab',
            'scientific_name': 'Venturia inaequalis',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Remove infected leaves and fruit debris, improve airflow, and monitor wet conditions.',
        },
        {
            'disease': 'Black Rot',
            'scientific_name': 'Botryosphaeria obtusa',
            'severity': 'high',
            'risk_level': 'high',
            'recommendation': 'Prune infected branches and remove mummified fruit to reduce spread.',
        },
        {
            'disease': 'Apple Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Continue routine monitoring.',
        },
    ],
    'potato': [
        {
            'disease': 'Potato Bacterial Disease',
            'scientific_name': 'Bacterial pathogen',
            'severity': 'high',
            'risk_level': 'high',
            'recommendation': 'Remove infected plants and sanitize tools after field work.',
        },
        {
            'disease': 'Potato Fungal Disease',
            'scientific_name': 'Fungal pathogen',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Improve airflow and avoid overhead irrigation during humid periods.',
        },
        {
            'disease': 'Potato Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Continue routine scouting.',
        },
    ],
    'corn': [
        {
            'disease': 'Corn Leaf Blight',
            'scientific_name': 'Exserohilum turcicum',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Scout neighboring plants and avoid prolonged leaf wetness.',
        },
        {
            'disease': 'Corn Rust',
            'scientific_name': 'Puccinia sorghi',
            'severity': 'low',
            'risk_level': 'low',
            'recommendation': 'Track humidity and monitor lesion spread over the next week.',
        },
        {
            'disease': 'Corn Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Continue routine scouting.',
        },
    ],
    'wheat': [
        {
            'disease': 'Wheat Rust',
            'scientific_name': 'Puccinia triticina',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Monitor canopy humidity and inspect nearby leaves for spread.',
        },
        {
            'disease': 'Powdery Mildew',
            'scientific_name': 'Blumeria graminis',
            'severity': 'low',
            'risk_level': 'low',
            'recommendation': 'Increase airflow and continue monitoring susceptible areas.',
        },
        {
            'disease': 'Wheat Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Maintain balanced nutrition and scouting.',
        },
    ],
    'grape': [
        {
            'disease': 'Grape Black Rot',
            'scientific_name': 'Grape disease',
            'severity': 'high',
            'risk_level': 'high',
            'recommendation': 'Remove infected tissue, improve airflow, and avoid prolonged leaf wetness.',
        },
        {
            'disease': 'Grape Powdery Mildew',
            'scientific_name': 'Grape disease',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Monitor canopy humidity and apply locally recommended treatment if symptoms spread.',
        },
        {
            'disease': 'Grape Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Continue routine vineyard scouting.',
        },
    ],
    'sugarcane': [
        {
            'disease': 'Sugarcane Rust',
            'scientific_name': 'Sugarcane disease',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Inspect nearby leaves, improve airflow, and monitor spread after humid weather.',
        },
        {
            'disease': 'Sugarcane Red Rot',
            'scientific_name': 'Colletotrichum falcatum',
            'severity': 'high',
            'risk_level': 'high',
            'recommendation': 'Remove heavily infected stalks and avoid moving infected plant material.',
        },
        {
            'disease': 'Sugarcane Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Continue routine scouting.',
        },
    ],
    'cotton': [
        {
            'disease': 'Cotton Bacterial Blight',
            'scientific_name': 'Xanthomonas citri pv. malvacearum',
            'severity': 'high',
            'risk_level': 'high',
            'recommendation': 'Remove infected tissue where possible and avoid overhead irrigation.',
        },
        {
            'disease': 'Cotton Curl Virus',
            'scientific_name': 'Cotton leaf curl virus',
            'severity': 'high',
            'risk_level': 'high',
            'recommendation': 'Control whiteflies and separate heavily infected plants from healthy areas.',
        },
        {
            'disease': 'Cotton Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Continue routine field checks.',
        },
    ],
}


def _normalize_crop(crop_type: str) -> str:
    normalized = (crop_type or 'tomato').strip().lower().replace('_', '').replace(' ', '')
    aliases = {
        'apples': 'apple',
        'grapes': 'grape',
        'potatoes': 'potato',
        'sugarcane': 'sugarcane',
        'sugarcanes': 'sugarcane',
        'tomatoes': 'tomato',
    }
    normalized = aliases.get(normalized, normalized)
    return normalized


def _unsupported_crop_payload(crop_type: str) -> dict:
    crop = _normalize_crop(crop_type)
    return {
        'error': 'Unsupported crop type',
        'error_code': 'UNSUPPORTED_CROP',
        'plant_status': 'unsupported_crop',
        'valid': False,
        'selected_crop': crop,
        'detected_crop': crop or 'unknown_plant',
        'supported_crops': list(CATALOG.keys()),
        'message': 'This crop is not supported yet. Please choose one of the supported crops.',
    }


def _mock_gradcam_b64(seed_int: int) -> str:
    """Generate a transparent RGBA Grad-CAM heatmap PNG (stdlib only, no PIL/numpy).

    Produces a 200×200 RGBA PNG with a warm radial hotspot at a seed-dependent
    position.  Alpha is 0 where the leaf is healthy (the real photo shows
    through) and ramps up to ~220 at the hotspot so the disease region is
    clearly highlighted when this is layered over the original scan image.
    """
    import base64, math, struct, zlib  # stdlib only
    W, H = 200, 200

    # ── Hotspot centre (deterministic but varies per scan) ────────────────────
    cx = W * (0.25 + 0.50 * ((seed_int & 0xFF) / 255.0))
    cy = H * (0.25 + 0.50 * (((seed_int >> 8) & 0xFF) / 255.0))
    # Primary hotspot radius
    max_r = min(W, H) * 0.32

    raw_rows = []
    for y in range(H):
        row = bytearray([0])   # PNG filter byte "None"
        for x in range(W):
            dist = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
            t = max(0.0, 1.0 - dist / max_r) ** 1.5   # intensity 0→1

            # Colour: bright yellow core → deep orange rim
            r = min(255, int(255 * min(1.0, t * 1.8)))
            g = min(255, int(200 * max(0.0, t * 1.6 - 0.10)))
            b = min(255, int(30  * max(0.0, t - 0.50)))
            # Alpha: fully transparent outside hotspot, opaque at centre
            a = min(220, int(220 * (t ** 0.6)))

            row += bytes([r, g, b, a])
        raw_rows.append(bytes(row))

    def _chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xFFFFFFFF)

    ihdr = struct.pack('>II', W, H) + bytes([8, 6, 0, 0, 0])   # 8-bit RGBA
    idat = zlib.compress(b''.join(raw_rows), 6)
    png  = b'\x89PNG\r\n\x1a\n' + _chunk(b'IHDR', ihdr) + _chunk(b'IDAT', idat) + _chunk(b'IEND', b'')
    return base64.b64encode(png).decode()


def _mock_detect(image_path_or_url: str, crop_type: str) -> dict:
    crop = _normalize_crop(crop_type)
    if crop not in CATALOG:
        raise DetectionValidationError(_unsupported_crop_payload(crop), 422)
    seed = f"{crop}:{os.path.basename(image_path_or_url)}"
    digest = int(hashlib.md5(seed.encode('utf-8')).hexdigest()[:8], 16)
    disease_options = CATALOG[crop]
    result = disease_options[digest % len(disease_options)]
    confidence = round(0.74 + ((digest >> 4) % 22) / 100, 3)
    return {
        'crop_type': crop,
        'disease': result['disease'],
        'scientific_name': result['scientific_name'],
        'confidence': confidence,
        'severity': result['severity'],
        'is_healthy': result['severity'] == 'none',
        'risk_level': result['risk_level'],
        'recommendation': result['recommendation'],
        'model_version': 'mock-fallback-v1',
        'gradcam_overlay': _mock_gradcam_b64(digest),
    }


def _mock_fallback_enabled() -> bool:
    return bool(current_app.config.get('DETECTION_MOCK_FALLBACK', False))


def detect(image_path_or_url: str, crop_type: str = '') -> dict | None:
    """Run disease detection through the configured provider.

    Grad-CAM is requested automatically for every image scan.  The overlay
    is available only from the local detection-service provider for now.
    """
    provider = (current_app.config.get('DETECTION_PROVIDER') or 'local').strip().lower()
    if provider == 'sagemaker':
        result = _detect_sagemaker(image_path_or_url, crop_type)
    else:
        result = _detect_local_service(image_path_or_url, crop_type)

    if result is not None:
        return result

    if _mock_fallback_enabled():
        logger.warning('Detection mock fallback enabled -- returning deterministic mock')
        return _mock_detect(image_path_or_url, crop_type)
    return None


def _detect_local_service(image_path_or_url: str, crop_type: str = '') -> dict | None:
    base = current_app.config.get('DETECTION_SERVICE_URL', 'http://localhost:5001')
    url = f'{base}/api/detect'
    timeout = (
        float(current_app.config.get('DETECTION_CONNECT_TIMEOUT', 5)),
        float(current_app.config.get('DETECTION_REQUEST_TIMEOUT', 120)),
    )

    try:
        if os.path.exists(image_path_or_url):
            with open(image_path_or_url, 'rb') as file_obj:
                resp = requests.post(
                    url,
                    files={'image': file_obj},
                    data={'crop_type': crop_type, 'include_gradcam': 'true'},
                    timeout=timeout,
                )
        else:
            resp = requests.post(
                url,
                json={
                    'image_url': image_path_or_url,
                    'crop_type': crop_type,
                    'include_gradcam': True,
                },
                timeout=timeout,
            )

        if resp.status_code == 200:
            return resp.json()

        if resp.status_code == 422:
            body = _safe_json(resp)
            if body.get('error_code') in VALIDATION_ERROR_CODES:
                raise DetectionValidationError(body, 422)

        logger.warning('Detection service returned %s: %s', resp.status_code, resp.text)
    except requests.ConnectionError:
        logger.warning('Detection service unreachable')
    except DetectionValidationError:
        raise
    except Exception as exc:
        logger.warning('Detection proxy error: %s', exc)

    return None


def select_video_keyframes(video_path: str, max_frames: int = 20) -> dict | None:
    """Ask detection-service to select representative frame indices for a video."""
    if not video_path or not os.path.exists(video_path):
        logger.warning('Video keyframe selection skipped; file not found: %s', video_path)
        return None

    base = current_app.config.get('DETECTION_SERVICE_URL', 'http://localhost:5001').rstrip('/')
    timeout = (
        float(current_app.config.get('DETECTION_CONNECT_TIMEOUT', 5)),
        float(current_app.config.get('DETECTION_REQUEST_TIMEOUT', 120)),
    )

    try:
        with open(video_path, 'rb') as video_file:
            resp = requests.post(
                f'{base}/api/video/keyframes',
                files={'video': (os.path.basename(video_path), video_file)},
                data={'max_frames': str(max_frames)},
                timeout=timeout,
            )
        if resp.status_code == 200:
            return resp.json()
        logger.warning('Video keyframe service returned %s: %s', resp.status_code, resp.text[:300])
    except Exception as exc:
        logger.warning('Video keyframe service unavailable: %s', exc)

    return None


def _detect_sagemaker(image_path_or_url: str, crop_type: str = '') -> dict | None:
    endpoint_name = _sagemaker_endpoint_for(crop_type)
    if not endpoint_name:
        logger.warning('SageMaker detection selected but no endpoint is configured')
        return None

    try:
        body, content_type = _image_bytes_for_sagemaker(image_path_or_url)
        client = _sagemaker_runtime_client()
        response = client.invoke_endpoint(
            EndpointName=endpoint_name,
            Body=body,
            ContentType=content_type,
            Accept='application/json',
        )
        payload = response['Body'].read().decode('utf-8')
        result = json.loads(payload)

        if result.get('error_code') in VALIDATION_ERROR_CODES:
            raise DetectionValidationError(result, 422)
        return result
    except DetectionValidationError:
        raise
    except Exception as exc:
        logger.warning('SageMaker detection proxy error: %s', exc)
        return None


def _sagemaker_runtime_client():
    import boto3
    from botocore.config import Config as BotoConfig

    region = current_app.config.get('SAGEMAKER_REGION') or 'us-east-1'
    profile = current_app.config.get('SAGEMAKER_PROFILE') or None
    timeout = float(current_app.config.get('DETECTION_REQUEST_TIMEOUT', 120))
    config = BotoConfig(read_timeout=timeout, connect_timeout=5, retries={'max_attempts': 2})
    if profile:
        return boto3.Session(profile_name=profile, region_name=region).client(
            'sagemaker-runtime',
            config=config,
        )
    return boto3.client('sagemaker-runtime', region_name=region, config=config)


def _sagemaker_endpoint_for(crop_type: str) -> str:
    crop = _normalize_crop(crop_type)
    mapping = _parse_sagemaker_endpoints(current_app.config.get('SAGEMAKER_ENDPOINTS', ''))
    return mapping.get(crop) or current_app.config.get('SAGEMAKER_ENDPOINT_NAME', '')


def _parse_sagemaker_endpoints(raw: str) -> dict[str, str]:
    if not raw:
        return {}
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            return {
                _normalize_crop(str(crop)): str(endpoint)
                for crop, endpoint in parsed.items()
                if endpoint
            }
    except json.JSONDecodeError:
        pass

    mapping = {}
    for item in raw.split(','):
        if '=' not in item:
            continue
        crop, endpoint = item.split('=', 1)
        if endpoint.strip():
            mapping[_normalize_crop(crop)] = endpoint.strip()
    return mapping


def _image_bytes_for_sagemaker(image_path_or_url: str) -> tuple[bytes, str]:
    if os.path.exists(image_path_or_url):
        with open(image_path_or_url, 'rb') as file_obj:
            return file_obj.read(), _content_type_for(image_path_or_url)

    response = requests.get(
        image_path_or_url,
        timeout=(
            float(current_app.config.get('DETECTION_CONNECT_TIMEOUT', 5)),
            float(current_app.config.get('DETECTION_REQUEST_TIMEOUT', 120)),
        ),
    )
    response.raise_for_status()
    return response.content, response.headers.get('Content-Type') or _content_type_for(image_path_or_url)


def _content_type_for(path_or_url: str) -> str:
    lower = path_or_url.lower()
    if lower.endswith('.png'):
        return 'image/png'
    if lower.endswith('.webp'):
        return 'image/webp'
    return 'image/jpeg'


def _safe_json(response) -> dict:
    try:
        payload = response.json()
        return payload if isinstance(payload, dict) else {}
    except Exception:
        return {}
