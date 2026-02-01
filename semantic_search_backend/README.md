# Paramedic Handover Semantic Suggestions

Minimal, deterministic semantic suggestion backend for a handover-first capture tool.

Disclaimer: Navigation aid only; not clinical decision support.

## Features
- FastAPI `POST /suggest` for a small set of relevant documentation sections via thresholding.
- Embeddings-based similarity with sentence-transformers (optional) or TF-IDF fallback.
- Deterministic rules to force/boost critical categories with transparent reasons.
- Low-confidence gate to prevent flooding on vague inputs.

## Setup (Windows PowerShell)
Use a virtual environment for Python packages:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Optional: enable sentence-transformers for better semantics:

```powershell
pip install sentence-transformers
```

Force TF-IDF (no model download) even if sentence-transformers is installed:

```powershell
$env:EMBEDDER_MODE = "tfidf"
```

Run the service:

```powershell
uvicorn main:app --host 0.0.0.0 --port 8000
```

## API
`POST /suggest`

Request body:
```json
{
  "text": "SOB, wheeze, sats 88%",
  "delta": 0.12,
  "min_score": null,
  "max_results": 8,
  "min_results": 3,
  "session_id": "optional"
}
```

Response body:
```json
{
  "suggestions": [
    {
      "id": "breathing_assessment",
      "title": "Breathing Assessment",
      "final_score": 1.12,
      "semantic_score": 0.41,
      "rule_boost": 0.71,
      "why": ["rule: shortness of breath trigger", "matched: sob", "forced_by_rule:shortness of breath trigger", "semantic: 0.41"]
    }
  ],
  "meta": {
    "model": "tfidf",
    "strategy_used": "relative",
    "s_max": 1.12,
    "delta": 0.12,
    "min_score": null,
    "max_results": 8,
    "min_results": 3,
    "forced_ids": ["breathing_assessment"],
    "baseline_added_ids": [],
    "low_confidence_mode": false,
    "low_conf_threshold": 0.65,
    "latency_ms": 42,
    "disclaimer": "Navigation aid only; not clinical decision support."
  }
}
```

Example curl (PowerShell):
```powershell
curl.exe -X POST http://localhost:8000/suggest ^
  -H "Content-Type: application/json" ^
  -d "{"text":"Chest pain radiating left arm, sweaty","delta":0.12,"max_results":8,"min_results":3}"
```

`POST /pathways/suggest`

Returns at most one JRCalc pathway when confidence is high enough.

Request body:
```json
{
  "text": "SOB with wheeze, sats 88%, known asthma",
  "min_score": 0.75
}
```

Response body:
```json
{
  "suggestion": {
    "id": "jrc_asthma",
    "title": "Acute Asthma",
    "score": 0.83,
    "why": ["semantic: 0.83", "selected_by_threshold"]
  },
  "meta": {
    "model": "tfidf",
    "threshold_score": 0.75,
    "top_score": 0.83,
    "latency_ms": 12,
    "disclaimer": "Navigation aid only; not clinical decision support."
  }
}
```

## Rules Layer
Rules live in `rules.py`. When triggers are detected, categories are boosted or forced. The `why` field in responses lists which rules matched.

## Categories
Categories are defined in `categories.json` and loaded at startup. Each category has an id, title, description, example phrases, and synonyms/abbreviations.

## Sanity Checks
Run quick sample checks:

```powershell
python sanity_check.py
```

## Notes
- Selection uses a relative threshold (`s_max - delta`) and optional absolute threshold (`min_score`).
- Low-confidence inputs (`s_max` below `LOW_CONF_THRESHOLD`) bypass thresholding and return only forced categories plus baseline IDs.
- Baseline IDs default to `chief_complaint`, `blood_pressure`, and `disposition`.
- If rules force categories, the response can exceed `max_results` to preserve safety-critical inclusions.
