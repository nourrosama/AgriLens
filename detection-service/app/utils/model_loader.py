"""
Multi-crop disease classifier loader.

The service supports PyTorch crop models, a Keras cotton model, and a
ConvNeXt-based crop validator. Models are loaded lazily on first use so local
development can boot even when a large or optional model is unavailable.
"""
from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass, field
import json
import logging
import os
import tempfile
from typing import Any
import zipfile

import cv2
import numpy as np
import requests
import timm
import torch
from torch import nn
from torchvision.models import convnext_tiny, efficientnet_b3, resnet50, vgg16

from app.utils.gradcam import GradCAM, _get_target_layer, generate_overlay_base64

logger = logging.getLogger(__name__)

IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

# When the top-class probability after softmax is below this value the image is
# almost certainly not a plant leaf.  A real plant image reliably scores >0.60;
# an out-of-distribution image (face, car, sky…) spreads probability evenly
# across all classes so the max is roughly 1/num_classes (~0.10 for tomato).
MIN_PLANT_CONFIDENCE = 0.40
SUPPORTED_BACKBONES = [
    'efficientnet_b3',
    'tf_efficientnet_b3',
    'efficientnet_b2',
    'efficientnet_b0',
]


class ValidationFailure(ValueError):
    """Raised when crop validation should be returned as a structured 422."""

    def __init__(self, payload: dict[str, Any]):
        super().__init__(payload.get('message') or payload.get('error') or 'Validation failed')
        self.payload = payload


@dataclass(frozen=True)
class CropConfig:
    name: str
    env_key: str
    default_filename: str
    labels: list[str]
    img_size: int
    model_name: str
    details: dict[str, dict[str, str]]
    runtime: str = 'torch'
    labels_env_key: str = ''
    default_labels_filename: str = ''


@dataclass
class ModelState:
    model: Any
    metadata: dict[str, Any]
    device: torch.device | None
    model_path: str
    config: CropConfig
    labels: list[str]
    details: dict[str, dict[str, str]]
    grad_cam: GradCAM | None = field(default=None)


@dataclass
class ValidatorState:
    model: torch.nn.Module
    labels: list[str]
    device: torch.device
    model_path: str
    metadata: dict[str, Any]


@dataclass
class VideoKeyframeState:
    model: torch.nn.Module
    device: torch.device
    model_path: str
    metadata: dict[str, Any]


class VGG16FeatureClassifier(nn.Module):
    """Corn head checkpoint plus an untrained local VGG16 feature extractor."""

    def __init__(self, num_classes: int):
        super().__init__()
        self.features = vgg16(weights=None).features
        self.pool = nn.AdaptiveAvgPool2d((1, 1))
        self.fc1 = nn.Linear(512, 256)
        self.bn1 = nn.BatchNorm1d(256)
        self.relu = nn.ReLU(inplace=True)
        self.dropout = nn.Dropout(0.3)
        self.fc2 = nn.Linear(256, num_classes)

    def forward(self, x):
        x = self.features(x)
        x = self.pool(x)
        x = torch.flatten(x, 1)
        x = self.fc1(x)
        x = self.bn1(x)
        x = self.relu(x)
        x = self.dropout(x)
        return self.fc2(x)


class ResNetFrameEncoder(nn.Module):
    def __init__(self):
        super().__init__()
        self.backbone = nn.Sequential(*list(resnet50(weights=None).children())[:-2])
        self.pool = nn.AdaptiveAvgPool2d((1, 1))

    def forward(self, x):
        features = self.backbone(x)
        features = self.pool(features)
        return torch.flatten(features, 1)


class VideoKeyframeModel(nn.Module):
    """Notebook model_tl port: ResNet frame encoder plus Conv1D keyframe head."""

    def __init__(self):
        super().__init__()
        self.frame_encoder = ResNetFrameEncoder()
        self.conv1 = nn.Conv1d(2048, 256, kernel_size=3, padding=1)
        self.conv2 = nn.Conv1d(256, 128, kernel_size=3, padding=1)
        self.classifier = nn.Conv1d(128, 1, kernel_size=1)
        self.relu = nn.ReLU(inplace=True)

    def forward(self, x):
        batch_size, frames, channels, height, width = x.shape
        flat = x.reshape(batch_size * frames, channels, height, width)
        encoded = self.frame_encoder(flat)
        encoded = encoded.reshape(batch_size, frames, -1).permute(0, 2, 1)
        scores = self.relu(self.conv1(encoded))
        scores = self.relu(self.conv2(scores))
        scores = torch.sigmoid(self.classifier(scores))
        return scores.permute(0, 2, 1)


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


def _format_label(label: str) -> str:
    return label.replace('_', ' ').replace('-', ' ').strip()


def _display_crop(crop: str) -> str:
    return _format_label(crop).title()


def _disease_details(label: str, scientific_name: str = 'Plant disease') -> dict[str, str]:
    if label.lower() in {'healthy', 'tomato___healthy'}:
        return _details(
            'Healthy',
            'Healthy plant',
            'none',
            'low',
            'No disease detected. Keep monitoring and maintain balanced crop care.',
        )
    normalized = _format_label(label)
    high_keywords = ('rot', 'rust', 'blast', 'blight', 'smut', 'mildew', 'septoria', 'esca')
    severity = 'high' if any(keyword in normalized.lower() for keyword in high_keywords) else 'medium'
    risk_level = 'high' if severity == 'high' else 'medium'
    return _details(
        normalized,
        scientific_name,
        severity,
        risk_level,
        'Inspect affected plants, remove heavily infected tissue, improve airflow, and follow local treatment guidance.',
    )


