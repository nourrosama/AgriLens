"""
Real tomato disease classifier loader backed by a custom HDF5-exported
PyTorch state_dict from the training notebook.
"""
from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass
from typing import Any

import cv2
import h5py
import numpy as np
import requests
import timm
import torch

logger = logging.getLogger(__name__)

IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

TOMATO_LABELS = [
    "Tomato___Bacterial_spot",
    "Tomato___Early_blight",
    "Tomato___Late_blight",
    "Tomato___Leaf_Mold",
    "Tomato___Septoria_leaf_spot",
    "Tomato___Spider_mites Two-spotted_spider_mite",
    "Tomato___Target_Spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato___Tomato_mosaic_virus",
    "Tomato___healthy",
]

LABEL_DETAILS = {
    "Tomato___Bacterial_spot": {
        "disease": "Bacterial spot",
        "scientific_name": "Xanthomonas spp.",
        "severity": "high",
        "risk_level": "high",
        "recommendation": "Remove infected leaves, avoid overhead irrigation, and sanitize tools between plants.",
    },
    "Tomato___Early_blight": {
        "disease": "Early blight",
        "scientific_name": "Alternaria solani",
        "severity": "medium",
        "risk_level": "medium",
        "recommendation": "Remove damaged leaves and begin preventive fungicide coverage if spread is increasing.",
    },
    "Tomato___Late_blight": {
        "disease": "Late blight",
        "scientific_name": "Phytophthora infestans",
        "severity": "high",
        "risk_level": "high",
        "recommendation": "Isolate infected plants quickly and reduce leaf wetness immediately to slow spread.",
    },
    "Tomato___Leaf_Mold": {
        "disease": "Leaf mold",
        "scientific_name": "Passalora fulva",
        "severity": "medium",
        "risk_level": "medium",
        "recommendation": "Improve ventilation, reduce humidity, and remove heavily affected lower foliage.",
    },
    "Tomato___Septoria_leaf_spot": {
        "disease": "Septoria leaf spot",
        "scientific_name": "Septoria lycopersici",
        "severity": "medium",
        "risk_level": "medium",
        "recommendation": "Prune affected leaves and avoid splashing water onto foliage during irrigation.",
    },
    "Tomato___Spider_mites Two-spotted_spider_mite": {
        "disease": "Spider mites",
        "scientific_name": "Tetranychus urticae",
        "severity": "medium",
        "risk_level": "medium",
        "recommendation": "Inspect leaf undersides, raise humidity when possible, and treat hotspots early.",
    },
    "Tomato___Target_Spot": {
        "disease": "Target spot",
        "scientific_name": "Corynespora cassiicola",
        "severity": "medium",
        "risk_level": "medium",
        "recommendation": "Remove infected foliage and keep plant spacing open enough for faster drying.",
    },
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": {
        "disease": "Tomato yellow leaf curl virus",
        "scientific_name": "Tomato yellow leaf curl virus",
        "severity": "high",
        "risk_level": "high",
        "recommendation": "Control whiteflies aggressively and separate infected plants from healthy ones.",
    },
    "Tomato___Tomato_mosaic_virus": {
        "disease": "Tomato mosaic virus",
        "scientific_name": "Tomato mosaic virus",
        "severity": "high",
        "risk_level": "high",
        "recommendation": "Discard infected material and disinfect hands and tools to prevent mechanical spread.",
    },
    "Tomato___healthy": {
        "disease": "Healthy",
        "scientific_name": "Healthy plant",
        "severity": "none",
        "risk_level": "low",
        "recommendation": "No disease detected. Keep monitoring and maintain balanced irrigation and airflow.",
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


def _default_model_path() -> str:
    return os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            "..",
            "..",
            "..",
            "models",
            "tomato_model.h5",
        )
    )


def _device(force_cpu: bool = True) -> torch.device:
    if not force_cpu and torch.cuda.is_available():
        return torch.device("cuda")
    return torch.device("cpu")


def _recursive_state_dict(group: h5py.Group, prefix: str = "") -> dict[str, torch.Tensor]:
    state_dict: dict[str, torch.Tensor] = {}
    for name, item in group.items():
        full_name = f"{prefix}.{name}" if prefix else name
        if isinstance(item, h5py.Group):
            state_dict.update(_recursive_state_dict(item, full_name))
            continue
        data = item[()]
        if np.isscalar(data):
            tensor = torch.tensor(data)
        else:
            tensor = torch.from_numpy(np.array(data))
        state_dict[full_name] = tensor
    return state_dict


