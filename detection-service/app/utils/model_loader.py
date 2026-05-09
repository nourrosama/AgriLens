"""
Multi-crop disease classifier loader backed by PyTorch `.pth` checkpoints.
"""
from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass, field
import logging
import os
from typing import Any

import cv2
import numpy as np
import requests
import timm
import torch

from app.utils.gradcam import GradCAM, _get_target_layer, generate_overlay_base64

logger = logging.getLogger(__name__)

IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)
SUPPORTED_BACKBONES = [
    'efficientnet_b3',
    'tf_efficientnet_b3',
    'efficientnet_b2',
    'efficientnet_b0',
]


@dataclass(frozen=True)
class CropConfig:
    name: str
    env_key: str
    default_filename: str
    labels: list[str]
    img_size: int
    model_name: str
    details: dict[str, dict[str, str]]


@dataclass
class ModelState:
    model: torch.nn.Module
    metadata: dict[str, Any]
    device: torch.device
    model_path: str
    config: CropConfig
    grad_cam: GradCAM | None = field(default=None)


def _details(
    disease: str,
    scientific_name: str,
    severity: str,
    risk_level: str,
    recommendation: str,
) -> dict[str, str]:
    return {
        'disease': disease,
        'scientific_name': scientific_name,
        'severity': severity,
        'risk_level': risk_level,
        'recommendation': recommendation,
    }


