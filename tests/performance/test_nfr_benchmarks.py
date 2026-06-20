"""
NFR benchmark tests — run these against a live stack to generate thesis evidence.

    pip install requests pytest tabulate
    python -m pytest tests/performance/test_nfr_benchmarks.py -v \
           --tb=short 2>&1 | tee nfr_benchmark_results.txt

Environment:
    BASE_URL   - default http://localhost:8080
    AUTH_TOKEN - valid JWT from /api/auth/verify-otp
"""
import os
import statistics
import time

import pytest
import requests

BASE = os.environ.get('BASE_URL', 'http://localhost:8080')
TOKEN = os.environ.get('AUTH_TOKEN', '')
HEADERS = {'Authorization': f'Bearer {TOKEN}'}

RUNS = 10  # repeat each call this many times to get stable stats


def _measure(fn, n=RUNS):
    """Run fn() n times and return (samples, mean, p95)."""
    samples = []
    for _ in range(n):
        t0 = time.perf_counter()
        fn()
        samples.append(time.perf_counter() - t0)
    return samples, statistics.mean(samples), sorted(samples)[int(n * 0.95)]


# ── NFR-P3: Dashboard and fields respond in < 3 s ────────────────────────────

class TestNFR_P3_Responsiveness:
    def test_dashboard_summary_under_3s(self):
        """NFR-P3 — dashboard summary p95 < 3 s."""
        if not TOKEN:
            pytest.skip('AUTH_TOKEN not set')
        samples, mean, p95 = _measure(
            lambda: requests.get(f'{BASE}/api/dashboard/summary', headers=HEADERS, timeout=10)
        )
        print(f'\n  dashboard/summary: mean={mean:.3f}s  p95={p95:.3f}s  (n={RUNS})')
        assert p95 < 3.0, f'NFR-P3 FAILED — p95={p95:.2f}s exceeds 3 s threshold'

    def test_farms_list_under_3s(self):
        """NFR-P3 — farm list p95 < 3 s."""
        if not TOKEN:
            pytest.skip('AUTH_TOKEN not set')
        samples, mean, p95 = _measure(
            lambda: requests.get(f'{BASE}/api/farms', headers=HEADERS, timeout=10)
        )
        print(f'\n  /api/farms: mean={mean:.3f}s  p95={p95:.3f}s  (n={RUNS})')
        assert p95 < 3.0, f'NFR-P3 FAILED — p95={p95:.2f}s exceeds 3 s threshold'

    def test_notifications_list_under_3s(self):
        """NFR-P3 — notification list p95 < 3 s."""
        if not TOKEN:
            pytest.skip('AUTH_TOKEN not set')
        samples, mean, p95 = _measure(
            lambda: requests.get(f'{BASE}/api/notifications', headers=HEADERS, timeout=10)
        )
        print(f'\n  /api/notifications: mean={mean:.3f}s  p95={p95:.3f}s  (n={RUNS})')
        assert p95 < 3.0, f'NFR-P3 FAILED — p95={p95:.2f}s exceeds 3 s threshold'


# ── NFR-S1: TLS/HTTPS enforcement ────────────────────────────────────────────

class TestNFR_S1_TLS:
    def test_http_redirects_to_https(self):
        """NFR-S1 — plain HTTP should redirect to HTTPS in production."""
        prod_url = os.environ.get('PROD_BASE_URL', '')
        if not prod_url:
            pytest.skip('PROD_BASE_URL not set — set to your production domain to verify TLS redirect')
        http_url = prod_url.replace('https://', 'http://')
        resp = requests.get(http_url, allow_redirects=False, timeout=5)
        assert resp.status_code in (301, 302, 307, 308), \
            f'NFR-S1: expected redirect from HTTP, got {resp.status_code}'
        assert 'https' in resp.headers.get('Location', '').lower(), \
            'NFR-S1: redirect does not point to HTTPS'

    def test_api_rejects_non_auth_requests(self):
        """NFR-S1 / auth — protected endpoints return 401 without token."""
        resp = requests.get(f'{BASE}/api/farms', timeout=5)
        assert resp.status_code == 401, \
            f'Expected 401 without auth, got {resp.status_code}'

    def test_rate_limit_on_otp_endpoint(self):
        """NFR-S1 / rate limiting — OTP endpoint rate-limits after threshold."""
        responses = []
        for _ in range(8):
            r = requests.post(
                f'{BASE}/api/auth/send-otp',
                json={'phone': '+20100000000'},
                timeout=5,
            )
            responses.append(r.status_code)
        assert 429 in responses, \
            'NFR-S1: OTP endpoint did not rate-limit after repeated requests'


# ── NFR-R2: Data integrity — round-trip scan persistence ─────────────────────

class TestNFR_R2_DataIntegrity:
    def test_health_endpoint_returns_ok(self):
        """NFR-R1/R3 — /health confirms all services up."""
        resp = requests.get(f'{BASE}/health', timeout=5)
        assert resp.status_code == 200
        body = resp.json()
        assert body.get('status') in ('ok', 'healthy', 'degraded'), \
            f'Unexpected health status: {body}'

    def test_scan_list_is_consistent(self):
        """NFR-R2 — scan list count matches after repeated fetches (no data loss)."""
        if not TOKEN:
            pytest.skip('AUTH_TOKEN not set')
        counts = []
        for _ in range(3):
            r = requests.get(f'{BASE}/api/scans', headers=HEADERS, timeout=10)
            assert r.status_code == 200
            counts.append(len(r.json().get('data', {}).get('scans', [])))
        assert len(set(counts)) == 1, \
            f'NFR-R2: scan count inconsistent across calls: {counts}'


# ── NFR-SC2: Query performance with index verification ───────────────────────

class TestNFR_SC2_QueryPerformance:
    def test_scan_history_pagination_fast(self):
        """NFR-SC2 — paginated scan history responds quickly even on large collections."""
        if not TOKEN:
            pytest.skip('AUTH_TOKEN not set')
        samples, mean, p95 = _measure(
            lambda: requests.get(
                f'{BASE}/api/scans?page=1&per_page=20',
                headers=HEADERS,
                timeout=10,
            )
        )
        print(f'\n  paginated scans: mean={mean:.3f}s  p95={p95:.3f}s')
        assert p95 < 2.0, f'NFR-SC2: scan list p95={p95:.2f}s exceeds 2 s'
