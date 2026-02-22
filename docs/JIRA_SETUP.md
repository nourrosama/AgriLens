# AgriLens — Jira Board Setup Guide

## Project Setup

1. Go to [Jira](https://www.atlassian.com/software/jira) → Create a new **Scrum** project
2. **Project name**: AgriLens
3. **Project key**: AG (this gives tickets like AG-1, AG-2, etc.)

---

## Epic Breakdown

Create these **Epics** in Jira (one per major area):

| Epic | Description | Owner |
|---|---|---|
| 🔧 **Project Setup** | Repo structure, CI/CD, Docker | Merna |
| 🔐 **Authentication** | User registration, login, JWT | Merna |
| 🌾 **Farm Management** | Farm/field CRUD, metadata | Merna |
| 📷 **Image & Video Upload** | Capture, upload, storage | Merna + Rahma |
| 🤖 **Disease Detection** | CNN/YOLO model integration | Nour + Layla |
| 📈 **Forecasting** | LSTM/Prophet risk prediction | Nour + Layla |
| 🔔 **Notifications** | SMS/Push alerts, Observer pattern | Merna |
| 📱 **Mobile App** | Flutter screens, offline mode | Merna + Rahma |
| 🧪 **Testing** | Unit, integration, UAT | Layla + Rahma |

---

## Sprint Plan (2-week sprints)

### Sprint 1 — Foundation (Week 15-16)
| Ticket | Type | Summary | Assignee | Story Points |
|---|---|---|---|---|
| AG-1 | Task | Set up project repo structure | Merna | 3 |
| AG-2 | Task | Create Docker Compose config | Merna | 2 |
| AG-3 | Story | User registration API endpoint | Merna | 5 |
| AG-4 | Story | User login API endpoint (JWT) | Merna | 5 |
| AG-5 | Story | Create Farm CRUD endpoints | Merna | 5 |
| AG-6 | Task | Set up Flutter project scaffold | Merna + Rahma | 3 |
| AG-7 | Task | Initial dataset preprocessing pipeline | Nour | 5 |

### Sprint 2 — Core Features (Week 17-18)
| Ticket | Type | Summary | Assignee | Story Points |
|---|---|---|---|---|
| AG-8 | Story | Image upload endpoint (backend) | Merna | 5 |
| AG-9 | Story | Video upload + frame extraction | Merna + Layla | 8 |
| AG-10 | Story | Mobile: Auth screens (login/register) | Merna + Rahma | 5 |
| AG-11 | Story | Mobile: Camera capture screen | Rahma | 5 |
| AG-12 | Task | Train initial CNN model on tomato dataset | Nour + Layla | 8 |
| AG-13 | Task | Integrate detection model into service | Nour + Layla | 5 |

### Sprint 3 — Integration (Week 19-20)
| Ticket | Type | Summary | Assignee | Story Points |
|---|---|---|---|---|
| AG-14 | Story | Mobile: Detection results display | Merna | 5 |
| AG-15 | Story | Mobile: Dashboard with stats | Merna | 8 |
| AG-16 | Story | Notification service (RabbitMQ + FCM) | Merna | 8 |
| AG-17 | Task | Train forecasting model | Nour + Layla | 8 |
| AG-18 | Task | Integrate forecast service | Layla | 5 |
| AG-19 | Story | Mobile: Map view with disease markers | Merna | 5 |

### Sprint 4 — Polish & Testing (Week 21-24)
| Ticket | Type | Summary | Assignee | Story Points |
|---|---|---|---|---|
| AG-20 | Story | Mobile: Offline caching + sync | Merna + Rahma | 8 |
| AG-21 | Story | Arabic/English localization | Merna | 5 |
| AG-22 | Task | Model fine-tuning on Egyptian data | Nour + Layla | 8 |
| AG-23 | Task | System integration tests | Layla + Rahma | 5 |
| AG-24 | Task | Performance & reliability tests | Nour + Rahma | 5 |
| AG-25 | Task | User acceptance testing (UAT) | Layla + Nour | 5 |
| AG-26 | Task | Final report & documentation | Whole Team | 3 |

---

## Workflow Columns

```
To Do → In Progress → Code Review → Testing → Done
```

## Tips

1. **Move ticket to "In Progress"** when you start a feature branch
2. **Move to "Code Review"** when you open a PR
3. **Move to "Testing"** when PR is approved and merged to develop
4. **Move to "Done"** when tested and verified
5. **Always use ticket IDs** in branch names and commit messages