CROP_CONFIGS: dict[str, CropConfig] = {
    'tomato': CropConfig(
        name='tomato',
        env_key='TOMATO_MODEL_PATH',
        default_filename='tomato_model.pth',
        img_size=300,
        model_name='efficientnet_b3',
        labels=[
            'Tomato___Bacterial_spot',
            'Tomato___Early_blight',
            'Tomato___Late_blight',
            'Tomato___Leaf_Mold',
            'Tomato___Septoria_leaf_spot',
            'Tomato___Spider_mites Two-spotted_spider_mite',
            'Tomato___Target_Spot',
            'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
            'Tomato___Tomato_mosaic_virus',
            'Tomato___healthy',
        ],
        details={
            'Tomato___Bacterial_spot': _details(
                'Bacterial spot',
                'Xanthomonas spp.',
                'high',
                'high',
                'Remove infected leaves, avoid overhead irrigation, and sanitize tools between plants.',
            ),
            'Tomato___Early_blight': _details(
                'Early blight',
                'Alternaria solani',
                'medium',
                'medium',
                'Remove damaged leaves and begin preventive fungicide coverage if spread is increasing.',
            ),
            'Tomato___Late_blight': _details(
                'Late blight',
                'Phytophthora infestans',
                'high',
                'high',
                'Isolate infected plants quickly and reduce leaf wetness immediately to slow spread.',
            ),
            'Tomato___Leaf_Mold': _details(
                'Leaf mold',
                'Passalora fulva',
                'medium',
                'medium',
                'Improve ventilation, reduce humidity, and remove heavily affected lower foliage.',
            ),
            'Tomato___Septoria_leaf_spot': _details(
                'Septoria leaf spot',
                'Septoria lycopersici',
                'medium',
                'medium',
                'Prune affected leaves and avoid splashing water onto foliage during irrigation.',
            ),
            'Tomato___Spider_mites Two-spotted_spider_mite': _details(
                'Spider mites',
                'Tetranychus urticae',
                'medium',
                'medium',
                'Inspect leaf undersides, raise humidity when possible, and treat hotspots early.',
            ),
            'Tomato___Target_Spot': _details(
                'Target spot',
                'Corynespora cassiicola',
                'medium',
                'medium',
                'Remove infected foliage and keep plant spacing open enough for faster drying.',
            ),
            'Tomato___Tomato_Yellow_Leaf_Curl_Virus': _details(
                'Tomato yellow leaf curl virus',
                'Tomato yellow leaf curl virus',
                'high',
                'high',
                'Control whiteflies aggressively and separate infected plants from healthy ones.',
            ),
            'Tomato___Tomato_mosaic_virus': _details(
                'Tomato mosaic virus',
                'Tomato mosaic virus',
                'high',
                'high',
                'Discard infected material and disinfect hands and tools to prevent mechanical spread.',
            ),
            'Tomato___healthy': _details(
                'Healthy',
                'Healthy plant',
                'none',
                'low',
                'No disease detected. Keep monitoring and maintain balanced irrigation and airflow.',
            ),
        },
    ),
    'apple': CropConfig(
        name='apple',
        env_key='APPLE_MODEL_PATH',
        default_filename='apple_model.pth',
        img_size=384,
        model_name='efficientnet_b3',
        labels=[
            'Apple Scab',
            'Black Rot',
            'Cedar Apple Rust',
            'Healthy',
        ],
        details={
            'Apple Scab': _details(
                'Apple scab',
                'Venturia inaequalis',
                'medium',
                'medium',
                'Remove infected leaves and fruit debris, improve airflow, and use preventive fungicide when conditions are wet.',
            ),
            'Black Rot': _details(
                'Black rot',
                'Botryosphaeria obtusa',
                'high',
                'high',
                'Prune infected branches, remove mummified fruit, and disinfect tools after cutting affected tissue.',
            ),
            'Cedar Apple Rust': _details(
                'Cedar apple rust',
                'Gymnosporangium juniperi-virginianae',
                'medium',
                'medium',
                'Remove nearby alternate hosts where possible and monitor leaves closely during humid spring weather.',
            ),
            'Healthy': _details(
                'Healthy',
                'Healthy plant',
                'none',
                'low',
                'No disease detected. Continue routine monitoring and balanced orchard management.',
            ),
        },
    ),
    'potato': CropConfig(
        name='potato',
        env_key='POTATO_MODEL_PATH',
        default_filename='potato_model.pth',
        img_size=384,
        model_name='efficientnet_b3',
        labels=[
            'Bacteria',
            'Fungi',
            'Healthy',
            'Nematode',
            'Pest',
            'Phytopthora',
            'Virus',
        ],
        details={
            'Bacteria': _details(
                'Bacterial disease',
                'Bacterial pathogen',
                'high',
                'high',
                'Remove infected plants, avoid spreading soil between beds, and sanitize tools after field work.',
            ),
            'Fungi': _details(
                'Fungal disease',
                'Fungal pathogen',
                'medium',
                'medium',
                'Improve airflow, avoid overhead irrigation, and monitor spread after humid or rainy periods.',
            ),
            'Healthy': _details(
                'Healthy',
                'Healthy plant',
                'none',
                'low',
                'No disease detected. Keep scouting and maintain balanced irrigation.',
            ),
            'Nematode': _details(
                'Nematode damage',
                'Plant-parasitic nematodes',
                'medium',
                'medium',
                'Rotate crops, avoid moving contaminated soil, and inspect nearby plants for uneven growth.',
            ),
            'Pest': _details(
                'Pest damage',
                'Insect pest',
                'medium',
                'medium',
                'Inspect leaf undersides and field edges, then treat hotspots early if pest pressure increases.',
            ),
            'Phytopthora': _details(
                'Phytophthora disease',
                'Phytophthora spp.',
                'high',
                'high',
                'Act quickly, reduce leaf wetness, and remove heavily infected plants to limit spread.',
            ),
            'Virus': _details(
                'Viral disease',
                'Plant virus',
                'high',
                'high',
                'Remove infected plants and control insect vectors to reduce virus transmission.',
            ),
        },
    ),
}

ALIASES = {
    'apples': 'apple',
    'potatoes': 'potato',
    'tomatoes': 'tomato',
}

_states: dict[str, ModelState] = {}
_state_errors: dict[str, str] = {}
_configured_model_paths: dict[str, str] = {}


def supported_crops() -> list[str]:
    return list(CROP_CONFIGS.keys())


def normalize_crop(crop_type: str | None) -> str:
    normalized = (crop_type or 'tomato').strip().lower().replace('_', '').replace(' ', '')
    return ALIASES.get(normalized, normalized)


def is_supported_crop(crop_type: str | None) -> bool:
    return normalize_crop(crop_type) in CROP_CONFIGS


def _default_model_path(filename: str) -> str:
    return os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            '..',
            '..',
            '..',
            'models',
            filename,
        )
    )


