"""
Input validation helpers.
"""
import re
from bson import ObjectId
from bson.errors import InvalidId


# E.164 phone format — must start with +20 (Egypt)
_PHONE_RE = re.compile(r'^\+20\d{10}$')


def is_valid_phone(phone: str) -> bool:
    """Validate Egyptian E.164 phone number (+20XXXXXXXXXX)."""
    return bool(_PHONE_RE.match(phone))


def is_valid_object_id(value: str) -> bool:
    """Check if string is a valid MongoDB ObjectId."""
    try:
        ObjectId(value)
        return True
    except (InvalidId, TypeError):
        return False


def sanitize_phone(phone: str) -> str:
    """Normalize phone: strip spaces, ensure +20 prefix."""
    phone = phone.strip().replace(' ', '').replace('-', '')
    if phone.startswith('0') and len(phone) == 11:
        phone = '+20' + phone[1:]
    return phone
