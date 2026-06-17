"""
RabbitMQ event consumer for alert delivery.
Listens for disease.detected and risk.high events and dispatches push alerts.
"""
import json
import logging
import queue
import threading
import time

import pika

logger = logging.getLogger(__name__)

EXCHANGE = 'agrilens_events'
QUEUE = 'notification_queue'
BINDING_KEYS = ['disease.detected', 'risk.high', 'scan.completed']

# Bounded queue so a burst of events doesn't exhaust memory.
_work_queue: queue.Queue = queue.Queue(maxsize=200)


def start_consumer(app):
    """Start the RabbitMQ consumer and a separate dispatch worker thread.

    Two threads are used deliberately:
    - Consumer thread: owns the pika BlockingConnection and does nothing but
      ACK messages and enqueue them.  It never blocks on network I/O other
      than the AMQP protocol itself, so RabbitMQ heartbeats are always handled.
    - Dispatch worker thread: calls Firebase / Twilio.  External HTTP latency
      cannot starve the pika event loop and trigger missed-heartbeat disconnects.
    """
    url = app.config.get('RABBITMQ_URL', 'amqp://guest:guest@localhost:5672/')

    def _make_params():
        params = pika.URLParameters(url)
        params.heartbeat = 600
        # Consumers only read — memory pressure (Connection.Blocked) doesn't
        # affect them.  Setting this to None disables the timeout so a temporary
        # RabbitMQ memory alarm no longer kills the consumer connection.
        params.blocked_connection_timeout = None
        return params

    def _consume():
        while True:
            try:
                connection = pika.BlockingConnection(_make_params())
                channel = connection.channel()

                channel.exchange_declare(exchange=EXCHANGE, exchange_type='topic', durable=True)
                channel.queue_declare(queue=QUEUE, durable=True)

                for key in BINDING_KEYS:
                    channel.queue_bind(exchange=EXCHANGE, queue=QUEUE, routing_key=key)

                channel.basic_qos(prefetch_count=1)
                channel.basic_consume(queue=QUEUE, on_message_callback=_on_message)

                logger.info('Notification consumer started')
                channel.start_consuming()          # blocks until connection drops
                logger.warning('Consumer disconnected — reconnecting...')

            except Exception as exc:
                logger.warning(
                    'Consumer connection error: %s(%s) — retrying in 5s',
                    type(exc).__name__, exc,
                )

            time.sleep(5)

    def _dispatch_worker():
        """Processes enqueued events without ever blocking the pika thread."""
        while True:
            try:
                routing_key, event = _work_queue.get(timeout=5)
                try:
                    _dispatch(routing_key, event)
                except Exception as exc:
                    logger.error('Dispatch error for [%s]: %s', routing_key, exc)
            except queue.Empty:
                continue

    threading.Thread(target=_consume, daemon=True, name='rmq-consumer').start()
    threading.Thread(target=_dispatch_worker, daemon=True, name='dispatch-worker').start()


def _on_message(ch, method, properties, body):
    """ACK immediately so pika is never held up by Firebase / Twilio calls."""
    try:
        event = json.loads(body)
        routing_key = method.routing_key
        logger.info('Received [%s]: %s', routing_key, event)
        ch.basic_ack(delivery_tag=method.delivery_tag)
        try:
            _work_queue.put_nowait((routing_key, event))
        except queue.Full:
            logger.error('Dispatch queue full — dropping [%s] event for scan=%s',
                         routing_key, event.get('scan_id', '?'))
    except Exception as exc:
        logger.error('Error parsing message: %s', exc)
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)


_SEVERITY_AR = {'low': 'منخفضة', 'medium': 'متوسطة', 'high': 'عالية', 'critical': 'حرجة'}


def _dispatch(routing_key: str, event: dict):
    """Route events to notification channels."""
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
        logger.info(
            'Scan %s completed (media_type=%s); push dispatched=%s',
            scan_id, media_type, bool(user_id and media_type == 'video'),
        )