GRAPE_LABELS = [
    'Bacterial Rot',
    'Black Rot',
    'Downey Mildew',
    'Esca (Black Measles)',
    'Healthy',
    'Leaf Blight',
    'Powdery Mildew',
]
WHEAT_LABELS = [
    'Aphid',
    'Black_Rust',
    'Blast',
    'Brown_Rust',
    'Common_Root_Rot',
    'Fusarium_Head_Blight',
    'Healthy',
    'Leaf_Blight',
    'Mildew',
    'Mite',
    'Septoria',
    'Smut',
    'Stem_fly',
    'Tan_spot',
    'Yellow_Rust',
]
CORN_LABELS = ['Blight', 'Common_Rust', 'Gray_Leaf_Spot', 'Healthy']
SUGARCANE_LABELS = ['Healthy', 'Mosaic', 'RedRot', 'Rust', 'Yellow']
COTTON_LABELS = ['bacterial_blight', 'curl_virus', 'fussarium_wilt', 'healthy']


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
        labels=['Apple Scab', 'Black Rot', 'Cedar Apple Rust', 'Healthy'],
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
        labels=['Bacteria', 'Fungi', 'Healthy', 'Nematode', 'Pest', 'Phytopthora', 'Virus'],
        details={label: _disease_details(label, 'Potato disease or pest') for label in [
            'Bacteria', 'Fungi', 'Healthy', 'Nematode', 'Pest', 'Phytopthora', 'Virus'
        ]},
    ),
    'grape': CropConfig(
        name='grape',
        env_key='GRAPE_MODEL_PATH',
        default_filename='grape_effb3_best.pth',
        img_size=384,
        model_name='efficientnet_b3',
        labels=GRAPE_LABELS,
        details={label: _disease_details(label, 'Grape disease') for label in GRAPE_LABELS},
    ),
    'wheat': CropConfig(
        name='wheat',
        env_key='WHEAT_MODEL_PATH',
        default_filename='wheat_disease_detector.pth',
        img_size=384,
        model_name='torchvision_efficientnet_b3_custom',
        labels=WHEAT_LABELS,
        details={label: _disease_details(label, 'Wheat disease or pest') for label in WHEAT_LABELS},
    ),
    'corn': CropConfig(
        name='corn',
        env_key='CORN_MODEL_PATH',
        default_filename='corn_model.pth',
        labels_env_key='CORN_LABELS_PATH',
        default_labels_filename='corn_labels.json',
        img_size=224,
        model_name='vgg16_classifier_head',
        labels=CORN_LABELS,
        details={label: _disease_details(label, 'Corn disease') for label in CORN_LABELS},
    ),
    'sugarcane': CropConfig(
        name='sugarcane',
        env_key='SUGARCANE_MODEL_PATH',
        default_filename='sugarcane_model.pt',
        labels_env_key='SUGARCANE_LABELS_PATH',
        default_labels_filename='sugarcane_labels.json',
        img_size=224,
        model_name='torchvision_efficientnet_b3_custom',
        labels=SUGARCANE_LABELS,
        details={label: _disease_details(label, 'Sugarcane disease') for label in SUGARCANE_LABELS},
    ),
    'cotton': CropConfig(
        name='cotton',
        env_key='COTTON_MODEL_PATH',
        default_filename='cotton_model.keras',
        labels_env_key='COTTON_LABELS_PATH',
        default_labels_filename='cotton_label_mapping.json',
        img_size=224,
        model_name='mobilenetv2',
        runtime='keras',
        labels=COTTON_LABELS,
        details={label: _disease_details(label, 'Cotton disease') for label in COTTON_LABELS},
    ),
}

ALIASES = {
    'apples': 'apple',
    'corns': 'corn',
    'cottons': 'cotton',
    'grapes': 'grape',
    'potatoes': 'potato',
    'sugarcane': 'sugarcane',
    'sugarcanes': 'sugarcane',
    'sugarcaneplant': 'sugarcane',
    'sugarcaneplants': 'sugarcane',
    'tomatoes': 'tomato',
}
VALIDATOR_NOT_PLANT_LABEL_KEYS = {
    'background',
    'noobject',
    'noplant',
    'nonplant',
    'notaplant',
    'notplant',
}
VALIDATOR_UNSUPPORTED_PLANT_LABEL_KEYS = {
    'other',
    'othercrop',
    'otherplant',
    'unknown',
    'unknowncrop',
    'unknownplant',
    'unsupported',
    'unsupportedcrop',
    'unsupportedplant',
}

_states: dict[str, ModelState] = {}
_state_errors: dict[str, str] = {}
_configured_model_paths: dict[str, str] = {}
_configured_label_paths: dict[str, str] = {}
_app_config: dict[str, Any] = {}
_validator_state: ValidatorState | None = None
_validator_error: str | None = None
_video_keyframe_state: VideoKeyframeState | None = None
_video_model_error: str | None = None
_video_model_metadata: dict[str, Any] | None = None


def supported_crops() -> list[str]:
    return list(CROP_CONFIGS.keys())


def normalize_crop(crop_type: str | None) -> str:
    normalized = (crop_type or 'tomato').strip().lower().replace('_', '').replace(' ', '')
    return ALIASES.get(normalized, normalized)


def _validator_label_key(label: str | None) -> str:
    return ''.join(ch for ch in (label or '').strip().lower() if ch.isalnum())


def _validate_crop_validator_label_contract(labels: list[str]) -> list[str]:
    label_keys = {_validator_label_key(label) for label in labels}
    crop_labels = {normalize_crop(label) for label in labels}
    missing_crops = sorted(set(CROP_CONFIGS) - crop_labels)
    problems = []

    if missing_crops:
        problems.append(f'missing supported crop labels: {", ".join(missing_crops)}')
    if not (label_keys & VALIDATOR_NOT_PLANT_LABEL_KEYS):
        problems.append('missing a not-plant label')
    if not (label_keys & VALIDATOR_UNSUPPORTED_PLANT_LABEL_KEYS):
        problems.append('missing an unsupported/other-plant label')

    if problems:
        raise RuntimeError(
            'Crop validator labels do not satisfy the validation contract: '
            + '; '.join(problems)
        )

    return [normalize_crop(label) for label in labels]


def is_supported_crop(crop_type: str | None) -> bool:
    return normalize_crop(crop_type) in CROP_CONFIGS


def unsupported_crop_payload(crop_type: str | None, detected_crop: str | None = None) -> dict[str, Any]:
    selected = normalize_crop(crop_type)
    return {
        'error': 'Unsupported crop type',
        'error_code': 'UNSUPPORTED_CROP',
        'plant_status': 'unsupported_crop',
        'valid': False,
        'selected_crop': selected,
        'detected_crop': detected_crop or selected or 'unknown_plant',
        'supported_crops': supported_crops(),
        'message': 'This crop is not supported yet. Please choose one of the supported crops.',
    }


def _default_model_path(filename: str) -> str:
    return os.path.abspath(
        os.path.join(os.path.dirname(__file__), '..', '..', '..', 'models', filename)
    )