def _load_metadata(handle: h5py.File) -> dict[str, Any]:
    raw = handle.attrs.get("metadata")
    if raw is None:
        return {
            "model_name": "efficientnet_b3",
            "num_classes": len(TOMATO_LABELS),
            "img_size": 384,
        }
    if isinstance(raw, bytes):
        raw = raw.decode("utf-8", errors="ignore")
    metadata = json.loads(str(raw))
    metadata.setdefault("model_name", "efficientnet_b3")
    metadata.setdefault("num_classes", len(TOMATO_LABELS))
    metadata.setdefault("img_size", 384)
    return metadata


def _build_model(metadata: dict[str, Any], device: torch.device) -> torch.nn.Module:
    model_name = metadata.get("model_name", "efficientnet_b3")
    num_classes = int(metadata.get("num_classes", len(TOMATO_LABELS)))
    model = timm.create_model(model_name, pretrained=False, num_classes=num_classes)
    return model.to(device)


def init_model_loader(app) -> None:
    """Load the tomato model once at startup."""
    global _state, _state_error

    model_path = app.config.get("MODEL_PATH") or _default_model_path()
    force_cpu = app.config.get("MODEL_FORCE_CPU", True)
    dev = _device(force_cpu=force_cpu)

    if not os.path.exists(model_path):
        _state = None
        _state_error = f"Model file not found: {model_path}"
        app.logger.error(_state_error)
        return

    try:
        with h5py.File(model_path, "r") as handle:
            metadata = _load_metadata(handle)
            weight_group = handle["weights"]
            state_dict = _recursive_state_dict(weight_group)

        model = _build_model(metadata, dev)
        missing, unexpected = model.load_state_dict(state_dict, strict=False)
        if missing or unexpected:
            raise RuntimeError(
                f"State dict mismatch. Missing={missing} Unexpected={unexpected}"
            )
        model.eval()

        _state = ModelState(
            model=model,
            metadata=metadata,
            device=dev,
            model_path=model_path,
        )
        _state_error = None
        app.logger.info(
            "Loaded tomato detection model %s from %s on %s",
            metadata.get("model_name"),
            model_path,
            dev,
        )
    except Exception as exc:  # pragma: no cover - runtime safety
        _state = None
        _state_error = str(exc)
        app.logger.exception("Failed to load tomato detection model: %s", exc)


def get_model_status() -> dict[str, Any]:
    if _state is None:
        return {
            "ready": False,
            "error": _state_error,
            "model_path": _default_model_path(),
        }
    return {
        "ready": True,
        "error": None,
        "model_name": _state.metadata.get("model_name", "efficientnet_b3"),
        "num_classes": int(_state.metadata.get("num_classes", len(TOMATO_LABELS))),
        "img_size": int(_state.metadata.get("img_size", 384)),
        "device": str(_state.device),
        "model_path": _state.model_path,
    }


def _ensure_ready() -> ModelState:
    if _state is None:
        raise RuntimeError(_state_error or "Tomato model is not loaded")
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
    img_size = int(state.metadata.get("img_size", 384))
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
                "class_id": int(idx),
                "label": raw_label,
                "disease": label_details["disease"],
                "confidence": round(float(prob), 4),
            }
        )

    return {
        "crop_type": "tomato",
        "label": predicted_label,
        "disease": details["disease"],
        "scientific_name": details["scientific_name"],
        "confidence": round(confidence, 4),
        "severity": details["severity"],
        "is_healthy": predicted_label == "Tomato___healthy",
        "risk_level": details["risk_level"],
        "recommendation": details["recommendation"],
        "top_predictions": top_predictions,
        "model_version": f"{state.metadata.get('model_name', 'efficientnet_b3')}-tomato-hdf5-v1",
        "model_input_size": img_size,
    }


def predict_from_file_bytes(file_bytes: bytes) -> dict[str, Any]:
    image = cv2.imdecode(np.frombuffer(file_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Could not decode image bytes")
    return _predict_from_bgr(image)


def predict_from_url(image_url: str, timeout: int = 15) -> dict[str, Any]:
    response = requests.get(image_url, timeout=timeout)
    response.raise_for_status()
    return predict_from_file_bytes(response.content)
