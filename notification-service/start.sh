#!/bin/sh
# Start the RabbitMQ consumer in the background, then start gunicorn.
# Running them as separate processes means gunicorn worker restarts never
# kill the consumer thread, and the consumer is not subject to gunicorn's
# request-handling timeout.
python -m app.consumer_runner &
exec gunicorn --workers 2 --bind 0.0.0.0:5003 --timeout 120 "app.main:create_app()"