def _model_path_for(app, config: CropConfig) -> str:
    specific_path = app.config.get(config.env_key, '')
    if specific_path:
        return specific_path
    if config.name == 'tomato' and app.config.get('MODEL_PATH'):
        return app.config['MODEL_PATH']
    return _default_model_path(config.default_filename)


def _device(force_cpu: bool = True) -> torch.device:
    if not force_cpu and torch.cuda.is_available():
        return torch.device('cuda')
    return torch.device('cpu')


def _load_checkpoint(path: str):
    try:
        return torch.load(path, map_location='cpu', weights_only=False)
    except TypeError:
        return torch.load(path, map_location='cpu')


def _extract_state_dict(checkpoint: Any) -> OrderedDict[str, torch.Tensor]:
    state_dict = None

    if isinstance(checkpoint, OrderedDict):
        state_dict = checkpoint
    elif isinstance(checkpoint, dict):
        for key in ('state_dict', 'model_state_dict', 'model', 'net', 'weights'):
            candidate = checkpoint.get(key)
            if isinstance(candidate, dict):
                state_dict = candidate
                break
        if state_dict is None and checkpoint and all(
            isinstance(value, torch.Tensor) for value in checkpoint.values()
        ):
            state_dict = checkpoint

    if state_dict is None:
        raise RuntimeError('Unsupported checkpoint format: could not locate a state_dict')

    normalized = OrderedDict()
    for key, value in state_dict.items():
        normalized_key = key
        for prefix in ('module.', '_orig_mod.', 'model.'):
            if normalized_key.startswith(prefix):
                normalized_key = normalized_key[len(prefix):]
        normalized[normalized_key] = value
    return normalized


def _infer_num_classes(state_dict: OrderedDict[str, torch.Tensor]) -> tuple[int, str]:
    for key in ('classifier.weight', 'head.fc.weight', 'fc.weight'):
        tensor = state_dict.get(key)
        if tensor is not None and tensor.ndim >= 1:
            return int(tensor.shape[0]), key
    raise RuntimeError('Could not infer classifier output size from checkpoint')


def _model_name_candidates(config: CropConfig) -> list[str]:
    candidates = [config.model_name]
    candidates.extend(name for name in SUPPORTED_BACKBONES if name not in candidates)
    return candidates


def init_model_loader(app) -> None:
    """Load all configured crop models once at startup."""
    global _states, _state_errors, _configured_model_paths

    _states = {}
    _state_errors = {}
    _configured_model_paths = {}
    force_cpu = app.config.get('MODEL_FORCE_CPU', True)
    dev = _device(force_cpu=force_cpu)

    for crop, config in CROP_CONFIGS.items():
        model_path = _model_path_for(app, config)
        _configured_model_paths[crop] = model_path

        if not os.path.exists(model_path):
            _state_errors[crop] = f'Model file not found: {model_path}'
            app.logger.error('%s model file not found: %s', crop, model_path)
            continue

        try:
            checkpoint = _load_checkpoint(model_path)
            state_dict = _extract_state_dict(checkpoint)
            num_classes, classifier_key = _infer_num_classes(state_dict)
            if num_classes != len(config.labels):
                raise RuntimeError(
                    f'Checkpoint classifier size is {num_classes} from {classifier_key}; '
                    f'expected {len(config.labels)} for the {crop} label mapping.'
                )

            errors = []
            for model_name in _model_name_candidates(config):
                try:
                    model = timm.create_model(
                        model_name,
                        pretrained=False,
                        num_classes=num_classes,
                    )
                    model.load_state_dict(state_dict, strict=True)
                    model = model.to(dev)
                    model.eval()

                    # Register Grad-CAM hooks once at startup
                    grad_cam: GradCAM | None = None
                    try:
                        target_layer = _get_target_layer(model)
                        grad_cam = GradCAM(model, target_layer)
                        app.logger.info(
                            'Grad-CAM hooks registered on %s.%s for %s',
                            model_name,
                            target_layer.__class__.__name__,
                            crop,
                        )
                    except Exception as exc:
                        app.logger.warning(
                            'Could not register Grad-CAM for %s: %s', crop, exc
                        )

                    _states[crop] = ModelState(
                        model=model,
                        grad_cam=grad_cam,
                        metadata={
                            'model_name': model_name,
                            'num_classes': num_classes,
                            'img_size': config.img_size,
                            'classifier_key': classifier_key,
                        },
                        device=dev,
                        model_path=model_path,
                        config=config,
                    )
                    _state_errors.pop(crop, None)
                    app.logger.info(
                        'Loaded %s detection checkpoint %s as %s on %s',
                        crop,
                        model_path,
                        model_name,
                        dev,
                    )
                    break
                except Exception as exc:
                    errors.append(f'{model_name}: {exc}')
            else:
                raise RuntimeError(
                    'Checkpoint did not match any supported backbone. '
                    f'Tried: {" | ".join(errors)}'
                )
        except Exception as exc:  # pragma: no cover - runtime safety
            _state_errors[crop] = str(exc)
            app.logger.exception('Failed to load %s detection model: %s', crop, exc)