def _model_path_for(app_config: dict[str, Any], config: CropConfig) -> str:
    specific_path = app_config.get(config.env_key, '')
    if specific_path:
        return specific_path
    if config.name == 'tomato' and app_config.get('MODEL_PATH'):
        return app_config['MODEL_PATH']
    return _default_model_path(config.default_filename)


def _label_path_for(app_config: dict[str, Any], config: CropConfig) -> str:
    if not config.labels_env_key:
        return ''
    specific_path = app_config.get(config.labels_env_key, '')
    if specific_path:
        return specific_path
    if config.default_labels_filename:
        return _default_model_path(config.default_labels_filename)
    return ''


def _device(force_cpu: bool = True) -> torch.device:
    if not force_cpu and torch.cuda.is_available():
        return torch.device('cuda')
    return torch.device('cpu')


def _load_checkpoint(path: str):
    try:
        return torch.load(path, map_location='cpu', weights_only=False)
    except TypeError:
        return torch.load(path, map_location='cpu')


def _remove_null_quantization_config(payload: Any) -> int:
    """Strip Keras 3.13 null quantization fields unsupported by local Keras."""
    removed = 0
    if isinstance(payload, dict):
        if payload.get('quantization_config') is None and 'quantization_config' in payload:
            payload.pop('quantization_config')
            removed += 1
        for value in payload.values():
            removed += _remove_null_quantization_config(value)
    elif isinstance(payload, list):
        for value in payload:
            removed += _remove_null_quantization_config(value)
    return removed


def _load_keras_model_with_compat(tf, model_path: str):
    try:
        model = tf.keras.models.load_model(model_path, compile=False, safe_mode=False)
        return model, {}
    except TypeError as exc:
        first_error = exc

    if not zipfile.is_zipfile(model_path):
        raise first_error

    temp_path = ''
    removed_fields = 0
    try:
        with tempfile.NamedTemporaryFile(suffix='.keras', delete=False) as temp_file:
            temp_path = temp_file.name

        with zipfile.ZipFile(model_path, 'r') as source, zipfile.ZipFile(
            temp_path,
            'w',
            compression=zipfile.ZIP_DEFLATED,
        ) as repaired:
            for item in source.infolist():
                data = source.read(item.filename)
                if item.filename == 'config.json':
                    config = json.loads(data)
                    removed_fields = _remove_null_quantization_config(config)
                    data = json.dumps(config, separators=(',', ':')).encode('utf-8')
                repaired.writestr(item, data)

        if removed_fields <= 0:
            raise first_error

        model = tf.keras.models.load_model(temp_path, compile=False, safe_mode=False)
        return model, {
            'keras_compat_repaired': True,
            'keras_compat_removed_null_quantization_config': removed_fields,
        }
    except Exception:
        raise first_error
    finally:
        if temp_path:
            try:
                os.remove(temp_path)
            except OSError:
                pass


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
    for key in (
        'classifier.4.weight',
        'classifier.2.weight',
        'classifier.weight',
        'head.fc.weight',
        'head.weight',
        'fc.weight',
        'fc2.weight',
    ):
        tensor = state_dict.get(key)
        if tensor is not None and tensor.ndim >= 1:
            return int(tensor.shape[0]), key
    raise RuntimeError('Could not infer classifier output size from checkpoint')


def _inspect_video_model_metadata(model_path: str, labels_path: str = '') -> dict[str, Any]:
    global _video_model_error, _video_model_metadata
    if _video_model_metadata is not None:
        return _video_model_metadata

    metadata: dict[str, Any] = {
        'metadata_found': False,
        'labels_found': False,
        'enabled': False,
    }

    if not os.path.exists(model_path):
        _video_model_error = None
        _video_model_metadata = metadata
        return metadata

    try:
        checkpoint = _load_checkpoint(model_path)
        checkpoint_labels = _labels_from_checkpoint(checkpoint)
        file_labels, label_metadata = _labels_from_file(labels_path, [])
        labels = checkpoint_labels or file_labels
        state_dict = _extract_state_dict(checkpoint)
        output_classes, classifier_key = _infer_num_classes(state_dict)
        classifier_tensor = state_dict[classifier_key]
        keys = list(state_dict.keys())
        has_frame_encoder = any(key.startswith('frame_encoder.') for key in keys)
        has_temporal_head = any(key.startswith(('conv1.', 'conv2.')) for key in keys)

        enabled = bool(output_classes == 1 and has_frame_encoder and has_temporal_head)
        metadata.update(
            {
                'checkpoint_format': type(checkpoint).__name__,
                'state_dict_keys': len(state_dict),
                'architecture_hint': (
                    'frame_encoder_resnet_with_temporal_conv_head'
                    if has_frame_encoder and has_temporal_head
                    else 'unknown_torch_state_dict'
                ),
                'classifier_key': classifier_key,
                'classifier_shape': list(classifier_tensor.shape),
                'raw_output_classes': output_classes,
                'metadata_found': bool(checkpoint_labels or label_metadata),
                'labels_found': bool(labels),
                'labels': labels or None,
                'labels_path': labels_path or None,
                'enabled': enabled,
                'output_contract': 'per_frame_keyframe_score',
                'threshold': float(_app_config.get('VIDEO_KEYFRAME_THRESHOLD', 0.5)),
                'target_fps': float(_app_config.get('VIDEO_KEYFRAME_TARGET_FPS', 10)),
                'window': int(_app_config.get('VIDEO_KEYFRAME_WINDOW', 64)),
                'stride': int(_app_config.get('VIDEO_KEYFRAME_STRIDE', 32)),
            }
        )
        if not metadata['enabled']:
            metadata['disabled_reason'] = (
                'Video checkpoint does not match the notebook keyframe-score contract; keeping frame aggregation active.'
            )
        _video_model_error = None
    except Exception as exc:
        _video_model_error = str(exc)
        metadata['disabled_reason'] = f'Video checkpoint metadata inspection failed: {exc}'

    _video_model_metadata = metadata
    return metadata


