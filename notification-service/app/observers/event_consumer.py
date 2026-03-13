"""
RabbitMQ event consumer — Observer pattern subscriber.
Listens for disease.detected and risk.high events,
dispatches to SMS and Push notification channels.
"""
import json
import logging
import pika
import threading

logger = logging.getLogger(__name__)

EXCHANGE = 'agrilens_events'
QUEUE = 'notification_queue'
BINDING_KEYS = ['disease.detected', 'risk.high', 'scan.completed']


def start_consumer(app):
    """Start the RabbitMQ consumer in a background thread."""
    url = app.config.get('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')

    def _consume():
        try:
            params = pika.URLParameters(url)
            connection = pika.BlockingConnection(params)
            channel = connection.channel()

            channel.exchange_declare(exchange=EXCHANGE, exchange_type='topic', durable=True)
            channel.queue_declare(queue=QUEUE, durable=True)

            for key in BINDING_KEYS:
                channel.queue_bind(exchange=EXCHANGE, queue=QUEUE, routing_key=key)

            def on_message(ch, method, properties, body):
                try:
                    event = json.loads(body)
                    routing_key = method.routing_key
                    logger.info(f'📥 Received [{routing_key}]: {event}')
                    _dispatch(routing_key, event)
                    ch.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    logger.error(f'Error processing message: {e}')
                    ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)

            channel.basic_qos(prefetch_count=1)
            channel.basic_consume(queue=QUEUE, on_message_callback=on_message)
            logger.info('✅ Notification consumer started — listening for events')
            channel.start_consuming()

        except Exception as e:
            logger.error(f'Consumer failed to start: {e}')

    thread = threading.Thread(target=_consume, daemon=True)
    thread.start()


def _dispatch(routing_key: str, event: dict):
    """Route events to notification channels."""
    from app.channels import push_channel, sms_channel

    user_id = event.get('user_id', '')
    scan_id = event.get('scan_id', '')

    if routing_key == 'disease.detected':
        disease = event.get('disease', 'Unknown')
        severity = event.get('severity', 'unknown')
        message = f'⚠️ Disease detected: {disease} (severity: {severity})'
        sms_channel.send(user_id, message)
        push_channel.send(user_id, 'Disease Alert', message)

    elif routing_key == 'risk.high':
        risk = event.get('risk_level', 'high')
        message = f'🚨 High risk alert! Risk level: {risk}. Check your crops immediately.'
        sms_channel.send(user_id, message)
        push_channel.send(user_id, 'High Risk Alert', message)

    elif routing_key == 'scan.completed':
        logger.info(f'Scan {scan_id} completed — result stored')
