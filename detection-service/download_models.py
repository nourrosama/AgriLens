"""Download model files at container startup.

Priority:
  1. AWS S3 if AWS_S3_BUCKET is set.
  2. Direct URL if MODEL_BASE_URL is set.
  3. Local volume if neither is set.

Required disease models are reported as missing when absent. Optional files such
as the disabled crop validator are allowed to be absent for demo staging.
"""
import os
import urllib.request

MODELS_DIR = os.environ.get("MODELS_DIR", "/models")

REQUIRED_MODEL_FILES = [
    "tomato_model.pth",
    "potato_model.pth",
    "apple_model.pth",
    "grape_effb3_best.pth",
    "wheat_disease_detector.pth",
    "corn_model.pth",
    "sugarcane_model.pt",
    "cotton_model.keras",
    "corn_labels.json",
    "sugarcane_labels.json",
    "cotton_label_mapping.json",
]

OPTIONAL_MODEL_FILES = [
    "cotton_model.tflite",
    "crop_validator.pt",
    "crop_validator_labels.json",
    "video_model_tl.pth",
]

MODEL_FILES = REQUIRED_MODEL_FILES + OPTIONAL_MODEL_FILES


def _already_present(filename: str) -> bool:
    path = os.path.join(MODELS_DIR, filename)
    if os.path.exists(path):
        size_mb = os.path.getsize(path) / 1024 / 1024
        print(f"  [skip] {filename} already present ({size_mb:.1f} MB)")
        return True
    return False


def _download_from_s3() -> bool:
    """Download from S3 using boto3 and AWS env vars or IAM role."""
    bucket = os.environ["AWS_S3_BUCKET"]
    prefix = os.environ.get("AWS_S3_PREFIX", "models").rstrip("/")
    region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")

    try:
        import boto3
    except ImportError:
        print("  boto3 not installed; falling back to URL download")
        return False

    s3 = boto3.client("s3", region_name=region)
    os.makedirs(MODELS_DIR, exist_ok=True)

    for filename in MODEL_FILES:
        if _already_present(filename):
            continue
        optional = filename in OPTIONAL_MODEL_FILES
        key = f"{prefix}/{filename}"
        dest = os.path.join(MODELS_DIR, filename)
        try:
            print(f"  [s3] Downloading s3://{bucket}/{key} ...")
            s3.download_file(bucket, key, dest)
            size_mb = os.path.getsize(dest) / 1024 / 1024
            print(f"  [s3] Done: {filename} ({size_mb:.1f} MB)")
        except s3.exceptions.ClientError as exc:
            code = exc.response["Error"]["Code"]
            if code in ("404", "NoSuchKey"):
                level = "optional" if optional else "required"
                print(f"  [s3] {filename} not found in bucket ({level}), skipping")
            else:
                print(f"  [s3] WARNING: {filename}: {exc}")
        except Exception as exc:
            print(f"  [s3] WARNING: {filename}: {exc}")

    return True


def _download_from_url() -> bool:
    """Download via direct HTTP(S) URL."""
    base_url = os.environ.get("MODEL_BASE_URL", "").rstrip("/")
    if not base_url:
        return False

    os.makedirs(MODELS_DIR, exist_ok=True)

    for filename in MODEL_FILES:
        if _already_present(filename):
            continue
        url = f"{base_url}/{filename}"
        dest = os.path.join(MODELS_DIR, filename)
        print(f"  [url] Downloading {filename} ...")
        try:
            urllib.request.urlretrieve(url, dest)
            size_mb = os.path.getsize(dest) / 1024 / 1024
            print(f"  [url] Done: {filename} ({size_mb:.1f} MB)")
        except Exception as exc:
            print(f"  [url] WARNING: {filename}: {exc}")

    return True


def _print_inventory() -> None:
    print("\nModel inventory:")
    for filename in REQUIRED_MODEL_FILES:
        path = os.path.join(MODELS_DIR, filename)
        if os.path.exists(path):
            size_mb = os.path.getsize(path) / 1024 / 1024
            print(f"  [ok] required {filename} ({size_mb:.1f} MB)")
        else:
            print(f"  [missing] required {filename}")
    for filename in OPTIONAL_MODEL_FILES:
        path = os.path.join(MODELS_DIR, filename)
        if os.path.exists(path):
            size_mb = os.path.getsize(path) / 1024 / 1024
            print(f"  [ok] optional {filename} ({size_mb:.1f} MB)")
        else:
            print(f"  [skip] optional {filename} missing")


def main() -> None:
    print("=" * 50)
    print("AgriLens Model Download Check")
    print(f"Models dir: {MODELS_DIR}")
    print("=" * 50)

    if os.environ.get("AWS_S3_BUCKET"):
        print("[mode] AWS S3")
        _download_from_s3()
    elif os.environ.get("MODEL_BASE_URL"):
        print("[mode] Direct URL")
        _download_from_url()
    else:
        print("[mode] Local volume; no download needed")

    _print_inventory()
    print("=" * 50)


if __name__ == "__main__":
    main()