def _labels_from_file(path: str, fallback: list[str]) -> tuple[list[str], dict[str, Any]]:
    metadata: dict[str, Any] = {}
    if not path or not os.path.exists(path):
        return list(fallback), metadata

    with open(path, 'r', encoding='utf-8') as label_file:
        payload = json.load(label_file)

    metadata['labels_path'] = path
    if isinstance(payload.get('class_names'), list):
        return [str(label) for label in payload['class_names']], metadata

    if isinstance(payload.get('id2label'), dict):
        def _sort_key(item):
            try:
                return int(item[0])
            except (TypeError, ValueError):
                return str(item[0])

        labels = []
        for _, value in sorted(payload['id2label'].items(), key=_sort_key):
            if isinstance(value, dict):
                labels.append(str(value.get('en') or value.get('label') or value))
            else:
                labels.append(str(value))
        metadata['ignored_class'] = payload.get('ignored_class')
        return labels, metadata

    if isinstance(payload.get('label2id'), dict):
        labels = [
            label
            for label, _ in sorted(payload['label2id'].items(), key=lambda item: int(item[1]))
        ]
        metadata['ignored_class'] = payload.get('ignored_class')
        return [str(label) for label in labels], metadata

    return list(fallback), metadata


def _labels_from_checkpoint(checkpoint: Any) -> list[str] | None:
    if isinstance(checkpoint, dict) and isinstance(checkpoint.get('class_names'), list):
        return [str(label) for label in checkpoint['class_names']]
    return None


def _details_for_labels(labels: list[str], config: CropConfig) -> dict[str, dict[str, str]]:
    details = dict(config.details)
    for label in labels:
        details.setdefault(label, _disease_details(label, f'{_display_crop(config.name)} disease'))
    return details


def _model_name_candidates(config: CropConfig) -> list[str]:
    if config.model_name in {
        'torchvision_efficientnet_b3_custom',
        'vgg16_classifier_head',
        'torchvision_convnext_tiny',
    }:
        return [config.model_name]
    candidates = [config.model_name]
    candidates.extend(name for name in SUPPORTED_BACKBONES if name not in candidates)
    return candidates


def _create_torch_model(model_name: str, num_classes: int):
    if model_name == 'torchvision_efficientnet_b3_custom':
        model = efficientnet_b3(weights=None)
        model.classifier = nn.Sequential(
            nn.Dropout(p=0.3, inplace=True),
            nn.Linear(1536, 512),
            nn.ReLU(inplace=True),
            nn.Dropout(p=0.3, inplace=True),
            nn.Linear(512, num_classes),
        )
        return model
    if model_name == 'vgg16_classifier_head':
        return VGG16FeatureClassifier(num_classes)
    if model_name == 'torchvision_convnext_tiny':
        model = convnext_tiny(weights=None)
        in_features = model.classifier[2].in_features
        model.classifier[2] = nn.Linear(in_features, num_classes)
        return model
    return timm.create_model(model_name, pretrained=False, num_classes=num_classes)


def init_model_loader(app) -> None:
    """Configure model paths. Actual model loading happens lazily."""
    global _states, _state_errors, _configured_model_paths, _configured_label_paths
    global _app_config, _validator_state, _validator_error, _video_keyframe_state
    global _video_model_error, _video_model_metadata

    _states = {}
    _state_errors = {}
    _configured_model_paths = {}
    _configured_label_paths = {}
    _validator_state = None
    _validator_error = None
    _video_keyframe_state = None
    _video_model_error = None
    _video_model_metadata = None
    _app_config = dict(app.config)

    for crop, config in CROP_CONFIGS.items():
        model_path = _model_path_for(_app_config, config)
        label_path = _label_path_for(_app_config, config)
        _configured_model_paths[crop] = model_path
        _configured_label_paths[crop] = label_path
        if not os.path.exists(model_path):
            _state_errors[crop] = f'Model file not found: {model_path}'
            app.logger.error('%s model file not found: %s', crop, model_path)


def _load_torch_crop_state(crop: str, config: CropConfig) -> ModelState:
    model_path = _configured_model_paths.get(crop) or _model_path_for(_app_config, config)
    if not os.path.exists(model_path):
        raise RuntimeError(f'Model file not found: {model_path}')

    checkpoint = _load_checkpoint(model_path)
    state_dict = _extract_state_dict(checkpoint)
    file_labels, label_metadata = _labels_from_file(
        _configured_label_paths.get(crop, ''),
        config.labels,
    )
    labels = _labels_from_checkpoint(checkpoint) or file_labels
    num_classes, classifier_key = _infer_num_classes(state_dict)
    if num_classes != len(labels):
        raise RuntimeError(
            f'Checkpoint classifier size is {num_classes} from {classifier_key}; '
            f'expected {len(labels)} labels for {crop}.'
        )

    dev = _device(force_cpu=bool(_app_config.get('MODEL_FORCE_CPU', True)))
    errors = []
    for model_name in _model_name_candidates(config):
        try:
            model = _create_torch_model(model_name, num_classes)
            if model_name == 'vgg16_classifier_head':
                missing, unexpected = model.load_state_dict(state_dict, strict=False)
                unexpected_keys = [key for key in unexpected if key]
                if unexpected_keys:
                    raise RuntimeError(f'Unexpected checkpoint keys: {unexpected_keys[:5]}')
                label_metadata['missing_feature_keys'] = len(missing)
                label_metadata['warning'] = (
                    'Corn checkpoint contains the classifier head only; VGG16 feature '
                    'extractor weights are not included in the artifact.'
                )
            else:
                model.load_state_dict(state_dict, strict=True)
            model = model.to(dev)
            model.eval()

            grad_cam: GradCAM | None = None
            try:
                target_layer = _get_target_layer(model)
                grad_cam = GradCAM(model, target_layer)
            except Exception as exc:
                logger.warning('Could not register Grad-CAM for %s: %s', crop, exc)

            return ModelState(
                model=model,
                grad_cam=grad_cam,
                metadata={
                    'model_name': model_name,
                    'num_classes': num_classes,
                    'img_size': config.img_size,
                    'classifier_key': classifier_key,
                    **label_metadata,
                },
                device=dev,
                model_path=model_path,
                config=config,
                labels=labels,
                details=_details_for_labels(labels, config),
            )
        except Exception as exc:
            errors.append(f'{model_name}: {exc}')
    raise RuntimeError(
        'Checkpoint did not match any supported backbone. '
        f'Tried: {" | ".join(errors)}'
    )


