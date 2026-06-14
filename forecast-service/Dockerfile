FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5002

ENV FLASK_APP=app.main:create_app

CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:5002", "--timeout", "120", "app.main:create_app()"]
