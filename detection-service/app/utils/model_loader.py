"""
Tomato disease classifier loader backed by a PyTorch `.pth` checkpoint.
"""
from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass
import logging
import os
from typing import Any

import cv2
import numpy as np
import requests
import timm
import torch

logger = logging.getLogger(__name__)

IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)
SUPPORTED_BACKBONES = [
    'efficientnet_b3',
    'tf_efficientnet_b3',
    'efficientnet_b2',
    'efficientnet_b0',
]

TOMATO_LABELS = [
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
]

LABEL_DETAILS = {
    'Tomato___Bacterial_spot': {
        'disease': 'Bacterial spot',
        'scientific_name': 'Xanthomonas spp.',
        'severity': 'high',
        'risk_level': 'high',
        'recommendation': 'Remove infected leaves, avoid overhead irrigation, and sanitize tools between plants.',
    },
    'Tomato___Early_blight': {
        'disease': 'Early blight',
        'scientific_name': 'Alternaria solani',
        'severity': 'medium',
        'risk_level': 'medium',
        'recommendation': 'Remove damaged leaves and begin preventive fungicide coverage if spread is increasing.',
    },
    'Tomato___Late_blight': {
        'disease': 'Late blight',
        'scientific_name': 'Phytophthora infestans',
        'severity': 'high',
        'risk_level': 'high',
        'recommendation': 'Isolate infected plants quickly and reduce leaf wetness immediately to slow spread.',
    },
    'Tomato___Leaf_Mold': {
        'disease': 'Leaf mold',
        'scientific_name': 'Passalora fulva',
        'severity': 'medium',
        'risk_level': 'medium',
        'recommendation': 'Improve ventilation, reduce humidity, and remove heavily affected lower foliage.',
    },
    'Tomato___Septoria_leaf_spot': {
        'disease': 'Septoria leaf spot',
        'scientific_name': 'Septoria lycopersici',
        'severity': 'medium',
        'risk_level': 'medium',
        'recommendation': 'Prune affected leaves and avoid splashing water onto foliage during irrigation.',
    },
    'Tomato___Spider_mites Two-spotted_spider_mite': {
        'disease': 'Spider mites',
        'scientific_name': 'Tetranychus urticae',
        'severity': 'medium',
        'risk_level': 'medium',
        'recommendation': 'Inspect leaf undersides, raise humidity when possible, and treat hotspots early.',
    },
    'Tomato___Target_Spot': {
        'disease': 'Target spot',
        'scientific_name': 'Corynespora cassiicola',
        'severity': 'medium',
        'risk_level': 'medium',
        'recommendation': 'Remove infected foliage and keep plant spacing open enough for faster drying.',
    },
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus': {
        'disease': 'Tomato yellow leaf curl virus',
        'scientific_name': 'Tomato yellow leaf curl virus',
        'severity': 'high',
        'risk_level': 'high',
        'recommendation': 'Control whiteflies aggressively and separate infected plants from healthy ones.',
    },
    'Tomato___Tomato_mosaic_virus': {
        'disease': 'Tomato mosaic virus',
        'scientific_name': 'Tomato mosaic virus',
        'severity': 'high',
        'risk_level': 'high',
        'recommendation': 'Discard infected material and disinfect hands and tools to prevent mechanical spread.',
    },
    'Tomato___healthy': {
        'disease': 'Healthy',
        'scientific_name': 'Healthy plant',
        'severity': 'none',
        'risk_level': 'low',
        'recommendation': 'No disease detected. Keep monitoring and maintain balanced irrigation and airflow.',
    },
}


@dataclass
class ModelState:
    model: torch.nn.Module
    metadata: dict[str, Any]
    device: torch.device
    model_path: str


_state: ModelState | None = None
_state_error: str | None = None
_configured_model_path: str = ''


def _default_model_path() -> str:
    return os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            '..',
            '..',
            '..',
            'models',
            'tomato_model.pth',
        )
    )


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
        if state_dict is None and checkpoint and all(isinstance(v, torch.Tensor) for v in checkpoint.values()):
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


def _resolve_image_size(model_name: str, model: torch.nn.Module) -> int:
    cfg = getattr(model, 'pretrained_cfg', None) or getattr(model, 'default_cfg', None) or {}
    input_size = cfg.get('input_size')
    if isinstance(input_size, (list, tuple)) and input_size:
        return int(input_size[-1])
    return {
        'efficientnet_b3': 300,
        'tf_efficientnet_b3': 300,
        'efficientnet_b2': 260,
        'efficientnet_b0': 224,
    }.get(model_name, 300)


