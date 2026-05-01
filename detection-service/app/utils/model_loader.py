"""
Multi-crop disease classifier loader backed by PyTorch `.pth` checkpoints.
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
from torch import nn
from torchvision.models import efficientnet_b3

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

MUSHROOM_LABELS = [
    'Agaricus_augustus',
    'Agaricus_xanthodermus',
    'Amanita_amerirubescens',
    'Amanita_augusta',
    'Amanita_brunnescens',
    'Amanita_calyptroderma',
    'Amanita_flavoconia',
    'Amanita_muscaria',
    'Amanita_persicina',
    'Amanita_phalloides',
    'Amanita_velosa',
    'Armillaria_mellea',
    'Armillaria_tabescens',
    'Artomyces_pyxidatus',
    'Bolbitius_titubans',
    'Boletus_pallidus',
    'Boletus_rex-veris',
    'Cantharellus_californicus',
    'Cantharellus_cinnabarinus',
    'Cerioporus_squamosus',
    'Chlorophyllum_brunneum',
    'Chlorophyllum_molybdites',
    'Clitocybe_nuda',
    'Coprinellus_micaceus',
    'Coprinopsis_lagopus',
    'Coprinus_comatus',
    'Crucibulum_laeve',
    'Cryptoporus_volvatus',
    'Daedaleopsis_confragosa',
    'Entoloma_abortivum',
    'Flammulina_velutipes',
    'Fomitopsis_mounceae',
    'Galerina_marginata',
    'Ganoderma_applanatum',
    'Ganoderma_curtisii',
    'Ganoderma_oregonense',
    'Ganoderma_tsugae',
    'Gliophorus_psittacinus',
    'Gloeophyllum_sepiarium',
    'Grifola_frondosa',
    'Gymnopilus_luteofolius',
    'Hericium_coralloides',
    'Hericium_erinaceus',
    'Hygrophoropsis_aurantiaca',
    'Hypholoma_fasciculare',
    'Hypholoma_lateritium',
    'Hypomyces_lactifluorum',
    'Ischnoderma_resinosum',
    'Laccaria_ochropurpurea',
    'Laetiporus_sulphureus',
    'Leratiomyces_ceres',
    'Leucoagaricus_americanus',
    'Leucoagaricus_leucothites',
    'Lycogala_epidendrum',
    'Lycoperdon_perlatum',
    'Lycoperdon_pyriforme',
    'Mycena_haematopus',
    'Mycena_leaiana',
    'Omphalotus_illudens',
    'Omphalotus_olivascens',
    'Panaeolus_papilionaceus',
    'Panellus_stipticus',
    'Phaeolus_schweinitzii',
    'Phlebia_tremellosa',
    'Phyllotopsis_nidulans',
    'Pleurotus_ostreatus',
    'Pleurotus_pulmonarius',
    'Psathyrella_candolleana',
    'Pseudohydnum_gelatinosum',
    'Psilocybe_azurescens',
    'Psilocybe_caerulescens',
    'Psilocybe_cubensis',
    'Psilocybe_cyanescens',
    'Psilocybe_ovoideocystidiata',
    'Psilocybe_pelliculosa',
    'Retiboletus_ornatipes',
    'Sarcomyxa_serotina',
    'Schizophyllum_commune',
    'Stereum_hirsutum',
    'Stereum_ostrea',
    'Stropharia_ambigua',
    'Suillus_americanus',
    'Suillus_luteus',
    'Suillus_spraguei',
    'Tapinella_atrotomentosa',
    'Trametes_betulina',
    'Trametes_gibbosa',
    'Trametes_versicolor',
    'Trichaptum_biforme',
    'Tricholoma_murrillianum',
    'Tricholomopsis_rutilans',
    'Tylopilus_felleus',
    'Tylopilus_rubrobrunneus',
    'Volvopluteus_gloiocephalus',
]


def _format_label(label: str) -> str:
    return label.replace('_', ' ')


def _disease_details(label: str, scientific_name: str = 'Plant disease') -> dict[str, str]:
    if label.lower() == 'healthy':
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


def _mushroom_details(label: str) -> dict[str, str]:
    species = _format_label(label)
    return _details(
        f'Mushroom species: {species}',
        species,
        'none',
        'low',
        'Species classification only. Do not use this result as edibility or safety advice.',
    )


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
    'grape': CropConfig(
        name='grape',
        env_key='GRAPE_MODEL_PATH',
        default_filename='grape_model.pth',
        img_size=384,
        model_name='efficientnet_b3',
        labels=GRAPE_LABELS,
        details={label: _disease_details(label, 'Grape disease') for label in GRAPE_LABELS},
    ),
    'wheat': CropConfig(
        name='wheat',
        env_key='WHEAT_MODEL_PATH',
        default_filename='wheat_model.pth',
        img_size=384,
        model_name='torchvision_efficientnet_b3_custom',
        labels=WHEAT_LABELS,
        details={label: _disease_details(label, 'Wheat disease or pest') for label in WHEAT_LABELS},
    ),
    'mushroom': CropConfig(
        name='mushroom',
        env_key='MUSHROOM_MODEL_PATH',
        default_filename='mushroom_model.pth',
        img_size=384,
        model_name='torchvision_efficientnet_b3_custom',
        labels=MUSHROOM_LABELS,
        details={label: _mushroom_details(label) for label in MUSHROOM_LABELS},
    ),
}

ALIASES = {
    'apples': 'apple',
    'grapes': 'grape',
    'mushrooms': 'mushroom',
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
    for key in ('classifier.4.weight', 'classifier.weight', 'head.fc.weight', 'fc.weight'):
        tensor = state_dict.get(key)
        if tensor is not None and tensor.ndim >= 1:
            return int(tensor.shape[0]), key
    raise RuntimeError('Could not infer classifier output size from checkpoint')


def _model_name_candidates(config: CropConfig) -> list[str]:
    if config.model_name == 'torchvision_efficientnet_b3_custom':
        return [config.model_name]
    candidates = [config.model_name]
    candidates.extend(name for name in SUPPORTED_BACKBONES if name not in candidates)
    return candidates


def _create_model(model_name: str, num_classes: int):
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
    return timm.create_model(
        model_name,
        pretrained=False,
        num_classes=num_classes,
    )


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
                    model = _create_model(model_name, num_classes)
                    model.load_state_dict(state_dict, strict=True)
                    model = model.to(dev)
                    model.eval()
                    _states[crop] = ModelState(
                        model=model,
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
    }


def predict_from_file_bytes(file_bytes: bytes, crop_type: str | None = 'tomato') -> dict[str, Any]:
    image = cv2.imdecode(np.frombuffer(file_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError('Could not decode image bytes')
    return _predict_from_bgr(image, crop_type)


def predict_from_url(
    image_url: str,
    crop_type: str | None = 'tomato',
    timeout: int = 15,
) -> dict[str, Any]:
    response = requests.get(image_url, timeout=timeout)
    response.raise_for_status()
    return predict_from_file_bytes(response.content, crop_type)
