"""
Standalone RabbitMQ consumer process.
Run as: python -m app.consumer_runner
Keeps running forever; gunicorn is started separately in start.sh.
"""
import logging
import os
import queue
import threading
import time
import traceback

import pika

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s [consumer] %(message)s',
)
logger = logging.getLogger(__name__)

RABBITMQ_URL = os.environ.get('RABBITMQ_URL', 'amqp://guest:guest@rabbitmq:5672/')
EXCHANGE = 'agrilens_events'
QUEUE_NAME = 'notification_queue'
BINDING_KEYS = ['disease.detected', 'risk.high', 'scan.completed']

_work_queue: queue.Queue = queue.Queue(maxsize=200)

_SEVERITY_AR = {
    'low': 'منخفضة',
    'medium': 'متوسطة',
    'high': 'عالية',
    'critical': 'حرجة',
}


def _make_params():
    params = pika.URLParameters(RABBITMQ_URL)
    params.heartbeat = 600
    params.blocked_connection_timeout = None
    return params


def _on_message(ch, method, properties, body):
    import json
    try:
        event = json.loads(body)
        routing_key = method.routing_key
        logger.info('Received [%s]: %s', routing_key, event)
        ch.basic_ack(delivery_tag=method.delivery_tag)
        try:
            _work_queue.put_nowait((routing_key, event))
        except queue.Full:
            logger.error('Dispatch queue full — dropping [%s] for scan=%s',
                         routing_key, event.get('scan_id', '?'))
    except Exception as exc:
        logger.error('Error parsing message: %s', exc)
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)


def _dispatch(routing_key, event):
    from app.channels import push_channel
    user_id = event.get('user_id', '')
    scan_id = event.get('scan_id', '')

    if routing_key == 'disease.detected':
        disease = event.get('disease', 'Unknown')
        severity = event.get('severity', 'unknown')
        severity_ar = _SEVERITY_AR.get(severity, severity)
        push_channel.send(
            user_id,
            title_en='Disease Alert 🌿',
            body_en=f'{disease} detected (severity: {severity}). Tap to view details.',
            title_ar='تنبيه مرض 🌿',
            body_ar=f'تم اكتشاف مرض: {disease} (شدة: {severity_ar}). اضغط لعرض التفاصيل.',
            scan_id=scan_id,
        )

    elif routing_key == 'risk.high':
        risk = event.get('risk_level', 'high')
        risk_ar = _SEVERITY_AR.get(risk, risk)
        push_channel.send(
            user_id,
            title_en='High Risk Alert ⚠️',
            body_en=f'Forecast risk level is {risk}. Check your crops immediately.',
            title_ar='تحذير خطر عالٍ ⚠️',
            body_ar=f'مستوى خطر التوقعات: {risk_ar}. تحقق من محاصيلك فوراً.',
            scan_id=scan_id,
        )

    elif routing_key == 'scan.completed':
        media_type = event.get('media_type', 'image')
        if user_id and media_type == 'video':
            is_healthy = event.get('is_healthy', True)
            disease = event.get('disease', '')
            severity = event.get('severity', 'none')
            severity_ar = _SEVERITY_AR.get(severity, severity)
            push_channel.send(
                user_id,
                title_en='Scan Complete ✓',
                body_en='Your crop looks healthy! No disease detected.' if is_healthy
                    else f'{disease} detected (severity: {severity}). Tap to view details.',
                title_ar='اكتمل الفحص ✓',
                body_ar='محصولك يبدو بصحة جيدة! لم يُكتشف أي مرض.' if is_healthy
                    else f'تم اكتشاف مرض: {disease} (شدة: {severity_ar}). اضغط لعرض التفاصيل.',
                scan_id=scan_id,
            )
        logger.info('Scan %s completed (media_type=%s)', scan_id, media_type)


def _dispatch_worker():
    while True:
        try:
            routing_key, event = _work_queue.get(timeout=5)
            try:
                _dispatch(routing_key, event)
            except Exception as exc:
                logger.error('Dispatch error [%s]: %s\n%s',
                             routing_key, exc, traceback.format_exc())
        except queue.Empty:
            continue


def _consume():
    while True:
        try:
            connection = pika.BlockingConnection(_make_params())
            channel = connection.channel()
            channel.exchange_declare(exchange=EXCHANGE, exchange_type='topic', durable=True)
            channel.queue_declare(queue=QUEUE_NAME, durable=True)
            for key in BINDING_KEYS:
                channel.queue_bind(exchange=EXCHANGE, queue=QUEUE_NAME, routing_key=key)
            channel.basic_qos(prefetch_count=1)
            channel.basic_consume(queue=QUEUE_NAME, on_message_callback=_on_message)
            logger.info('Notification consumer started — waiting for events')
            channel.start_consuming()
            logger.warning('Consumer disconnected — reconnecting...')
        except Exception as exc:
            logger.warning('Consumer connection error: %s(%s) — retrying in 5s',
                           type(exc).__name__, exc)
        time.sleep(5)


if __name__ == '__main__':
    # Initialise runtime (MongoDB + Firebase) before starting the consumer.
    # We build a minimal Flask app context so runtime.init_runtime() can use
    # app.config and app.logger exactly the same way as the HTTP workers do.
    from app.main import create_app as _create_app
    _app = _create_app()

    threading.Thread(target=_dispatch_worker, daemon=True, name='dispatch-worker').start()
    logger.info('Dispatch worker started')
    _consume()  # blocks forever in the main thread
