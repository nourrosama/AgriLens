import pytest

from app.utils import model_loader


def test_crop_normalization_and_support_matrix():
    assert model_loader.normalize_crop(" Tomatoes ") == "tomato"
    assert model_loader.normalize_crop(" grapes ") == "grape"
    assert model_loader.normalize_crop("mush rooms") == "mushrooms"
    assert model_loader.normalize_crop("sweet potato") == "sweetpotato"
    assert model_loader.is_supported_crop("potatoes") is True
    assert model_loader.is_supported_crop("wheat") is True
    assert model_loader.is_supported_crop("mushrooms") is False
    assert model_loader.is_supported_crop("corn") is True
    assert model_loader.is_supported_crop("sugar cane") is True
    assert model_loader.is_supported_crop("cotton") is True
    assert model_loader.is_supported_crop("banana") is False
    assert {"tomato", "apple", "potato", "grape", "wheat", "corn", "sugarcane", "cotton"} <= set(
        model_loader.supported_crops()
    )
    assert "mushroom" not in model_loader.supported_crops()


def test_new_crop_configs_match_expected_label_counts():
    assert model_loader.CROP_CONFIGS["grape"].labels[0] == "Bacterial Rot"
    assert len(model_loader.CROP_CONFIGS["grape"].labels) == 7
    assert model_loader.CROP_CONFIGS["wheat"].labels[6] == "Healthy"
    assert len(model_loader.CROP_CONFIGS["wheat"].labels) == 15
    assert model_loader.CROP_CONFIGS["wheat"].model_name == "torchvision_efficientnet_b3_custom"
    assert model_loader.CROP_CONFIGS["corn"].labels == [
        "Blight",
        "Common_Rust",
        "Gray_Leaf_Spot",
        "Healthy",
    ]
    assert model_loader.CROP_CONFIGS["sugarcane"].labels == [
        "Healthy",
        "Mosaic",
        "RedRot",
        "Rust",
        "Yellow",
    ]
    assert model_loader.CROP_CONFIGS["cotton"].runtime == "keras"
    assert model_loader.CROP_CONFIGS["cotton"].labels[-1] == "healthy"


def test_unsupported_crop_payload_is_structured():
    payload = model_loader.unsupported_crop_payload("mushroom")

    assert payload["error_code"] == "UNSUPPORTED_CROP"
    assert payload["plant_status"] == "unsupported_crop"
    assert payload["selected_crop"] == "mushroom"
    assert "mushroom" not in payload["supported_crops"]


def test_crop_validator_without_not_plant_or_other_labels_is_skipped(monkeypatch):
    monkeypatch.setattr(model_loader, "_validator_state", None)
    monkeypatch.setattr(model_loader, "_validator_error", None)
    monkeypatch.setattr(
        model_loader,
        "_app_config",
        {
            "CROP_VALIDATOR_ENABLED": True,
            "CROP_VALIDATOR_MODEL_PATH": "crop_validator.pt",
        },
    )
    monkeypatch.setattr(model_loader.os.path, "exists", lambda path: True)
    monkeypatch.setattr(
        model_loader,
        "_load_checkpoint",
        lambda path: {
            "class_names": [
                "apple",
                "corn",
                "cotton",
                "grape",
                "potato",
                "sugarcane",
                "tomato",
                "wheat",
            ]
        },
    )

    validation = model_loader.validate_image_bgr(object(), "sugarcane")

    assert validation["plant_status"] == "validator_unavailable"
    assert validation["selected_crop"] == "sugarcane"
    assert "missing a not-plant label" in validation["warning"]


def test_low_confidence_prediction_after_skipped_validator_returns_not_plant(monkeypatch):
    monkeypatch.setattr(
        model_loader,
        "validate_image_bgr",
        lambda image, crop: {
            "valid": True,
            "plant_status": "validator_unavailable",
            "selected_crop": "tomato",
            "detected_crop": "tomato",
            "supported_crops": model_loader.supported_crops(),
        },
    )
    monkeypatch.setattr(
        model_loader,
        "_predict_from_bgr",
        lambda image, crop: {"confidence": 0.12, "_predicted_id": 0},
    )
    monkeypatch.setattr(
        model_loader,
        "_app_config",
        {"MIN_PLANT_CONFIDENCE": 0.4},
    )

    with pytest.raises(model_loader.ValidationFailure) as exc_info:
        model_loader._predict_validated(object(), "tomato", include_gradcam=False)

    assert exc_info.value.payload["error_code"] == "NOT_A_PLANT"
    assert exc_info.value.payload["selected_crop"] == "tomato"


def test_get_model_status_for_unsupported_crop_is_explicit():
    status = model_loader.get_model_status("banana")

    assert status["ready"] is False
    assert "Unsupported crop type" in status["error"]
    assert "tomato" in status["supported_crops"]


def test_predict_from_file_bytes_rejects_non_image_bytes():
    with pytest.raises(ValueError, match="Could not decode image bytes"):
        model_loader.predict_from_file_bytes(b"not an image", "tomato")


def test_keyframe_peak_selection_uses_threshold_distance_and_top_fallback():
    scores = model_loader.np.array([0.1, 0.7, 0.6, 0.2, 0.9, 0.3, 0.8], dtype="float32")

    selected = model_loader._select_keyframe_peaks(
        scores,
        threshold=0.5,
        min_distance=3,
        max_frames=2,
    )

    assert selected == [1, 4]
    assert model_loader._select_keyframe_peaks(scores * 0.1, threshold=0.5, max_frames=2) == [4, 6]