def _load_keras_crop_state(crop: str, config: CropConfig) -> ModelState:
    model_path = _configured_model_paths.get(crop) or _model_path_for(_app_config, config)
    if not os.path.exists(model_path):
        raise RuntimeError(f'Model file not found: {model_path}')

    try:
        import tensorflow as tf
    except Exception as exc:  # pragma: no cover - depends on local runtime
        raise RuntimeError(
            'TensorFlow is required for cotton_model.keras. Install detection-service requirements.'
        ) from exc

    labels, label_metadata = _labels_from_file(
        _configured_label_paths.get(crop, ''),
        config.labels,
    )
    runtime_backend = 'keras'
    runtime_metadata: dict[str, Any] = {}
    try:
        model, runtime_metadata = _load_keras_model_with_compat(tf, model_path)
        output_shape = getattr(model, 'output_shape', None)
        num_outputs = int(output_shape[-1]) if output_shape and output_shape[-1] else len(labels)
    except Exception as exc:
        tflite_path = _app_config.get('COTTON_TFLITE_MODEL_PATH') or _default_model_path(
            'cotton_model.tflite'
        )
        if crop != 'cotton' or not os.path.exists(tflite_path):
            raise
        logger.warning(
            'Keras cotton model failed to load, using TFLite fallback: %s',
            str(exc).splitlines()[0],
        )
        interpreter = tf.lite.Interpreter(model_path=tflite_path)
        interpreter.allocate_tensors()
        output_details = interpreter.get_output_details()
        output_shape = output_details[0].get('shape')
        num_outputs = int(output_shape[-1]) if output_shape is not None else len(labels)
        model = {
            'interpreter': interpreter,
            'input_details': interpreter.get_input_details(),
            'output_details': output_details,
            'model_path': tflite_path,
        }
        model_path = tflite_path
        runtime_backend = 'tflite'

    if num_outputs not in {len(labels), len(labels) + 1}:
        raise RuntimeError(
            f'{runtime_backend} model output size is {num_outputs}; expected {len(labels)} labels '
            f'or {len(labels) + 1} with an ignored class.'
        )

    return ModelState(
        model=model,
        metadata={
            'model_name': config.model_name,
            'runtime_backend': runtime_backend,
            'num_classes': len(labels),
            'raw_output_classes': num_outputs,
            'img_size': config.img_size,
            **runtime_metadata,
            **label_metadata,
        },
        device=None,
        model_path=model_path,
        config=config,
        labels=labels,
        details=_details_for_labels(labels, config),
    )


def _ensure_ready(crop_type: str | None) -> ModelState:
    crop = normalize_crop(crop_type)
    if crop not in CROP_CONFIGS:
        raise ValidationFailure(unsupported_crop_payload(crop_type))

    state = _states.get(crop)
    if state is not None:
        return state

    config = CROP_CONFIGS[crop]
    try:
        if config.runtime == 'keras':
            state = _load_keras_crop_state(crop, config)
        else:
            state = _load_torch_crop_state(crop, config)
        _states[crop] = state
        _state_errors.pop(crop, None)
        logger.info('Loaded %s model %s', crop, state.model_path)
        return state
    except Exception as exc:
        _state_errors[crop] = str(exc)
        logger.exception('Failed to load %s detection model: %s', crop, exc)
        raise RuntimeError(str(exc)) from exc


def _status_for_crop(crop: str) -> dict[str, Any]:
    config = CROP_CONFIGS[crop]
    state = _states.get(crop)
    model_path = _configured_model_paths.get(crop, _default_model_path(config.default_filename))
    label_path = _configured_label_paths.get(crop, '')
    error = _state_errors.get(crop)
    exists = os.path.exists(model_path)

    if state is not None:
        return {
            'ready': True,
            'status': 'loaded',
            'error': None,
            'runtime': config.runtime,
            'model_name': state.metadata.get('model_name', config.model_name),
            'num_classes': int(state.metadata.get('num_classes', len(state.labels))),
            'img_size': int(state.metadata.get('img_size', config.img_size)),
            'device': str(state.device) if state.device else None,
            'model_path': state.model_path,
            'labels_path': label_path or None,
        }

    if error and not exists:
        status = 'missing'
    elif error:
        status = 'failed'
    else:
        status = 'configured'

    return {
        'ready': status == 'configured',
        'status': status,
        'error': error,
        'runtime': config.runtime,
        'model_path': model_path,
        'labels_path': label_path or None,
        'model_name': config.model_name,
        'num_classes': len(config.labels),
        'img_size': config.img_size,
    }


def _special_model_status() -> dict[str, Any]:
    validator_path = _app_config.get('CROP_VALIDATOR_MODEL_PATH') or _default_model_path('crop_validator.pt')
    video_path = _app_config.get('VIDEO_MODEL_PATH') or _default_model_path('video_model_tl.pth')
    video_labels_path = _app_config.get('VIDEO_LABELS_PATH', '')
    video_exists = os.path.exists(video_path)
    video_metadata = _video_model_metadata or {
        'metadata_found': False,
        'labels_found': bool(video_labels_path and os.path.exists(video_labels_path)),
        'enabled': False,
        'lazy': True,
    }
    if not video_exists:
        video_metadata['disabled_reason'] = 'Video keyframe model file is missing.'
    return {
        'crop_validator': {
            'ready': _validator_state is not None or (not _validator_error and os.path.exists(validator_path)),
            'status': 'loaded'
            if _validator_state is not None
            else ('failed' if _validator_error else ('configured' if os.path.exists(validator_path) else 'missing')),
            'error': _validator_error,
            'model_path': validator_path,
            'labels': _validator_state.labels if _validator_state else None,
            'enabled': bool(_app_config.get('CROP_VALIDATOR_ENABLED', False)),
        },
        'video_model': {
            'ready': video_exists and _video_model_error is None,
            'status': 'loaded'
            if _video_keyframe_state is not None
            else ('failed' if _video_model_error else ('configured' if video_exists else 'missing')),
            'error': _video_model_error,
            'model_path': video_path,
            'labels_path': video_labels_path or None,
            'enabled': bool(video_metadata.get('enabled')),
            'metadata': video_metadata,
            'note': video_metadata.get(
                'disabled_reason',
                'Local frame aggregation remains the active video path until video labels/output are confirmed.',
            ),
        },
    }


