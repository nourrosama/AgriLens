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
EXCHANGE = 'agrilens_events'


def init_publisher(app):
    """Establish RabbitMQ connection and declare the exchange."""
    global _connection, _channel
    url = app.config.get('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')
    params = pika.URLParameters(url)

    for attempt in range(1, 11):
        try:
            _connection = pika.BlockingConnection(params)
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
    """Publish an event. Falls back to logging if RabbitMQ is down."""
    message = json.dumps(payload, default=str)
    if _channel and _connection and _connection.is_open:
        try:
            _channel.basic_publish(
                exchange=EXCHANGE,
                routing_key=routing_key,
                body=message,
                properties=pika.BasicProperties(
                    delivery_mode=2,
                    content_type='application/json',
                ),
            )
            logger.info('Published [%s]', routing_key)
        except Exception as exc:
            logger.warning('Publish failed: %s; logging event instead', exc)
            logger.info('[EVENT] %s: %s', routing_key, message)
    else:
        logger.info('[EVENT-LOCAL] %s: %s', routing_key, message)


def scan_created(scan_id: str, media_url: str):
    publish('scan.created', {
        'scan_id': scan_id,
        'media_url': media_url,
        'image_url': media_url,
    })


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
