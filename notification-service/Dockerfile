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
RUN chmod +x /app/start.sh
CMD ["/app/start.sh"]