def _status_for_crop(crop: str) -> dict[str, Any]:
    config = CROP_CONFIGS[crop]
    state = _states.get(crop)
    if state is None:
        return {
            'ready': False,
            'error': _state_errors.get(crop),
            'model_path': _configured_model_paths.get(
                crop,
                _default_model_path(config.default_filename),
            ),
            'model_name': config.model_name,
            'num_classes': len(config.labels),
            'img_size': config.img_size,
            'supported_backbones': SUPPORTED_BACKBONES,
        }
    return {
        'ready': True,
        'error': None,
        'model_name': state.metadata.get('model_name', config.model_name),
        'num_classes': int(state.metadata.get('num_classes', len(config.labels))),
        'img_size': int(state.metadata.get('img_size', config.img_size)),
        'device': str(state.device),
        'model_path': state.model_path,
        'supported_backbones': SUPPORTED_BACKBONES,
    }


def get_model_status(crop_type: str | None = None) -> dict[str, Any]:
    if crop_type:
        crop = normalize_crop(crop_type)
        if crop not in CROP_CONFIGS:
            return {
                'ready': False,
                'error': f'Unsupported crop type: {crop_type}',
                'supported_crops': supported_crops(),
            }
        return _status_for_crop(crop)

    models = {crop: _status_for_crop(crop) for crop in supported_crops()}
    return {
        'ready': all(model['ready'] for model in models.values()),
        'supported_crops': supported_crops(),
        'models': models,
    }


def _ensure_ready(crop_type: str | None) -> ModelState:
    crop = normalize_crop(crop_type)
    if crop not in CROP_CONFIGS:
        raise ValueError(
            f'Unsupported crop type: {crop}. Supported crops: {", ".join(supported_crops())}'
        )
    state = _states.get(crop)
    if state is None:
        raise RuntimeError(_state_errors.get(crop) or f'{crop} model is not loaded')
    return state


def _prepare_tensor(image_bgr: np.ndarray, img_size: int, device: torch.device) -> torch.Tensor:
    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    resized = cv2.resize(image_rgb, (img_size, img_size), interpolation=cv2.INTER_AREA)
    image_float = resized.astype(np.float32) / 255.0
    normalized = (image_float - IMAGENET_MEAN) / IMAGENET_STD
    chw = np.transpose(normalized, (2, 0, 1)).copy()
    return torch.from_numpy(chw).unsqueeze(0).to(device)