def _load_video_keyframe_state() -> VideoKeyframeState:
    global _video_keyframe_state, _video_model_error
    if _video_keyframe_state is not None:
        return _video_keyframe_state

    model_path = _app_config.get('VIDEO_MODEL_PATH') or _default_model_path('video_model_tl.pth')
    if not os.path.exists(model_path):
        raise RuntimeError(f'Video keyframe model file not found: {model_path}')

    metadata = _inspect_video_model_metadata(model_path, _app_config.get('VIDEO_LABELS_PATH', ''))
    if not metadata.get('enabled'):
        raise RuntimeError(metadata.get('disabled_reason') or 'Video keyframe model is not enabled')

    checkpoint = _load_checkpoint(model_path)
    state_dict = _extract_state_dict(checkpoint)
    dev = _device(force_cpu=bool(_app_config.get('MODEL_FORCE_CPU', True)))
    model = VideoKeyframeModel()
    model.load_state_dict(state_dict, strict=True)
    model = model.to(dev)
    model.eval()

    _video_keyframe_state = VideoKeyframeState(
        model=model,
        device=dev,
        model_path=model_path,
        metadata=metadata,
    )
    _video_model_error = None
    return _video_keyframe_state


def _load_keyframe_video_frames(video_path: str, target_fps: float, max_source_frames: int = 0) -> np.ndarray:
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise ValueError('Could not open video')

    native_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frame_interval = max(1, int(round(native_fps / target_fps)))
    frames: list[np.ndarray] = []
    frame_idx = 0

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            if frame_idx % frame_interval == 0:
                frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                frame = cv2.resize(frame, (224, 224), interpolation=cv2.INTER_AREA)
                frames.append(frame)
                if max_source_frames and len(frames) >= max_source_frames:
                    break
            frame_idx += 1
    finally:
        cap.release()

    if not frames:
        raise ValueError('No frames extracted')

    return np.asarray(frames, dtype=np.float32) / 255.0


def _keyframe_scores_for_video_tensor(
    frames: np.ndarray,
    state: VideoKeyframeState,
    window: int,
    stride: int,
) -> np.ndarray:
    num_frames = int(frames.shape[0])
    all_scores = np.zeros(num_frames, dtype=np.float32)

    for start in range(0, num_frames, stride):
        end = start + window
        chunk = frames[start:end]
        if len(chunk) < window:
            pad_len = window - len(chunk)
            pad = np.repeat(chunk[-1:], pad_len, axis=0)
            chunk = np.concatenate([chunk, pad], axis=0)

        tensor = torch.from_numpy(chunk).permute(0, 3, 1, 2).unsqueeze(0).to(state.device)
        with torch.no_grad():
            scores = state.model(tensor)[0, :, 0].detach().cpu().numpy()

        for offset, score in enumerate(scores):
            idx = start + offset
            if idx < num_frames:
                all_scores[idx] = max(float(all_scores[idx]), float(score))

    return all_scores


def _select_keyframe_peaks(
    scores: np.ndarray,
    threshold: float = 0.5,
    min_distance: int = 5,
    max_frames: int = 20,
) -> list[int]:
    if scores.size == 0:
        return []
    max_frames = max(1, int(max_frames))

    candidates: list[tuple[int, float]] = []
    for idx, score in enumerate(scores):
        left = scores[idx - 1] if idx > 0 else -np.inf
        right = scores[idx + 1] if idx < scores.size - 1 else -np.inf
        if float(score) >= threshold and float(score) >= float(left) and float(score) >= float(right):
            candidates.append((idx, float(score)))

    if not candidates:
        candidates = [(idx, float(score)) for idx, score in enumerate(scores) if float(score) >= threshold]

    if not candidates:
        limit = max(1, min(max_frames, int(scores.size)))
        return sorted(int(idx) for idx in np.argsort(scores)[::-1][:limit])

    selected: list[int] = []
    for idx, _ in sorted(candidates, key=lambda item: item[1], reverse=True):
        if all(abs(idx - existing) >= min_distance for existing in selected):
            selected.append(idx)
        if len(selected) >= max_frames:
            break
    return sorted(selected)


def select_video_keyframes(video_path: str, max_frames: int | None = None) -> dict[str, Any]:
    state = _load_video_keyframe_state()
    target_fps = float(_app_config.get('VIDEO_KEYFRAME_TARGET_FPS', 10))
    window = int(_app_config.get('VIDEO_KEYFRAME_WINDOW', 64))
    stride = int(_app_config.get('VIDEO_KEYFRAME_STRIDE', 32))
    threshold = float(_app_config.get('VIDEO_KEYFRAME_THRESHOLD', 0.5))
    min_distance = int(_app_config.get('VIDEO_KEYFRAME_MIN_DISTANCE', 5))
    source_cap = int(_app_config.get('VIDEO_KEYFRAME_MAX_SOURCE_FRAMES', 600))
    max_selected = max(1, int(max_frames or _app_config.get('VIDEO_KEYFRAME_MAX_SELECTED', 20)))

    frames = _load_keyframe_video_frames(video_path, target_fps, source_cap)
    scores = _keyframe_scores_for_video_tensor(frames, state, window, stride)
    selected_indices = _select_keyframe_peaks(scores, threshold, min_distance, max_selected)

    return {
        'source': 'video_keyframe_model',
        'model_version': 'resnet50-conv1d-keyframe-local-v1',
        'model_path': state.model_path,
        'output_contract': state.metadata.get('output_contract', 'per_frame_keyframe_score'),
        'target_fps': target_fps,
        'input_frames': int(frames.shape[0]),
        'selected_indices': selected_indices,
        'selected_scores': [round(float(scores[idx]), 4) for idx in selected_indices],
        'threshold': threshold,
        'min_distance': min_distance,
        'window': window,
        'stride': stride,
    }


def get_model_status(crop_type: str | None = None) -> dict[str, Any]:
    if crop_type:
        crop = normalize_crop(crop_type)
        if crop not in CROP_CONFIGS:
            return {
                'ready': False,
                'status': 'unsupported',
                'error': f'Unsupported crop type: {crop_type}',
                'supported_crops': supported_crops(),
            }
        return _status_for_crop(crop)

    models = {crop: _status_for_crop(crop) for crop in supported_crops()}
    return {
        'ready': all(model['status'] in {'configured', 'loaded'} for model in models.values()),
        'supported_crops': supported_crops(),
        'models': models,
        'special_models': _special_model_status(),
    }


