"""
RabbitMQ event publisher for scan and alert events.
Publishes: scan.created, scan.completed, disease.detected, risk.high.
"""
import json
import logging
import time

import pika

logger = logging.getLogger(__name__)

_connection = None
_channel = None
_rabbitmq_url: str | None = None
EXCHANGE = 'agrilens_events'


def _make_params(url: str) -> pika.URLParameters:
    params = pika.URLParameters(url)
    params.heartbeat = 60          # keep-alive ping — prevents Docker NAT from dropping idle connections
    params.blocked_connection_timeout = 30
    return params


def _reconnect() -> bool:
    """Try to re-establish the RabbitMQ connection. Returns True on success."""
    global _connection, _channel
    if not _rabbitmq_url:
        return False
    try:
        _connection = pika.BlockingConnection(_make_params(_rabbitmq_url))
        _channel = _connection.channel()
        _channel.exchange_declare(exchange=EXCHANGE, exchange_type='topic', durable=True)
        logger.info('RabbitMQ publisher reconnected')
        return True
    except Exception as exc:
        logger.warning('RabbitMQ reconnect failed: %s', exc)
        return False


def init_publisher(app):
    """Establish RabbitMQ connection and declare the exchange."""
    global _connection, _channel, _rabbitmq_url
    _rabbitmq_url = app.config.get('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')

    for attempt in range(1, 11):
        try:
            _connection = pika.BlockingConnection(_make_params(_rabbitmq_url))
            _channel = _connection.channel()
            _channel.exchange_declare(exchange=EXCHANGE, exchange_type='topic', durable=True)
            app.logger.info('RabbitMQ publisher connected')
            return
        except Exception as exc:
            app.logger.warning(
                'RabbitMQ publisher not ready (attempt %s/10): %s',
                attempt,
                exc,
            )
            time.sleep(2)

    app.logger.warning('RabbitMQ not reachable after retries; events will be logged only')


def publish(routing_key: str, payload: dict):
    """Publish an event. Reconnects once on failure; falls back to logging if RabbitMQ is down."""
    message = json.dumps(payload, default=str)

    def _do_publish():
        _channel.basic_publish(
            exchange=EXCHANGE,
            routing_key=routing_key,
            body=message,
            properties=pika.BasicProperties(
                delivery_mode=2,
                content_type='application/json',
            ),
        )

    if _channel and _connection and _connection.is_open:
        try:
            _do_publish()
            logger.info('Published [%s]', routing_key)
            return
        except Exception as exc:
            logger.warning('Publish failed: %s; attempting reconnect', exc)

    # Connection was dead — try once to reconnect then republish
    if _reconnect():
        try:
            _do_publish()
            logger.info('Published [%s] after reconnect', routing_key)
            return
        except Exception as exc:
            logger.warning('Publish failed after reconnect: %s', exc)

    logger.info('[EVENT-LOCAL] %s: %s', routing_key, message)


def scan_created(scan_id: str, media_url: str):
    publish('scan.created', {
        'scan_id': scan_id,
        'media_url': media_url,
        'image_url': media_url,
    })


def scan_completed(scan_id: str, result: dict, user_id: str = '', media_type: str = 'image'):
    publish('scan.completed', {
        'scan_id': scan_id,
        'user_id': user_id,
        'media_type': media_type,
        'disease': result.get('disease', ''),
        'is_healthy': result.get('is_healthy', True),
        'severity': result.get('severity', 'none'),
    })


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
