from __future__ import annotations

import json
import re
from pathlib import Path

"""
Generate categories.json from Merged_Clinical_Attributes.json.

Goal: make semantic search robust for real-world paramedic free-text (jargon, abbreviations,
and short under-pressure phrases), not "fieldName: Value" training text.
"""


BASE_DIR = Path(__file__).resolve().parent
MERGED_PATH = BASE_DIR / "Merged_Clinical_Attributes.json"
OUTPUT_PATH = BASE_DIR / "categories.json"

# Baseline attributes from SYSTEM_DOCUMENTATION.md which are always suggested elsewhere
# and should not dilute semantic search suggestions.
BASELINE_PATHS: set[str] = {
    "Patient Details.familyName",
    "Patient Details.givenName",
    "Patient Details.dateOfBirth",
    "Patient Demographics.age",
    "Patient Details.sex",
    "Patient Details.NHSNumber",
    "Known Allergy.type",
    "Current Medication.name",
    "Chief Complaint.presentingComplaint",
    "Chief Complaint.pastMedicalHistory",
    "Incident.incidentTime",
    "Incident.incidentDate",
}

PLACEHOLDER_VALUES = {"INSERT LOCAL LIST HERE", ""}

STOP_WORDS = {
    "and",
    "of",
    "the",
    "a",
    "an",
    "to",
    "for",
    "in",
    "on",
    "with",
    "at",
    "by",
    "from",
}

GENERIC_FIELD_TITLES = {
    "type",
    "status",
    "value",
    "outcome",
    "method",
    "site",
    "side",
    "location",
    "reason",
    "time",
    "date",
    "name",
    "dose",
    "dosage",
    "route",
    "size",
    "score",
    "result",
    "level",
    "severity",
    "grade",
    "cause",
    "rhythm",
    "attempts",
    "comments",
    "comment",
}


def _ascii(text: str) -> str:
    return text.encode("ascii", "ignore").decode("ascii") if text else ""


