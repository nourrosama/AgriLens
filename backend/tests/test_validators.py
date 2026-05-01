from bson import ObjectId

from app.utils.validators import is_valid_object_id, is_valid_phone, sanitize_phone


def test_sanitize_phone_normalizes_local_egyptian_numbers():
    assert sanitize_phone(" 0100-123 4567 ") == "+201001234567"


def test_is_valid_phone_accepts_only_egyptian_e164_numbers():
    assert is_valid_phone("+201001234567")
    assert not is_valid_phone("01001234567")
    assert not is_valid_phone("+14155552671")
    assert not is_valid_phone("+20100123456")


def test_is_valid_object_id_rejects_bad_values():
    assert is_valid_object_id(str(ObjectId()))
    assert not is_valid_object_id("not-a-mongo-id")
    assert not is_valid_object_id(None)
