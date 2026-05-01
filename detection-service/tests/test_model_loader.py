import pytest

from app.utils import model_loader


def test_crop_normalization_and_support_matrix():
    assert model_loader.normalize_crop(" Tomatoes ") == "tomato"
    assert model_loader.normalize_crop("sweet potato") == "sweetpotato"
    assert model_loader.is_supported_crop("potatoes") is True
    assert model_loader.is_supported_crop("banana") is False
    assert {"tomato", "apple", "potato"} <= set(model_loader.supported_crops())


def test_get_model_status_for_unsupported_crop_is_explicit():
    status = model_loader.get_model_status("banana")

    assert status["ready"] is False
    assert "Unsupported crop type" in status["error"]
    assert "tomato" in status["supported_crops"]


def test_predict_from_file_bytes_rejects_non_image_bytes():
    with pytest.raises(ValueError, match="Could not decode image bytes"):
        model_loader.predict_from_file_bytes(b"not an image", "tomato")