def _predict_from_bgr(image_bgr: np.ndarray, crop_type: str | None) -> dict[str, Any]:
    state = _ensure_ready(crop_type)
    config = state.config
    img_size = int(state.metadata.get('img_size', config.img_size))
    input_tensor = _prepare_tensor(image_bgr, img_size, state.device)

    with torch.no_grad():
        outputs = state.model(input_tensor)
        probabilities = torch.softmax(outputs, dim=1)[0]
        predicted_id = int(torch.argmax(probabilities).item())
        confidence = float(probabilities[predicted_id].item())
        top_k = torch.topk(probabilities, k=min(3, len(config.labels)))

    predicted_label = config.labels[predicted_id]
    details = config.details[predicted_label]
    top_predictions = []
    for idx, prob in zip(top_k.indices.tolist(), top_k.values.tolist()):
        raw_label = config.labels[int(idx)]
        label_details = config.details[raw_label]
        top_predictions.append(
            {
                'class_id': int(idx),
                'label': raw_label,
                'disease': label_details['disease'],
                'confidence': round(float(prob), 4),
            }
        )

    return {
        'crop_type': config.name,
        'label': predicted_label,
        'disease': details['disease'],
        'scientific_name': details['scientific_name'],
        'confidence': round(confidence, 4),
        'severity': details['severity'],
        'is_healthy': details['severity'] == 'none',
        'risk_level': details['risk_level'],
        'recommendation': details['recommendation'],
        'top_predictions': top_predictions,
        'model_version': f"{state.metadata.get('model_name', config.model_name)}-{config.name}-pth-v1",
        'model_input_size': img_size,
        # Internal key used by _predict_from_bgr_with_gradcam; stripped before returning to callers
        '_predicted_id': predicted_id,
    }


def predict_from_file_bytes(file_bytes: bytes, crop_type: str | None = 'tomato') -> dict[str, Any]:
    image = cv2.imdecode(np.frombuffer(file_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError('Could not decode image bytes')
    result = _predict_from_bgr(image, crop_type)
    result.pop('_predicted_id', None)
    return result


def predict_from_url(
    image_url: str,
    crop_type: str | None = 'tomato',
    timeout: int = 15,
) -> dict[str, Any]:
    response = requests.get(image_url, timeout=timeout)
    response.raise_for_status()
    return predict_from_file_bytes(response.content, crop_type)


# ---------------------------------------------------------------------------
# Grad-CAM-augmented prediction
# ---------------------------------------------------------------------------

def _predict_from_bgr_with_gradcam(image_bgr: np.ndarray, crop_type: str | None) -> dict[str, Any]:
    """Run prediction and append a base64 Grad-CAM overlay to the result."""
    # 1. Standard prediction (no_grad path) - includes _predicted_id
    result = _predict_from_bgr(image_bgr, crop_type)

    state = _ensure_ready(crop_type)
    if state.grad_cam is None:
        result['gradcam_overlay'] = None
        result.pop('_predicted_id', None)
        return result

    config = state.config
    img_size = int(state.metadata.get('img_size', config.img_size))
    input_tensor = _prepare_tensor(image_bgr, img_size, state.device)
    predicted_id = result.get('_predicted_id')

    # 2. Second forward pass with gradients for Grad-CAM
    try:
        inp_grad = input_tensor.clone().requires_grad_(True)
        with torch.enable_grad():
            cam = state.grad_cam.generate(
                inp_grad,
                class_idx=predicted_id,
                output_size=(img_size, img_size),
            )

        # De-normalise original image for the overlay (RGB float [0, 1])
        img_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
        img_resized = cv2.resize(img_rgb, (img_size, img_size), interpolation=cv2.INTER_AREA)
        img_np = img_resized.astype(np.float32) / 255.0

        result['gradcam_overlay'] = generate_overlay_base64(img_np, cam)
    except Exception as exc:
        logger.warning('Grad-CAM generation failed: %s', exc)
        result['gradcam_overlay'] = None

    result.pop('_predicted_id', None)
    return result


def predict_from_file_bytes_with_gradcam(
    file_bytes: bytes,
    crop_type: str | None = 'tomato',
) -> dict[str, Any]:
    """Predict and include a base64 Grad-CAM overlay in the result."""
    image = cv2.imdecode(np.frombuffer(file_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError('Could not decode image bytes')
    return _predict_from_bgr_with_gradcam(image, crop_type)


def predict_from_url_with_gradcam(
    image_url: str,
    crop_type: str | None = 'tomato',
    timeout: int = 15,
) -> dict[str, Any]:
    """Fetch image from URL, predict, and include Grad-CAM overlay."""
    response = requests.get(image_url, timeout=timeout)
    response.raise_for_status()
    return predict_from_file_bytes_with_gradcam(response.content, crop_type)
