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

CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:5003", "--timeout", "120", "app.main:create_app()"]
