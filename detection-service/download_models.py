"""
Downloads model files from Azure Blob Storage at container startup.
Set MODEL_BASE_URL env var to your Azure Blob container URL.
e.g. https://agrilens.blob.core.windows.net/models/
"""
import os
import sys
import urllib.request

MODEL_BASE_URL = os.environ.get("MODEL_BASE_URL", "").rstrip("/") + "/"

MODELS = [
    "tomato_model.pth",
    "apple_model.pth",
    "potato_model.pth",
    "grape_effb3_best.pth",
    "wheat_disease_detector.pth",
    "mushroom_disease_classifier.pth",
]

MODELS_DIR = "/app/models"


def download_models():
    if not MODEL_BASE_URL.strip("/"):
        print("MODEL_BASE_URL not set — skipping model download (local mode)")
        return

    os.makedirs(MODELS_DIR, exist_ok=True)

    for filename in MODELS:
        path = os.path.join(MODELS_DIR, filename)

        if os.path.exists(path):
            size_mb = os.path.getsize(path) / 1024 / 1024
            print(f"  {filename} already present ({size_mb:.1f} MB), skipping")
            continue

        url = MODEL_BASE_URL + filename
        print(f"  Downloading {filename} from Azure Blob Storage...")
        try:
            urllib.request.urlretrieve(url, path)
            size_mb = os.path.getsize(path) / 1024 / 1024
            print(f"  Downloaded {filename} ({size_mb:.1f} MB)")
        except Exception as e:
            print(f"  WARNING: Could not download {filename}: {e}")


if __name__ == "__main__":
    print("=== Model Download ===")
    download_models()
    print("=== Done ===")