def init_model_loader(app) -> None:
    """Load the tomato model once at startup."""
    global _state, _state_error, _configured_model_path

    model_path = app.config.get('MODEL_PATH') or _default_model_path()
    _configured_model_path = model_path
    force_cpu = app.config.get('MODEL_FORCE_CPU', True)
    dev = _device(force_cpu=force_cpu)

    if not os.path.exists(model_path):
        _state = None
        _state_error = f'Model file not found: {model_path}'
        app.logger.error(_state_error)
        return

    try:
        checkpoint = _load_checkpoint(model_path)
        state_dict = _extract_state_dict(checkpoint)
        num_classes, classifier_key = _infer_num_classes(state_dict)
        if num_classes != len(TOMATO_LABELS):
            raise RuntimeError(
                f'Checkpoint classifier size is {num_classes} from {classifier_key}; '
                f'expected {len(TOMATO_LABELS)} for the tomato label mapping.'
            )

        errors = []
        for model_name in SUPPORTED_BACKBONES:
            try:
                model = timm.create_model(model_name, pretrained=False, num_classes=num_classes)
                model.load_state_dict(state_dict, strict=True)
                model = model.to(dev)
                model.eval()
                img_size = _resolve_image_size(model_name, model)
                _state = ModelState(
                    model=model,
                    metadata={
                        'model_name': model_name,
                        'num_classes': num_classes,
                        'img_size': img_size,
                        'classifier_key': classifier_key,
                    },
                    device=dev,
                    model_path=model_path,
                )
                _state_error = None
                app.logger.info(
                    'Loaded tomato detection checkpoint %s as %s on %s',
                    model_path,
                    model_name,
                    dev,
                )
                return
            except Exception as exc:
                errors.append(f'{model_name}: {exc}')

        raise RuntimeError(
            'Checkpoint did not match any supported EfficientNet backbone. '
            f'Tried: {" | ".join(errors)}'
        )
    except Exception as exc:  # pragma: no cover - runtime safety
        _state = None
        _state_error = str(exc)
        app.logger.exception('Failed to load tomato detection model: %s', exc)


def get_model_status() -> dict[str, Any]:
    if _state is None:
        return {
            'ready': False,
            'error': _state_error,
            'model_path': _configured_model_path or _default_model_path(),
            'supported_backbones': SUPPORTED_BACKBONES,
        }
    return {
        'ready': True,
        'error': None,
        'model_name': _state.metadata.get('model_name', 'efficientnet_b3'),
        'num_classes': int(_state.metadata.get('num_classes', len(TOMATO_LABELS))),
        'img_size': int(_state.metadata.get('img_size', 300)),
        'device': str(_state.device),
        'model_path': _state.model_path,
        'supported_backbones': SUPPORTED_BACKBONES,
    }


def _ensure_ready() -> ModelState:
    if _state is None:
        raise RuntimeError(_state_error or 'Tomato model is not loaded')
    return _state


def _prepare_tensor(image_bgr: np.ndarray, img_size: int, device: torch.device) -> torch.Tensor:
    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    resized = cv2.resize(image_rgb, (img_size, img_size), interpolation=cv2.INTER_AREA)
    image_float = resized.astype(np.float32) / 255.0
    normalized = (image_float - IMAGENET_MEAN) / IMAGENET_STD
    chw = np.transpose(normalized, (2, 0, 1)).copy()
    return torch.from_numpy(chw).unsqueeze(0).to(device)


def _predict_from_bgr(image_bgr: np.ndarray) -> dict[str, Any]:
    state = _ensure_ready()
    img_size = int(state.metadata.get('img_size', 300))
    input_tensor = _prepare_tensor(image_bgr, img_size, state.device)

    with torch.no_grad():
        outputs = state.model(input_tensor)
        probabilities = torch.softmax(outputs, dim=1)[0]
        predicted_id = int(torch.argmax(probabilities).item())
        confidence = float(probabilities[predicted_id].item())
        top_k = torch.topk(probabilities, k=min(3, len(TOMATO_LABELS)))

    predicted_label = TOMATO_LABELS[predicted_id]
    details = LABEL_DETAILS[predicted_label]
    top_predictions = []
    for idx, prob in zip(top_k.indices.tolist(), top_k.values.tolist()):
        raw_label = TOMATO_LABELS[int(idx)]
        label_details = LABEL_DETAILS[raw_label]
        top_predictions.append(
            {
                'class_id': int(idx),
                'label': raw_label,
                'disease': label_details['disease'],
                'confidence': round(float(prob), 4),
            }
        )

    return {
        'crop_type': 'tomato',
        'label': predicted_label,
        'disease': details['disease'],
        'scientific_name': details['scientific_name'],
        'confidence': round(confidence, 4),
        'severity': details['severity'],
        'is_healthy': predicted_label == 'Tomato___healthy',
        'risk_level': details['risk_level'],
        'recommendation': details['recommendation'],
        'top_predictions': top_predictions,
        'model_version': f"{state.metadata.get('model_name', 'efficientnet_b3')}-tomato-pth-v1",
        'model_input_size': img_size,
    }


def predict_from_file_bytes(file_bytes: bytes) -> dict[str, Any]:
    image = cv2.imdecode(np.frombuffer(file_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError('Could not decode image bytes')
    return _predict_from_bgr(image)


def predict_from_url(image_url: str, timeout: int = 15) -> dict[str, Any]:
    response = requests.get(image_url, timeout=timeout)
    response.raise_for_status()
    return predict_from_file_bytes(response.content)