def _prepare_torch_tensor(image_bgr: np.ndarray, img_size: int, device: torch.device) -> torch.Tensor:
    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    resized = cv2.resize(image_rgb, (img_size, img_size), interpolation=cv2.INTER_AREA)
    image_float = resized.astype(np.float32) / 255.0
    normalized = (image_float - IMAGENET_MEAN) / IMAGENET_STD
    chw = np.transpose(normalized, (2, 0, 1)).copy()
    return torch.from_numpy(chw).unsqueeze(0).to(device)


def _prepare_keras_batch(image_bgr: np.ndarray, img_size: int) -> np.ndarray:
    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    resized = cv2.resize(image_rgb, (img_size, img_size), interpolation=cv2.INTER_AREA)
    normalized = resized.astype(np.float32) / 127.5 - 1.0
    return np.expand_dims(normalized, axis=0)

def _probabilities_from_outputs(outputs: Any) -> np.ndarray:
    probs = np.asarray(outputs)
    if probs.ndim > 1:
        probs = probs[0]
    probs = probs.astype(np.float32)
    if probs.size == 1:
        probs = np.array([1.0 - float(probs[0]), float(probs[0])], dtype=np.float32)
    total = float(probs.sum())
    if total <= 0 or not np.isclose(total, 1.0, atol=1e-3):
        shifted = probs - np.max(probs)
        exp = np.exp(shifted)
        probs = exp / exp.sum()
    return probs


def _build_prediction_result(
    state: ModelState,
    probabilities: np.ndarray,
    source: str = 'image',
) -> dict[str, Any]:
    labels = state.labels
    ignored = state.metadata.get('ignored_class')
    if len(probabilities) == len(labels) + 1 and isinstance(ignored, dict):
        ignored_index = int(ignored.get('index', 0))
        probabilities = np.delete(probabilities, ignored_index)

    if len(probabilities) != len(labels):
        raise RuntimeError(
            f'Model returned {len(probabilities)} probabilities for {len(labels)} labels.'
        )

    predicted_id = int(np.argmax(probabilities))
    confidence = float(probabilities[predicted_id])
    predicted_label = labels[predicted_id]
    details = state.details[predicted_label]
    top_indices = np.argsort(probabilities)[::-1][: min(3, len(labels))]

    top_predictions = []
    for idx in top_indices:
        raw_label = labels[int(idx)]
        label_details = state.details[raw_label]
        top_predictions.append(
            {
                'class_id': int(idx),
                'label': raw_label,
                'disease': label_details['disease'],
                'confidence': round(float(probabilities[int(idx)]), 4),
            }
        )

    return {
        'crop_type': state.config.name,
        'label': predicted_label,
        'disease': details['disease'],
        'scientific_name': details['scientific_name'],
        'confidence': round(confidence, 4),
        'severity': details['severity'],
        'is_healthy': details['severity'] == 'none',
        'risk_level': details['risk_level'],
        'recommendation': details['recommendation'],
        'top_predictions': top_predictions,
        'model_version': f"{state.metadata.get('model_name', state.config.model_name)}-{state.config.name}-local-v1",
        'model_input_size': int(state.metadata.get('img_size', state.config.img_size)),
        'source': source,
        '_predicted_id': predicted_id,
    }


def _predict_from_bgr(image_bgr: np.ndarray, crop_type: str | None) -> dict[str, Any]:
    state = _ensure_ready(crop_type)
    img_size = int(state.metadata.get('img_size', state.config.img_size))

    if state.config.runtime == 'keras':
        batch = _prepare_keras_batch(image_bgr, img_size)
        if state.metadata.get('runtime_backend') == 'tflite':
            interpreter = state.model['interpreter']
            input_details = state.model['input_details']
            output_details = state.model['output_details']
            interpreter.set_tensor(input_details[0]['index'], batch.astype(np.float32))
            interpreter.invoke()
            outputs = interpreter.get_tensor(output_details[0]['index'])
        else:
            outputs = state.model.predict(batch, verbose=0)
        probabilities = _probabilities_from_outputs(outputs)
        return _build_prediction_result(state, probabilities)

    input_tensor = _prepare_torch_tensor(image_bgr, img_size, state.device)
    with torch.no_grad():
        outputs = state.model(input_tensor)
        probabilities = torch.softmax(outputs, dim=1)[0].detach().cpu().numpy()
    return _build_prediction_result(state, probabilities)


