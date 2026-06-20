"""
Data anonymization utilities.

Used when user data must be shared for analytics, research, or logging
without exposing personally identifiable information (PII).
"""
import hashlib
import re


def _hash(value: str) -> str:
    """One-way SHA-256 hash so two records with the same value can be
    correlated without revealing the original."""
    return hashlib.sha256(value.encode()).hexdigest()[:16]


def anonymize_user(user: dict) -> dict:
    """Return a PII-free representation of a user document.

    Strips name, phone, email, and photo. Retains only attributes
    needed for aggregate analysis (role, plan, country, timestamps).
    A stable pseudonym is derived from the user id so records from
    the same user can still be grouped across datasets.
    """
    uid = str(user.get('_id', ''))
    return {
        'pseudonym': _hash(uid),
        'role': user.get('role', 'farmer'),
        'plan': user.get('plan', 'free'),
        'country': user.get('country', ''),
        'language': user.get('language', 'en'),
        'farm_count': len(user.get('farms', [])),
        'consent_given_at': (
            user['consent_given_at'].isoformat()
            if user.get('consent_given_at') and hasattr(user['consent_given_at'], 'isoformat')
            else user.get('consent_given_at')
        ),
        'created_at': (
            user['created_at'].isoformat()
            if user.get('created_at') and hasattr(user['created_at'], 'isoformat')
            else user.get('created_at')
        ),
    }


def anonymize_scan(scan: dict) -> dict:
    """Return a PII-free representation of a scan document.

    Replaces user_id with a pseudonym; drops image data and file paths.
    """
    uid = str(scan.get('user_id', ''))
    return {
        'pseudonym': _hash(uid),
        'crop_type': scan.get('crop_type', ''),
        'disease_name': scan.get('disease_name', ''),
        'confidence': scan.get('confidence'),
        'severity': scan.get('severity', ''),
        'is_healthy': scan.get('is_healthy', False),
        'media_type': scan.get('media_type', 'image'),
        'created_at': (
            scan['created_at'].isoformat()
            if scan.get('created_at') and hasattr(scan['created_at'], 'isoformat')
            else scan.get('created_at')
        ),
    }


def mask_phone(phone: str) -> str:
    """Replace middle digits of a phone number for display in logs.
    Example: +201234567890 → +20****7890
    """
    if not phone or len(phone) < 6:
        return '****'
    return phone[:3] + '*' * (len(phone) - 7) + phone[-4:]


def mask_email(email: str) -> str:
    """Partially mask an email address for display in logs.
    Example: ahmed@example.com → a***@example.com
    """
    if not email or '@' not in email:
        return '****'
    local, domain = email.split('@', 1)
    masked_local = local[0] + '*' * max(len(local) - 1, 3)
    return f'{masked_local}@{domain}'
