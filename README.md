# 🌿 AgriLens

**AI-Based Early Detection System for Crop Diseases**

AgriLens is an AI-powered system that helps Egyptian farmers detect crop diseases early using deep learning, computer vision, and farm data.

---

## 🏗️ Architecture

The project follows a **microservices architecture** with **MVC** and **Observer** design patterns.

| Service | Purpose | Tech |
|---|---|---|
| `backend/` | Central API — auth, uploads, farm management, data routing | Flask, MongoDB |
| `detection-service/` | Disease detection (CNN/YOLO/ViT) | Flask, TensorFlow/PyTorch |
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
├── notification-service/     # Alert microservice
├── mobile-app/               # Flutter mobile app
├── docs/                     # Documentation & diagrams
│   └── Diagrams/
├── Dataset_EDA/              # Exploratory data analysis notebooks
├── docker-compose.yml        # Orchestrate all services
└── .gitignore
```

---

## 🤖 ML Model Weights

Model weights are **not included in the repository** due to file size. In staging, the detection service downloads required model files from S3 into `/models` at container startup when `AWS_S3_BUCKET` is configured.

| Model | Crop | Destination | Download |
|---|---|---|---|
| `model.h5` | Paddy (Rice) | `detection-service/ml_models/paddy/` | [Download](https://drive.google.com/file/d/1aMWF_ahDYmmSpsZ60HmuUEW1DjDNONgv/view?usp=drive_link) |
| `tomato_model.h5` | Tomato | `detection-service/ml_models/tomato/` | [Download](https://drive.google.com/file/d/15-69tbpibTl4QElsYuFDG6vWSccRkoh2/view?usp=drive_link) |


### Model Details

| Model | Architecture | Classes | Input Size |
|---|---|---|---|
| Paddy | EfficientNet-B3 / ResNet50 / ViT-Base | 10 rice diseases | 384×384 |
| Tomato | EfficientNet-B3 / ResNet50 / ViT-Base | 10 tomato diseases | 384×384 |

### After downloading, your structure should look like:
```
detection-service/
└── ml_models/
    ├── paddy/
    │   ├── model.h5                ← downloaded from Drive
    │   └── label_mapping.json      ← included in repo
    └── tomato/
        ├── tomato_model.h5         ← downloaded from Drive
        └── tomato_label_mapping.json  ← included in repo
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

#### 1. Backend API
```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate
# Mac/Linux
source venv/bin/activate

pip install -r requirements.txt
python -m flask run
```

#### 2. Detection Service
```bash
cd detection-service
python -m venv venv

# Windows
venv\Scripts\activate
# Mac/Linux
source venv/bin/activate

pip install -r requirements.txt

# ⚠️ Download model weights from the links in the ML Model Weights section
# and place them in ml_models/paddy/ and ml_models/tomato/ before running

python run.py
```

The detection service will start on **http://localhost:5001**

Test it with:
```bash
curl -X POST http://127.0.0.1:5001/api/detect \
  -F "image=@your_image.jpg" \
  -F "crop_type=paddy"
```

#### 3. Mobile App
```bash
cd mobile-app
flutter run
```

---

## 👥 Team

| Member | Role |
|---|---|
| Nour Osama | DSAI — AI models |
| Rahma Abdelwahab | DSAI — Mobile app & testing |
| Merna Ahmed | SWD — Architecture, dashboard, mobile |
| Layla Mohammad | DSAI — AI model & integration |

**Supervisor**: Dr. Mohamed Sami Rakha

---

## 📄 License

University project — CSAI 498, Fall 2025
