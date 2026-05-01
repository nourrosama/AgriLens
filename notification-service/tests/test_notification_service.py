from flask import Flask

from app.controllers.health_controller import health_bp
from app.controllers import health_controller
from app.observers import event_consumer
from app.services import runtime


class FakeMethod:
    def __init__(self, routing_key="disease.detected"):
        self.routing_key = routing_key
        self.delivery_tag = "tag-1"


class FakeChannel:
    def __init__(self):
        self.acked = []
        self.nacked = []

    def basic_ack(self, delivery_tag):
        self.acked.append(delivery_tag)

    def basic_nack(self, delivery_tag, requeue=False):
        self.nacked.append((delivery_tag, requeue))


def test_health_endpoint_reports_degraded_when_integrations_are_missing(monkeypatch):
    monkeypatch.setattr(
        health_controller,
        "get_status",
        lambda: {"mongo_ready": False, "twilio_ready": False, "firebase_ready": False},
    )
    app = Flask(__name__)
    app.register_blueprint(health_bp)

    response = app.test_client().get("/api/health")

    assert response.status_code == 200
    assert response.get_json()["status"] == "degraded"


def test_runtime_noops_when_external_clients_are_not_ready(monkeypatch):
    monkeypatch.setattr(runtime, "_db", None)
    monkeypatch.setattr(runtime, "_twilio_client", None)
    monkeypatch.setattr(runtime, "_firebase_ready", False)

    assert runtime.get_user("bad-id") is None
    assert runtime.send_sms("+201001234567", "body") is None
    assert runtime.send_push(["token"], "Title", "Body") == 0


def test_dispatch_sends_push_for_disease_and_high_risk(monkeypatch):
    from app.channels import push_channel

    sent = []
    monkeypatch.setattr(push_channel, "send", lambda *args: sent.append(args))

    event_consumer._dispatch(
        "disease.detected",
        {"user_id": "user-1", "scan_id": "scan-1", "disease": "Blight", "severity": "high"},
    )
    event_consumer._dispatch(
        "risk.high",
        {"user_id": "user-1", "scan_id": "scan-1", "risk_level": "critical"},
    )

    assert sent[0][1] == "Disease Alert"
    assert "Blight" in sent[0][2]
    assert sent[1][1] == "High Risk Alert"
    assert "critical" in sent[1][2]


def test_on_message_acks_valid_json_and_nacks_invalid_json(monkeypatch):
    monkeypatch.setattr(event_consumer, "_dispatch", lambda routing_key, event: None)
    valid_channel = FakeChannel()
    invalid_channel = FakeChannel()

    event_consumer._on_message(
        valid_channel,
        FakeMethod("scan.completed"),
        None,
        b'{"scan_id": "scan-1"}',
    )
    event_consumer._on_message(
        invalid_channel,
        FakeMethod("scan.completed"),
        None,
        b"{not-json",
    )

    assert valid_channel.acked == ["tag-1"]
    assert invalid_channel.nacked == [("tag-1", False)]
