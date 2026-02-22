# 🌿 AgriLens

**AI-Based Early Detection and Forecasting System for Crop Diseases**

AgriLens is an AI-powered system that helps Egyptian farmers detect crop diseases early and predict their spread using deep learning, computer vision, and environmental data.

---

## 🏗️ Architecture

The project follows a **microservices architecture** with **MVC** and **Observer** design patterns.

| Service | Purpose | Tech |
|---|---|---|
| `backend/` | Central API — auth, uploads, farm management, data routing | Flask, MongoDB |
| `detection-service/` | Disease detection (CNN/YOLO/ViT) | Flask, TensorFlow/PyTorch |
| `forecast-service/` | Disease spread forecasting (LSTM/Prophet/ARIMA) | Flask, TensorFlow/PyTorch |
| `notification-service/` | Event-driven alerts (SMS, push notifications) | Flask, RabbitMQ, Twilio, FCM |
| `mobile-app/` | Farmer-facing mobile client | Flutter, Firebase |

### Infrastructure
- **MongoDB** — Central database
- **RabbitMQ** — Message broker (Observer pattern)
- **Redis** — Caching layer
- **Docker** — Containerized deployment

---

## 📂 Project Structure

```
AgriLens/
├── backend/                  # Central API microservice
├── detection-service/        # Disease detection microservice
├── forecast-service/         # Forecasting microservice
├── notification-service/     # Alert microservice
├── mobile-app/               # Flutter mobile app
├── docs/                     # Documentation & diagrams
│   └── Diagrams/
├── Dataset_EDA/              # Exploratory data analysis notebooks
├── docker-compose.yml        # Orchestrate all services
└── .gitignore
```

---

## 🚀 Getting Started

### Prerequisites
- Python 3.11+
- Flutter SDK
- Docker & Docker Compose
- MongoDB (or use Docker)

### Run with Docker
```bash
docker-compose up --build
```

### Run individual services
```bash
# Backend API
cd backend && python -m venv venv && pip install -r requirements.txt
python -m flask run

# Mobile App
cd mobile-app && flutter run
```

---

## 👥 Team

| Member | Role |
|---|---|
| Nour Osama | DSAI — AI model & forecasting |
| Rahma Abdelwahab | DSAI — Mobile app & testing |
| Merna Ahmed | SWD — Architecture, dashboard, mobile |
| Layla Mohammad | DSAI — AI model & integration |

**Supervisor**: Dr. Mohamed Sami Rakha

---

## 📄 License

University project — CSAI 498, Fall 2025
