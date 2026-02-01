from __future__ import annotations

import json
import re
from pathlib import Path

"""
Generate pathways.json from JRCALC_Protocols.json, using a tolerant line-based parser.
Goal: capture pathway name, category, and triggers for semantic search on natural language.
"""

BASE_DIR = Path(__file__).resolve().parent
PROTOCOLS_PATH = BASE_DIR / "JRCALC_Protocols.json"
OUTPUT_PATH = BASE_DIR / "pathways.json"

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

NAME_EXPANSIONS: dict[str, list[str]] = {
    # Neuro
    "stroke": ["fast", "facial droop", "slurred speech", "arm weakness", "face arm speech", "tia"],
    "tia": ["fast", "facial droop", "slurred speech", "arm weakness", "transient ischemic attack"],
    "convulsion": ["seizure", "fit", "tonic clonic", "post ictal"],
    "seizure": ["fit", "tonic clonic", "post ictal"],
    # Cardiac
    "chest pain": ["cp", "central chest pain", "radiating", "left arm", "sweaty", "diaphoretic"],
    "acs": ["mi", "heart attack", "stemi", "nstemi", "acute coronary syndrome"],
    # Respiratory
    "asthma": ["wheeze", "tight chest", "short of breath", "sob"],
    "copd": ["coad", "emphysema", "chronic bronchitis", "blue bloater", "breathless"],
    # Allergy
    "anaphylaxis": ["allergic reaction", "hives", "urticaria", "lip swelling", "tongue swelling", "stridor"],
    # Metabolic
    "hypoglycaemia": ["hypoglycemia", "low sugar", "bgl low", "bm low"],
    "hyperglycaemia": ["hyperglycemia", "high sugar", "bgl high"],
}


def _ascii(text: str) -> str:
    return text.encode("ascii", "ignore").decode("ascii") if text else ""


def _norm_spaces(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _norm_term(text: str) -> str:
    text = _ascii(text)
    text = text.replace("_", " ").replace(".", " ").replace(":", " ").replace("/", " ")
    text = re.sub(r"[^a-zA-Z0-9\s]", " ", text)
    return _norm_spaces(text).lower()


def _dedupe_preserve(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        if item and item not in seen:
            out.append(item)
            seen.add(item)
    return out


def _extract_string(line: str) -> str:
    match = re.search(r'"[^"]+"\s*:\s*"([^"]*)"', line)
    return match.group(1) if match else ""


def _parse_protocols(text: str) -> list[dict]:
    protocols: list[dict] = []
    current: dict[str, object] = {}
    in_triggers = False
    trigger_buffer: list[str] = []

    def flush_current() -> None:
        nonlocal current
        if current.get("condition_id") and current.get("name"):
            protocols.append(current)
        current = {}

    for raw in text.splitlines():
        line = raw.strip()

        if "\"condition_id\"" in line:
            flush_current()
            current["condition_id"] = _extract_string(line)
            continue

        if "\"name\"" in line and "condition_id" in current and "name" not in current:
            current["name"] = _extract_string(line)
            continue

        if "\"category\"" in line and "condition_id" in current and "category" not in current:
            current["category"] = _extract_string(line)
            continue

        if "\"triggers\"" in line and "condition_id" in current:
            in_triggers = True
            trigger_buffer = [line]
            if "]" in line:
                in_triggers = False
                blob = " ".join(trigger_buffer)
                triggers = re.findall(r"\"([^\"]+)\"", blob)
                if triggers and triggers[0].lower() == "triggers":
                    triggers = triggers[1:]
                current["triggers"] = triggers
            continue

        if in_triggers:
            trigger_buffer.append(line)
            if "]" in line:
                in_triggers = False
                blob = " ".join(trigger_buffer)
                triggers = re.findall(r"\"([^\"]+)\"", blob)
                current["triggers"] = triggers
            continue

    flush_current()
    return protocols


def _build_examples(name: str, triggers: list[str]) -> list[str]:
    examples: list[str] = []
    if triggers:
        for trig in triggers[:3]:
            t = _norm_spaces(trig)
            if t:
                examples.append(t)
                examples.append(f"Pt with {t}")
        examples = examples[:4]
    # Add a couple of common real-world phrasing hints based on the pathway name.
    name_norm = _norm_term(name)
    for key, vals in NAME_EXPANSIONS.items():
        if key in name_norm:
            for val in vals[:2]:
                examples.append(val)
            break
    if name:
        examples.append(f"Suspected {name}")
        examples.append(f"Possible {name}")
    return _dedupe_preserve([_ascii(_norm_spaces(e)) for e in examples])[:6]


def _build_synonyms(name: str, category: str, triggers: list[str]) -> list[str]:
    syns: list[str] = []
    if name:
        syns.append(name)
    if category:
        syns.append(category)
    syns.extend(triggers)
    # Add normalized forms for matching.
    syns.extend([_norm_term(name), _norm_term(category)])
    # Add name-driven expansions (clinical jargon/phrasing).
    name_norm = _norm_term(name)
    for key, vals in NAME_EXPANSIONS.items():
        if key in name_norm:
            syns.extend(vals)
    return _dedupe_preserve([s for s in syns if s])[:20]


def main() -> None:
    text = PROTOCOLS_PATH.read_text(encoding="utf-8", errors="ignore")
    protocols = _parse_protocols(text)

    pathways: list[dict] = []
    for proto in protocols:
        condition_id = str(proto.get("condition_id", "")).strip()
        name = str(proto.get("name", "")).strip()
        category = str(proto.get("category", "")).strip()
        triggers = list(proto.get("triggers") or [])

        if not condition_id or not name:
            continue

        description = f"JRCalc pathway for {name}."
        if category:
            description = f"JRCalc pathway for {name} ({category})."

        pathways.append(
            {
                "id": _ascii(condition_id),
                "title": _ascii(name),
                "description": _ascii(description),
                "examples": _build_examples(name, triggers),
                "synonyms": _build_synonyms(name, category, triggers),
            }
        )

    OUTPUT_PATH.write_text(json.dumps(pathways, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(json.dumps({"total_pathways": len(pathways)}, indent=2))


if __name__ == "__main__":
    main()
