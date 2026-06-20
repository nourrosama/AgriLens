"""
AgriLens Load Test — NFR-P3, NFR-SC1 verification.
Tests realistic farmer browsing behaviour across 8 endpoint categories.

Run (UI mode — open http://localhost:8089 after starting):
    $env:AGRILENS_TEST_TOKEN = "<jwt>"
    python -m locust -f tests/performance/locustfile.py --host http://localhost:8080

Run (headless, 100 users, 15 min, saves HTML report):
    python -m locust -f tests/performance/locustfile.py --host http://localhost:8080 `
        --users 100 --spawn-rate 10 --run-time 15m `
        --headless --html tests/performance/locust_report.html
"""
import os
from locust import HttpUser, TaskSet, task, between

TOKEN = os.environ.get('AGRILENS_TEST_TOKEN', '')
AUTH  = {'Authorization': f'Bearer {TOKEN}'}

NFR_P3_THRESHOLD = 3.0   # seconds


class FarmerSession(TaskSet):
    """Simulates a farmer navigating the app — tests NFR-P3 and NFR-SC1."""

    def _check(self, r, name):
        """Failure = server error (5xx) OR NFR-P3 threshold exceeded (>3s).
        4xx responses (auth, not found, rate limit) are expected and not counted."""
        if r.status_code >= 500:
            r.failure(f'{name}: server error HTTP {r.status_code}')
        elif r.elapsed.total_seconds() > NFR_P3_THRESHOLD:
            r.failure(f'{name}: NFR-P3 FAIL {r.elapsed.total_seconds():.2f}s > 3s')
        else:
            r.success()

    # ── Core dashboard (highest traffic — weight 6) ──────────────────────────
    @task(6)
    def dashboard(self):
        with self.client.get(
            '/api/dashboard/summary',
            headers=AUTH,
            catch_response=True,
            name='GET /dashboard/summary',
        ) as r:
            self._check(r, 'dashboard')

    # ── Farm management (weight 5) ────────────────────────────────────────────
    @task(5)
    def farms(self):
        with self.client.get(
            '/api/farms',
            headers=AUTH,
            catch_response=True,
            name='GET /farms',
        ) as r:
            self._check(r, 'farms')

    # ── Notifications (weight 4) ──────────────────────────────────────────────
    @task(4)
    def notifications(self):
        with self.client.get(
            '/api/notifications',
            headers=AUTH,
            catch_response=True,
            name='GET /notifications',
        ) as r:
            self._check(r, 'notifications')

    # ── Community feed (weight 3) ─────────────────────────────────────────────
    @task(3)
    def feed(self):
        with self.client.get(
            '/api/feed',
            headers=AUTH,
            catch_response=True,
            name='GET /feed',
        ) as r:
            self._check(r, 'feed')

    # ── Published articles (weight 3) ─────────────────────────────────────────
    @task(3)
    def articles(self):
        with self.client.get(
            '/api/articles',
            headers=AUTH,
            catch_response=True,
            name='GET /articles',
        ) as r:
            self._check(r, 'articles')

    # ── Scan history — premium user, full history (weight 2) ─────────────────
    @task(2)
    def scan_history(self):
        with self.client.get(
            '/api/scans',
            headers=AUTH,
            catch_response=True,
            name='GET /scans (history)',
        ) as r:
            self._check(r, 'scans')

    # ── Communities list (weight 2) ───────────────────────────────────────────
    @task(2)
    def communities(self):
        with self.client.get(
            '/api/communities',
            headers=AUTH,
            catch_response=True,
            name='GET /communities',
        ) as r:
            self._check(r, 'communities')

    # ── Health check (weight 1) ───────────────────────────────────────────────
    @task(1)
    def health(self):
        with self.client.get(
            '/api/health',
            catch_response=True,
            name='GET /health',
        ) as r:
            self._check(r, 'health')


class AgriLensUser(HttpUser):
    tasks = [FarmerSession]
    wait_time = between(1, 3)   # realistic human pacing between tasks
