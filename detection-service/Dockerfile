FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5001

ENV FLASK_APP=app.main:create_app

CMD ["sh", "-c", "python download_models.py && gunicorn --workers 2 --bind 0.0.0.0:5001 --timeout 120 'app.main:create_app()'"]
