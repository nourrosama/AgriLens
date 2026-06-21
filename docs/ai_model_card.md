# AgriLens AI Model Card

## Model Overview

| Field | Details |
|-------|---------|
| **Purpose** | Detect and identify crop diseases from field photographs and videos |
| **Primary users** | Egyptian farmers and agricultural researchers |
| **Deployment context** | Mobile application (Android/iOS); results are advisory only |
| **Output** | Disease name, confidence score, severity level, treatment recommendations, Grad-CAM explanation map |
| **Model architecture** | CNN / YOLO / Vision Transformer (ViT) ensemble |
| **Explainability** | Grad-CAM gradient attention maps included in every response |

---

## Supported Crops

The model is trained and validated on Egyptian agricultural crops including (but not limited to):

- Tomato
- Potato
- Wheat
- Maize (Corn)
- Cotton
- Grape

Crops outside this list return an `UNSUPPORTED_CROP` validation error rather than a guess.

---

## Intended Use

- Early detection of visible crop disease symptoms from photos taken in field conditions
- Prioritization of which fields need agronomist attention
- Educational guidance on disease identification and management

### Out-of-Scope Use

- Diagnosing human or animal conditions
- Legal or insurance claim evidence
- Definitive crop certification (requires laboratory confirmation)
- Use on crops outside the supported list

---

## Performance & Limitations

### Confidence Thresholds

| Threshold | Value | Purpose |
|-----------|-------|---------|
| Plant detection minimum | 0.40 | Rejects non-plant images |
| Supported crop minimum | 0.65 | Rejects unrecognized or unsupported crops |
| Disease classification | Top-3 returned with scores | User sees confidence for each prediction |

### Known Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Poor lighting (night, deep shadow) | Lower confidence scores | Model returns low-confidence warning |
| Early-stage symptoms (< 5% leaf area affected) | May classify as healthy | Recommend rescanning after 3–5 days |
| Heavily overlapping diseases | Top prediction may be incorrect | Top-3 predictions shown with confidence |
| Image blur or extreme distance | Reduced accuracy | Validation rejects images below quality threshold |
| Seasonal variation in appearance | Slight accuracy drop in off-season | Model retrained periodically with new data |

---

## Bias & Fairness

### Training Data

- Images sourced from Egyptian field conditions (Nile Delta, Upper Egypt, Delta region)
- Multiple lighting conditions: natural sunlight, overcast, partial shade
- Multiple growth stages: seedling, vegetative, flowering, fruiting

### Known Biases

- Accuracy may be lower for smallholder farms with mixed cropping patterns not represented in training data
- Limited data for rare diseases; these conditions return lower confidence scores
- Model performance has not been independently validated on crops grown in non-Egyptian climates

### Fairness Commitments

- Model is retrained periodically as new annotated data is collected from diverse regions
- Confidence scores and top-3 predictions are always shown to prevent false certainty
- Unsupported crops and non-plant images are explicitly rejected rather than silently misclassified

---

## Data Governance

- Uploaded images are used only for the immediate scan request
- Images are stored associated with the authenticated user's account only
- Users can delete all their data (including scan images) via the account deletion endpoint
- Aggregated, anonymized scan statistics may be used for model improvement

---

## Human Oversight

- Every result includes a **disclaimer**: "AI-generated results. For critical crop decisions, consult a certified agronomist."
- Grad-CAM visual explanation allows users and agronomists to verify which plant region the model focused on
- Confidence scores are always disclosed — the model never presents a result as certain
- Severity levels (none / medium / high) help users gauge urgency and decide whether to seek expert consultation

---

## Responsible AI Alignment

| Principle | Implementation |
|-----------|---------------|
| Transparency | Grad-CAM explanation + confidence scores in every response |
| Accountability | Audit log records every scan with user ID and timestamp |
| Reliability | Confidence thresholds + crop validator prevent hallucinated outputs |
| Fairness | Diverse training data; continuous retraining planned |
| Human agency | Disclaimer on results; agronomist consultation recommended for critical decisions |
| Privacy | Images tied to authenticated user; full data deletion available |

---

## Regulatory Context

AgriLens is classified as a **limited-risk AI system** under the EU AI Act framework (advisory agricultural tool with human oversight). It is not classified as high-risk because:

- Decisions remain with the human farmer/agronomist
- No automated enforcement or penalty systems are connected to outputs
- Confidence scores and disclaimers ensure informed human decision-making

---

## Version & Contact

| Field | Details |
|-------|---------|
| Model version | v1 (local deployment) |
| Last updated | June 2026 |
| Project | CSAI 498 — Zewail City of Science and Technology |
| Supervisor | Dr. Mohamed Sami Rakha |
| Contact | s-rahma.shaaban@zewailcity.edu.eg |