def _decode_image(file_bytes: bytes) -> np.ndarray:
    image = cv2.imdecode(np.frombuffer(file_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError('Could not decode image bytes')
    return image


def _load_validator_state() -> ValidatorState:
    global _validator_state, _validator_error
    if _validator_state is not None:
        return _validator_state

    model_path = _app_config.get('CROP_VALIDATOR_MODEL_PATH') or _default_model_path('crop_validator.pt')
    if not os.path.exists(model_path):
        raise RuntimeError(f'Crop validator model file not found: {model_path}')

    checkpoint = _load_checkpoint(model_path)
    labels = _labels_from_checkpoint(checkpoint)
    if not labels:
        label_path = _app_config.get('CROP_VALIDATOR_LABELS_PATH') or _default_model_path('crop_validator_labels.json')
        labels, _ = _labels_from_file(label_path, [])
    if not labels:
        raise RuntimeError('Crop validator labels were not found in checkpoint or label file')
    normalized_labels = _validate_crop_validator_label_contract(labels)

    state_dict = _extract_state_dict(checkpoint)
    num_classes, classifier_key = _infer_num_classes(state_dict)
    if num_classes != len(labels):
        raise RuntimeError(
            f'Crop validator classifier size is {num_classes}; expected {len(labels)} labels.'
        )

    dev = _device(force_cpu=bool(_app_config.get('MODEL_FORCE_CPU', True)))
    model = _create_torch_model('torchvision_convnext_tiny', num_classes)
    model.load_state_dict(state_dict, strict=True)
    model = model.to(dev)
    model.eval()
    _validator_state = ValidatorState(
        model=model,
        labels=normalized_labels,
        device=dev,
        model_path=model_path,
        metadata={
            'classifier_key': classifier_key,
            'num_classes': num_classes,
            'img_size': 224,
            'raw_labels': labels,
        },
    )
    _validator_error = None
    return _validator_state


def _validation_payload(
    error_code: str,
    selected_crop: str,
    detected_crop: str | None,
    confidence: float | None,
) -> dict[str, Any]:
    if error_code == 'NOT_A_PLANT':
        message = 'This does not appear to be a plant. Please upload a clear scan of a plant.'
        plant_status = 'not_plant'
    elif error_code == 'CROP_MISMATCH':
        message = f'This appears to be {_display_crop(detected_crop or "")}, not {_display_crop(selected_crop)}.'
        plant_status = 'supported_crop'
    else:
        message = 'This crop is not supported yet. Please choose one of the supported crops.'
        plant_status = 'unsupported_crop'

    return {
        'error': message,
        'error_code': error_code,
        'plant_status': plant_status,
        'valid': False,
        'selected_crop': selected_crop,
        'detected_crop': detected_crop or 'unknown_plant',
        'confidence': round(float(confidence), 4) if confidence is not None else None,
        'supported_crops': supported_crops(),
        'message': message,
    }


def validate_image_bgr(image_bgr: np.ndarray, crop_type: str | None) -> dict[str, Any]:
    selected_crop = normalize_crop(crop_type)
    if selected_crop not in CROP_CONFIGS:
        raise ValidationFailure(unsupported_crop_payload(crop_type))

    if not bool(_app_config.get('CROP_VALIDATOR_ENABLED', False)):
        return {
            'valid': True,
            'plant_status': 'validator_disabled',
            'selected_crop': selected_crop,
            'detected_crop': selected_crop,
            'supported_crops': supported_crops(),
        }

    global _validator_error
    try:
        state = _load_validator_state()
    except Exception as exc:
        _validator_error = str(exc)
        logger.warning('Crop validation skipped: %s', exc)
        return {
            'valid': True,
            'plant_status': 'validator_unavailable',
            'selected_crop': selected_crop,
            'detected_crop': selected_crop,
            'supported_crops': supported_crops(),
            'warning': str(exc),
        }

    input_tensor = _prepare_torch_tensor(
        image_bgr,
        int(state.metadata.get('img_size', 224)),
        state.device,
    )
    with torch.no_grad():
        outputs = state.model(input_tensor)
        probabilities = torch.softmax(outputs, dim=1)[0].detach().cpu().numpy()

    predicted_id = int(np.argmax(probabilities))
    confidence = float(probabilities[predicted_id])
    detected_crop = normalize_crop(state.labels[predicted_id])
    detected_key = _validator_label_key(detected_crop)
    not_plant_threshold = float(_app_config.get('CROP_VALIDATOR_NOT_PLANT_THRESHOLD', 0.35))
    supported_threshold = float(_app_config.get('CROP_VALIDATOR_SUPPORTED_THRESHOLD', 0.65))

    if detected_key in VALIDATOR_NOT_PLANT_LABEL_KEYS or confidence < not_plant_threshold:
        raise ValidationFailure(
            _validation_payload('NOT_A_PLANT', selected_crop, detected_crop, confidence)
        )

    if (
        detected_key in VALIDATOR_UNSUPPORTED_PLANT_LABEL_KEYS
        or confidence < supported_threshold
        or detected_crop not in CROP_CONFIGS
    ):
        raise ValidationFailure(
            _validation_payload('UNSUPPORTED_CROP', selected_crop, 'unknown_plant', confidence)
        )

    if detected_crop != selected_crop:
        raise ValidationFailure(
            _validation_payload('CROP_MISMATCH', selected_crop, detected_crop, confidence)
        )

    return {
        'valid': True,
        'plant_status': 'supported_crop',
        'selected_crop': selected_crop,
        'detected_crop': detected_crop,
        'confidence': round(confidence, 4),
        'supported_crops': supported_crops(),
    }


def _predict_validated(image_bgr: np.ndarray, crop_type: str | None, include_gradcam: bool) -> dict[str, Any]:
    validation = validate_image_bgr(image_bgr, crop_type)
    result = (
        _predict_from_bgr_with_gradcam(image_bgr, crop_type)
        if include_gradcam
        else _predict_from_bgr(image_bgr, crop_type)
    )
    if (
        validation.get('plant_status') == 'validator_unavailable'
        and float(result.get('confidence') or 0.0)
        < float(_app_config.get('MIN_PLANT_CONFIDENCE', MIN_PLANT_CONFIDENCE))
    ):
        raise ValidationFailure(
            _validation_payload(
                'NOT_A_PLANT',
                normalize_crop(crop_type),
                None,
                float(result.get('confidence') or 0.0),
            )
        )
    result.pop('_predicted_id', None)
    result['validation'] = validation
    return result


def predict_from_file_bytes(file_bytes: bytes, crop_type: str | None = 'tomato') -> dict[str, Any]:
    image = _decode_image(file_bytes)
    return _predict_validated(image, crop_type, include_gradcam=False)


def predict_from_url(
    image_url: str,
    crop_type: str | None = 'tomato',
    timeout: int = 15,
) -> dict[str, Any]:
    response = requests.get(image_url, timeout=timeout)
    response.raise_for_status()
    return predict_from_file_bytes(response.content, crop_type)


def _predict_from_bgr_with_gradcam(image_bgr: np.ndarray, crop_type: str | None) -> dict[str, Any]:
    result = _predict_from_bgr(image_bgr, crop_type)
    state = _ensure_ready(crop_type)
    if state.config.runtime != 'torch' or state.grad_cam is None:
        result['gradcam_overlay'] = None
        result.pop('_predicted_id', None)
        return result

    img_size = int(state.metadata.get('img_size', state.config.img_size))
    input_tensor = _prepare_torch_tensor(image_bgr, img_size, state.device)
    predicted_id = result.get('_predicted_id')

    try:
        inp_grad = input_tensor.clone().requires_grad_(True)
        with torch.enable_grad():
            cam = state.grad_cam.generate(
                inp_grad,
                class_idx=predicted_id,
                output_size=(img_size, img_size),
            )

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
    image = _decode_image(file_bytes)
    return _predict_validated(image, crop_type, include_gradcam=True)


def predict_from_url_with_gradcam(
    image_url: str,
    crop_type: str | None = 'tomato',
    timeout: int = 15,
) -> dict[str, Any]:
    response = requests.get(image_url, timeout=timeout)
    response.raise_for_status()
    return predict_from_file_bytes_with_gradcam(response.content, crop_type)
