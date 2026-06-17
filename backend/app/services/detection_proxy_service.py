"""
Detection proxy for the crop detection microservice.

Mock fallback is available only when explicitly enabled by configuration.
"""
import hashlib
import logging
import os

import requests
from flask import current_app

logger = logging.getLogger(__name__)

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
    'mushroom': [
        {
            'disease': 'Mushroom species: Agaricus augustus',
            'scientific_name': 'Agaricus augustus',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'Species classification only. Do not use this result as edibility or safety advice.',
        },
        {
            'disease': 'Mushroom species: Amanita muscaria',
            'scientific_name': 'Amanita muscaria',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'Species classification only. Do not use this result as edibility or safety advice.',
        },
        {
            'disease': 'Mushroom species: Pleurotus ostreatus',
            'scientific_name': 'Pleurotus ostreatus',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'Species classification only. Do not use this result as edibility or safety advice.',
        },
    ],
    'sweetpotato': [
        {
            'disease': 'Sweet Potato Leaf Spot',
            'scientific_name': 'Cercospora spp.',
            'severity': 'medium',
            'risk_level': 'medium',
            'recommendation': 'Remove heavily affected leaves and keep foliage dry where possible.',
        },
        {
            'disease': 'Sweet Potato Healthy',
            'scientific_name': 'Healthy plant',
            'severity': 'none',
            'risk_level': 'low',
            'recommendation': 'No disease detected. Continue routine monitoring.',
        },
    ],
}


def _normalize_crop(crop_type: str) -> str:
    normalized = (crop_type or 'tomato').strip().lower().replace('_', '').replace(' ', '')
    aliases = {
        'apples': 'apple',
        'grapes': 'grape',
        'mushrooms': 'mushroom',
        'potatoes': 'potato',
        'tomatoes': 'tomato',
    }
    normalized = aliases.get(normalized, normalized)
    return normalized if normalized in CATALOG else 'tomato'


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
    """Send image to detection service and return parsed result.

    Grad-CAM is requested automatically for every image scan.  The overlay
    arrives as ``gradcam_overlay`` (base64 PNG string) in the returned dict and
    is stripped from the MongoDB document by the scan controller before being
    re-injected into the one-time creation response sent to the Flutter client.
    """
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
            body = resp.json()
            if body.get('error_code') == 'NOT_A_PLANT':
                raise ValueError(body.get('error', 'Image does not appear to contain a plant.'))

        logger.warning('Detection service returned %s: %s', resp.status_code, resp.text)
    except requests.ConnectionError:
        logger.warning('Detection service unreachable')
    except ValueError:
        raise  # NOT_A_PLANT errors must reach the scan controller — do not swallow
    except Exception as exc:
        logger.warning('Detection proxy error: %s', exc)

    if _mock_fallback_enabled():
        logger.warning('Detection mock fallback enabled -- returning deterministic mock')
        return _mock_detect(image_path_or_url, crop_type)
    return None
