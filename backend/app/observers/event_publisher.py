"""
RabbitMQ event publisher — Observer pattern.
Publishes events: scan.created, scan.completed, disease.detected, risk.high
"""
import json
import logging
import pika

logger = logging.getLogger(__name__)

_connection = None
_channel = None
EXCHANGE = 'agrilens_events'


def init_publisher(app):
    """Establish RabbitMQ connection and declare the exchange."""
    global _connection, _channel
    url = app.config.get('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
    try:
        params = pika.URLParameters(url)
        _connection = pika.BlockingConnection(params)
        _channel = _connection.channel()
        _channel.exchange_declare(exchange=EXCHANGE, exchange_type='topic', durable=True)
        app.logger.info('✅ RabbitMQ publisher connected')
    except Exception as e:
        app.logger.warning(f'⚠️  RabbitMQ not reachable: {e} — events will be logged only')


def publish(routing_key: str, payload: dict):
    """Publish an event. Falls back to logging if RabbitMQ is down."""
    message = json.dumps(payload, default=str)
    if _channel and _connection and _connection.is_open:
        try:
            _channel.basic_publish(
                exchange=EXCHANGE,
                routing_key=routing_key,
                body=message,
                properties=pika.BasicProperties(
                    delivery_mode=2,  # persistent
                    content_type='application/json',
                ),
            )
            logger.info(f'📤 Published [{routing_key}]')
        except Exception as e:
            logger.warning(f'Publish failed: {e} — logging event instead')
            logger.info(f'[EVENT] {routing_key}: {message}')
    else:
        logger.info(f'[EVENT-LOCAL] {routing_key}: {message}')


# ── Convenience helpers ───────────────────────────────────────

def scan_created(scan_id: str, image_url: str):
    publish('scan.created', {'scan_id': scan_id, 'image_url': image_url})


def scan_completed(scan_id: str, result: dict):
    publish('scan.completed', {'scan_id': scan_id, 'result': result})


def disease_detected(scan_id: str, disease: str, severity: str, user_id: str):
    publish('disease.detected', {
        'scan_id': scan_id,
        'disease': disease,
        'severity': severity,
        'user_id': user_id,
    })


def risk_high(scan_id: str, risk_level: str, user_id: str):
    publish('risk.high', {
        'scan_id': scan_id,
        'risk_level': risk_level,
        'user_id': user_id,
    })
