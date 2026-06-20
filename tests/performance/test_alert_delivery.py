"""
NFR-P2 verification — alert delivery time after a disease detection event.

The script submits a scan known to trigger a disease alert, then polls
the notifications endpoint until the alert appears, measuring the delta.

Run:
    AUTH_TOKEN=<jwt> python tests/performance/test_alert_delivery.py

Expected: alert appears within 5 seconds (NFR-P2 threshold).
"""
import os
import sys
import time

import requests

BASE = os.environ.get('BASE_URL', 'http://localhost:8080')
TOKEN = os.environ.get('AUTH_TOKEN', '')
if not TOKEN:
    print('Set AUTH_TOKEN before running.')
    sys.exit(1)

HEADERS = {'Authorization': f'Bearer {TOKEN}'}
TIMEOUT = 10          # seconds to wait for the alert
POLL_INTERVAL = 0.25  # seconds between polls


def upload_diseased_scan():
    """Upload a scan likely to trigger a disease detection event."""
    # Minimal 1×1 JPEG — replace with an actual diseased-crop image for realism.
    jpeg_bytes = (
        b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00'
        b'\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t'
        b'\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a'
        b'\x1f\x1e\x1d\x1a\x1c\x1c $.\' ",#\x1c\x1c(7),01444\x1f\'9=82<.342\x1e'
        b'\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00'
        b'\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xf5\x0a\xff\xd9'
    )
    resp = requests.post(
        f'{BASE}/api/scans',
        headers=HEADERS,
        files={'image': ('leaf.jpg', jpeg_bytes, 'image/jpeg')},
        data={'crop_type': 'tomato'},
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def get_latest_notification_id():
    resp = requests.get(f'{BASE}/api/notifications?per_page=1', headers=HEADERS, timeout=5)
    resp.raise_for_status()
    notifications = resp.json().get('data', {}).get('notifications', [])
    return notifications[0]['id'] if notifications else None


def measure_alert_delivery():
    print('Step 1 — Snapshot current latest notification ID...')
    baseline_id = get_latest_notification_id()

    print('Step 2 — Uploading diseased scan...')
    t_submit = time.perf_counter()
    scan_resp = upload_diseased_scan()
    print(f'         Scan submitted (HTTP {scan_resp})')

    print(f'Step 3 — Polling for new notification (timeout={TIMEOUT}s)...')
    deadline = time.perf_counter() + TIMEOUT
    while time.perf_counter() < deadline:
        current_id = get_latest_notification_id()
        if current_id and current_id != baseline_id:
            elapsed = time.perf_counter() - t_submit
            print(f'\nNFR-P2 RESULT: alert delivered in {elapsed:.2f} s')
            if elapsed <= 5:
                print('PASS — within 3–5 s threshold')
            else:
                print('FAIL — exceeds 5 s threshold')
            return elapsed
        time.sleep(POLL_INTERVAL)

    print(f'\nNFR-P2 RESULT: no alert detected within {TIMEOUT} s — FAIL or scan was healthy')
    return None


if __name__ == '__main__':
    measure_alert_delivery()