def _norm_spaces(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _norm_term(text: str) -> str:
    # Lowercase and strip punctuation so synonyms match TF-IDF tokens too.
    text = _ascii(text)
    text = text.replace("_", " ").replace(".", " ").replace(":", " ").replace("/", " ")
    text = re.sub(r"[^a-zA-Z0-9\s]", " ", text)
    return _norm_spaces(text).lower()


def _sentence_case(text: str) -> str:
    if not text:
        return text
    return text[0].upper() + text[1:]


def _humanize(field: str) -> str:
    if not field:
        return field
    if " " in field:
        return field.strip()
    s = field.replace("_", " ")
    s = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", s)
    s = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", s)
    s = _norm_spaces(s)
    if not s:
        return field
    return s[0].upper() + s[1:]


def _dedupe_preserve(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        if item and item not in seen:
            out.append(item)
            seen.add(item)
    return out


ABBREVIATIONS: dict[str, list[str]] = {
    # Airway/breathing
    "shortness of breath": ["sob", "dyspnea", "dyspnoea", "cant breathe", "cannot breathe"],
    "breathing": ["sob", "wheeze", "work of breathing", "wob", "tachypnea", "tachypnoea"],
    "respiratory": ["sob", "rr", "resp rate", "tachypnea", "wheeze"],
    "respiratory rate": ["rr", "resp rate", "breathing rate"],
    "pulse oximetry": ["spo2", "sats", "o2 sats", "oxygen sats"],
    "oxygen saturation": ["spo2", "sats", "o2 sats"],
    "oxygen": ["o2"],
    # Circulation
    "blood pressure": ["bp"],
    "systolic": ["sbp", "systolic bp"],
    "diastolic": ["dbp", "diastolic bp"],
    "capillary refill": ["crt"],
    "intravenous": ["iv"],
    "intraosseous": ["io"],
    "cannula": ["iv"],
    # Neuro
    "glasgow coma scale": ["gcs"],
    "avpu": ["avpu"],
    # Cardiac
    "electrocardiogram": ["ecg", "ekg", "12 lead"],
    "ecg": ["ecg", "ekg", "12 lead"],
    "cardiac arrest": ["arrest", "cpr", "rosc"],
    "cardiopulmonary resuscitation": ["cpr", "rosc"],
    "defibrillation": ["defib"],
    # Diabetes
    "blood glucose": ["bgl", "bm", "blood sugar"],
    "glucose": ["bgl", "bm", "blood sugar"],
}


CATEGORY_OVERRIDES: dict[str, str] = {
    "avpu assessment": "avpu",
    "airway adjunct": "airway adjunct",
    "airway assessment": "airway",
    "breathing assessment": "breathing",
    "blood pressure": "bp",
    "blood glucose": "blood sugar",
    "pulse oximetry": "spo2",
    "glasgow coma scale": "gcs",
    "ecg interpretation": "ecg",
    "body temperature": "temp",
    "cardiopulmonary resuscitation": "cpr",
    "defibrillation": "defib",
    "oxygen administration": "oxygen",
    "respiratory support": "resp support",
}


def _short_category(category_name: str) -> str:
    normalized = _norm_term(category_name)
    if normalized in CATEGORY_OVERRIDES:
        return CATEGORY_OVERRIDES[normalized]

    words = [w for w in normalized.split() if w not in STOP_WORDS]
    if not words:
        return normalized
    joined = " ".join(words)

    # Prefer keeping strongly discriminative heads.
    for key in (
        "airway",
        "breathing",
        "respiratory",
        "spo2",
        "sats",
        "oxygen",
        "bp",
        "blood pressure",
        "blood sugar",
        "glucose",
        "ecg",
        "cardiac",
        "cpr",
        "defib",
        "gcs",
        "avpu",
        "sepsis",
        "stroke",
        "trauma",
        "burn",
        "allergy",
    ):
        if key in joined:
            return key

    if len(words) <= 3:
        return " ".join(words)
    return " ".join(words[:3])


def _clean_value(value: str) -> str:
    value = _ascii(value)
    value = value.replace("%", " percent")
    value = value.replace(">", " greater than ")
    value = value.replace("<", " less than ")
    return _norm_spaces(value)


def _special_examples(combined: str) -> list[str]:
    # These are high-impact for matching common narrative/jargon.
    if "avpu" in combined:
        return ["Pt alert on avpu", "Avpu voice", "Avpu pain", "Avpu unresponsive"]
    if "glasgow coma scale" in combined or "gcs" in combined:
        if "eye" in combined:
            return ["Gcs eyes 4", "Gcs eyes 3"]
        if "verbal" in combined:
            return ["Gcs verbal 5", "Gcs verbal 4"]
        if "motor" in combined:
            return ["Gcs motor 6", "Gcs motor 5"]
        if "total" in combined:
            return ["Gcs 15", "Gcs 13", "Pt gcs 12"]
        return ["Gcs 15", "Gcs 13", "Pt gcs 12"]
    if "blood pressure" in combined:
        if "systolic" in combined:
            return ["Sbp 90", "Systolic bp 100", "Hypotensive"]
        if "diastolic" in combined:
            return ["Dbp 60", "Diastolic bp 70"]
        return ["Bp 120/80", "Bp 90/60", "Low bp"]
    if "chest pain onset" in combined:
        if "time" in combined:
            return ["Chest pain started 14:30", "Cp started 2 hours ago", "Chest pain began 30 min ago"]
        if "date" in combined:
            return ["Chest pain started today", "Chest pain onset yesterday"]
    if "blood glucose" in combined or "glucose" in combined:
        return ["Bgl 4.1", "Blood sugar 3.2", "Bm 6.0", "Hypo bgl 2.9"]
    if "pulse oximetry" in combined or "oxygen saturation" in combined or "spo2" in combined:
        return ["Sats 88% ra", "Spo2 94% on o2", "O2 sats 92%"]
    if "oxygen administration" in combined and ("flow rate" in combined or "l/min" in combined or "lpm" in combined):
        return ["O2 2 lpm nc", "O2 15 lpm nrb", "Oxygen at 10 lpm"]
    if "respiratory rate" in combined:
        return ["Rr 28", "Resp rate 18", "Tachypneic rr 30"]
    if "temperature" in combined:
        return ["Temp 38.5", "Febrile", "Temp 36.8"]
    if "ecg" in combined or "electrocardiogram" in combined:
        return ["12 lead ecg done", "Ecg sinus rhythm", "Ecg st elevation", "Ekg done for cp"]
    if "airway" in combined and ("status" in combined or "obstruct" in combined):
        return ["Airway patent", "Airway obstructed", "Snoring airway", "Gurgling airway"]
    if "breathing" in combined:
        return ["SOB", "Wheeze", "Increased wob", "Labored breathing"]
    if "pain" in combined and "score" in combined:
        return ["Pain 8/10", "Pain score 4/10"]
    if "cpr" in combined or "cardiopulmonary resuscitation" in combined:
        return ["Cpr started", "Cpr ongoing", "Rosc achieved"]
    if "defib" in combined or "defibrillation" in combined:
        return ["Defib x1", "Defib 200j"]
    return []


DEVICE_VALUE_MAP: dict[str, list[str]] = {
    "Oropharangeal (OP) Airway": ["opa inserted", "opa in situ"],
    "Nasopharyngeal (NP) Airway": ["npa inserted", "npa in situ"],
    "Nasal cannula": ["2l nc", "nasal cannula"],
    "Non-rebreather": ["15l nrb", "non rebreather mask"],
    "Endotracheal Intubation": ["intubated", "ett placed"],
    "Laryngeal Mask": ["lma placed"],
}


def _examples_from_values(values: list[str], subject: str) -> list[str]:
    examples: list[str] = []
    for raw in values:
        if raw in PLACEHOLDER_VALUES:
            continue
        v = _clean_value(raw)
        if not v:
            continue
        if raw in DEVICE_VALUE_MAP:
            examples.extend(DEVICE_VALUE_MAP[raw])
            continue
        v_norm = _norm_term(v)
        subj_norm = _norm_term(subject)

        # Keep the phrase short and closer to typical narrative.
        if v_norm == "no":
            examples.append(f"no {subj_norm}")
        elif v_norm.startswith("yes"):
            tail = _norm_spaces(v.replace("Yes", "").replace("yes", "")).strip()
            if tail:
                examples.append(_norm_spaces(f"{subj_norm} {tail}"))
            else:
                examples.append(f"{subj_norm} yes")
        else:
            examples.append(_norm_spaces(f"{subj_norm} {v}"))
    return examples


def _pick_subject(category_name: str, field_title: str) -> str:
    ft = _norm_term(field_title)
    if ft in GENERIC_FIELD_TITLES:
        return _short_category(category_name)
    # Prefer the specific concept for more discriminative matching.
    return ft or _short_category(category_name)


def _build_examples(category_name: str, field_name: str, field_title: str, field_info: dict) -> list[str]:
    combined = _norm_term(f"{category_name} {field_title} {field_name} {field_info.get('description','')}")
    special = _special_examples(combined)
    if special:
        return _dedupe_preserve([_sentence_case(_ascii(s)) for s in special])[:5]

    values = list(field_info.get("values") or [])
    values = [v for v in values if v not in PLACEHOLDER_VALUES]

    subject = _pick_subject(category_name, field_title)
    if values:
        examples = _examples_from_values(values[:3], subject)
        if len(examples) < 3:
            examples.append(f"Recorded {subject}")
        return _dedupe_preserve([_sentence_case(_ascii(_norm_spaces(e))) for e in examples])[:5]

    ftype = (field_info.get("type") or "").strip().lower()
    if ftype == "numeric":
        return _dedupe_preserve(
            [
                _sentence_case(f"{subject} 98"),
                _sentence_case(f"Measured {subject}"),
                _sentence_case(f"Recorded {subject}"),
            ]
        )[:5]
    if ftype == "boolean":
        return _dedupe_preserve(
            [
                _sentence_case(f"{subject} present"),
                _sentence_case(f"No {subject}"),
                _sentence_case(f"{subject} confirmed"),
            ]
        )[:5]
    if ftype == "time":
        return _dedupe_preserve(
            [
                _sentence_case(f"{subject} 14:30"),
                _sentence_case(f"Time noted for {subject}"),
            ]
        )[:5]
    if ftype == "date":
        return _dedupe_preserve(
            [
                _sentence_case(f"{subject} 2026-02-01"),
                _sentence_case(f"Date noted for {subject}"),
            ]
        )[:5]

    return _dedupe_preserve(
        [
            _sentence_case(f"Recorded {subject}"),
            _sentence_case(f"Documented {subject}"),
        ]
    )[:5]


def _build_synonyms(category_name: str, field_title: str, field_name: str, description: str) -> list[str]:
    base: list[str] = []

    def add(term: str) -> None:
        t = _norm_term(term)
        if t:
            base.append(t)

    combined = _norm_term(f"{category_name} {field_title} {field_name} {description}")

    # Always include category anchor(s) and field title for discoverability.
    add(_short_category(category_name))
    add(category_name)
    add(field_title)

    # Expand common medical abbreviations/jargon when the attribute context suggests it.
    for key, vals in ABBREVIATIONS.items():
        if key in combined:
            for val in vals:
                add(val)

    # A few high-value generic abbreviations (only when likely).
    if "shortness of breath" in combined or "dysp" in combined or "breathing" in combined:
        add("sob")
        add("wheeze")
        add("increased wob")
    if "oxygen saturation" in combined or "pulse oximetry" in combined:
        add("sats")
        add("spo2")
    if "blood pressure" in combined:
        add("bp")
    if "blood glucose" in combined or "glucose" in combined:
        add("bgl")
        add("bm")
        add("blood sugar")
    if "electrocardiogram" in combined or "ecg" in combined:
        add("ecg")
        add("12 lead")
        add("ekg")

    return _dedupe_preserve(base)[:14]


def main() -> None:
    merged = json.loads(MERGED_PATH.read_text(encoding="utf-8"))
    attributes = merged.get("attributes", {})

    categories: list[dict] = []
    excluded_baseline: list[str] = []
    excluded_hidden: list[str] = []

    for category_name, fields in attributes.items():
        if not isinstance(fields, dict):
            continue
        for field_name, field_info in fields.items():
            if not isinstance(field_info, dict):
                continue

            path = f"{category_name}.{field_name}"
            if path in BASELINE_PATHS:
                excluded_baseline.append(path)
                continue
            if field_info.get("medic_visible") is False:
                excluded_hidden.append(path)
                continue

            field_title = _humanize(field_name)
            title = f"{category_name} - {field_title}"
            description = field_info.get("description", "") or f"{field_title} field in {category_name}."

            categories.append(
                {
                    "id": _ascii(path),
                    "title": _ascii(title),
                    "description": _ascii(description),
                    "examples": _build_examples(category_name, field_name, field_title, field_info),
                    "synonyms": _build_synonyms(category_name, field_title, field_name, description),
                }
            )

    OUTPUT_PATH.write_text(json.dumps(categories, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "total_generated": len(categories),
                "excluded_baseline": excluded_baseline,
                "excluded_hidden": excluded_hidden,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
