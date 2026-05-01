from datetime import datetime, timezone

import pytest
from bson import ObjectId

from app.models import farm_model, forecast_model, notification_model, scan_model, user_model


def test_user_serializer_is_json_safe():
    user = {
        "_id": ObjectId(),
        "phone": "+201001234567",
        "name": "Mona",
        "farms": [ObjectId()],
        "created_at": datetime(2026, 1, 1, tzinfo=timezone.utc),
        "updated_at": datetime(2026, 1, 2, tzinfo=timezone.utc),
    }

    result = user_model.serialize(user)

    assert result["id"] == str(user["_id"])
    assert result["phone"] == "+201001234567"
    assert result["profile_completed"] is False
    assert result["created_at"].startswith("2026-01-01")


def test_farm_serializer_includes_nested_fields():
    field_id = ObjectId()
    farm = {
        "_id": ObjectId(),
        "owner_id": ObjectId(),
        "name": "North Farm",
        "fields": [
            {
                "field_id": field_id,
                "name": "Plot A",
                "area_hectares": 2.5,
                "risk_level": "medium",
            }
        ],
    }

    result = farm_model.serialize(farm)

    assert result["name"] == "North Farm"
    assert result["fields"][0]["field_id"] == str(field_id)
    assert result["fields"][0]["risk_level"] == "medium"


def test_scan_serializer_infers_storage_backend():
    scan = {
        "_id": ObjectId(),
        "user_id": ObjectId(),
        "farm_id": None,
        "field_id": None,
        "media_url": "https://res.cloudinary.com/demo/image/upload/v1/leaf.jpg",
        "status": "completed",
        "detection_result": {"disease": "Early blight"},
    }

    result = scan_model.serialize(scan)

    assert result["storage_backend"] == "cloudinary"
    assert result["image_url"] == scan["media_url"]
    assert result["detection_result"]["disease"] == "Early blight"


def test_scan_update_status_rejects_invalid_status():
    with pytest.raises(ValueError, match="Invalid status"):
        scan_model.update_status(str(ObjectId()), "queued")


def test_notification_and_forecast_serializers_handle_optional_ids():
    notification = notification_model.serialize(
        {
            "_id": ObjectId(),
            "user_id": ObjectId(),
            "title": "Risk",
            "message": "High humidity",
            "is_read": False,
        }
    )
    snapshot = forecast_model.serialize(
        {
            "_id": ObjectId(),
            "user_id": ObjectId(),
            "farm_id": None,
            "field_id": None,
            "payload": {"risk_level": "high"},
        }
    )

    assert notification["related_scan_id"] is None
    assert notification["is_read"] is False
    assert snapshot["farm_id"] is None
    assert snapshot["payload"]["risk_level"] == "high"
