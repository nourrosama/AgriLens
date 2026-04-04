import io, json, h5py
import numpy as np
import torch
import timm
import albumentations as A
from albumentations.pytorch import ToTensorV2
from PIL import Image

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# ── Load label mapping ──
with open("ml_models/paddy/label_mapping.json") as f:
    mapping = json.load(f)

ID2LABEL    = {int(k): v for k, v in mapping["id2label"].items()}
NUM_CLASSES = mapping["num_classes"]
IMG_SIZE    = mapping["img_size"]
MODEL_NAME  = mapping["model_name"]

# ── Load model once at startup ──
def _load_model():
    model = timm.create_model(MODEL_NAME, pretrained=False, num_classes=NUM_CLASSES)
    state_dict = {}
    with h5py.File("ml_models/paddy/model.h5", "r") as hf:
        def _collect(name, obj):
            if isinstance(obj, h5py.Dataset):
                key = name.replace("weights/", "", 1).replace("/", ".")
                state_dict[key] = torch.tensor(np.array(obj))
        hf.visititems(_collect)
    model.load_state_dict(state_dict)
    model.to(DEVICE).eval()
    return model

_model = _load_model()

# ── Preprocessing ──
_transform = A.Compose([
    A.Resize(IMG_SIZE, IMG_SIZE),
    A.Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
    ToTensorV2()
])

# ── Predict ──
def predict(image_bytes: bytes) -> dict:
    image  = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    tensor = _transform(image=np.array(image))["image"].unsqueeze(0).to(DEVICE)
    with torch.no_grad():
        probs = torch.softmax(_model(tensor), dim=1)[0]
    conf, idx = probs.max(dim=0)
    return {
        "predicted_class": ID2LABEL[idx.item()],
        "confidence":      round(conf.item(), 4),
        "probabilities":   {ID2LABEL[i]: round(probs[i].item(), 4) for i in range(NUM_CLASSES)}
    }