FROM python:3.11-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5003

ENV FLASK_APP=app.main:create_app

# start.sh runs the consumer as a standalone process, then starts gunicorn.
# Keeping them separate means gunicorn worker restarts never kill the consumer.
CMD ["sh", "-c", "python -m app.consumer_runner & exec gunicorn --workers 2 --bind 0.0.0.0:5003 --timeout 120 'app.main:create_app()'"]
