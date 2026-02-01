from __future__ import annotations

from dataclasses import dataclass
import json
import logging
from pathlib import Path
from time import perf_counter
from typing import Dict, List, Optional, Tuple

try:
    from fastapi import FastAPI
    from pydantic import BaseModel, Field
except ModuleNotFoundError:  # Allow importing scoring logic without API deps installed.
    FastAPI = None  # type: ignore[assignment]
    BaseModel = object  # type: ignore[assignment]
    Field = lambda *args, **kwargs: None  # type: ignore[assignment]

from embedder import create_embedder, similarity_scores


DISCLAIMER = "Navigation aid only; not clinical decision support."
LOW_CONF_THRESHOLD = 0.65
PATHWAY_MIN_SCORE = 0.75

logger = logging.getLogger("semantic_search")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")


@dataclass
class Category:
    id: str
    title: str
    description: str
    examples: List[str]
    synonyms: List[str]


@dataclass
class Pathway:
    id: str
    title: str
    description: str
    examples: List[str]
    synonyms: List[str]


def _load_categories(path: Path) -> List[Category]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    seen = set()
    categories: List[Category] = []
    for item in raw:
        if item["id"] in seen:
            raise ValueError(f"Duplicate category id: {item['id']}")
        seen.add(item["id"])
        categories.append(
            Category(
                id=item["id"],
                title=item["title"],
                description=item["description"],
                examples=list(item.get("examples", [])),
                synonyms=list(item.get("synonyms", [])),
            )
        )
    return categories


def _load_pathways(path: Path) -> List[Pathway]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    seen = set()
    pathways: List[Pathway] = []
    for item in raw:
        if item["id"] in seen:
            raise ValueError(f"Duplicate pathway id: {item['id']}")
        seen.add(item["id"])
        pathways.append(
            Pathway(
                id=item["id"],
                title=item["title"],
                description=item["description"],
                examples=list(item.get("examples", [])),
                synonyms=list(item.get("synonyms", [])),
            )
        )
    return pathways


def _build_doc(item: Category | Pathway) -> str:
    examples = "; ".join(item.examples)
    synonyms = ", ".join(item.synonyms)
    return f"{item.title}. {item.description}. Examples: {examples}. Synonyms: {synonyms}."


def _dedupe_preserve(items: List[str]) -> List[str]:
    seen = set()
    deduped: List[str] = []
    for item in items:
        if item not in seen:
            deduped.append(item)
            seen.add(item)
    return deduped


BASE_DIR = Path(__file__).resolve().parent
CATEGORIES = _load_categories(BASE_DIR / "categories.json")
CATEGORY_DOCS = [_build_doc(cat) for cat in CATEGORIES]
EMBEDDER, CATEGORY_MATRIX = create_embedder(CATEGORY_DOCS)

PATHWAYS = _load_pathways(BASE_DIR / "pathways.json")
PATHWAY_DOCS = [_build_doc(pathway) for pathway in PATHWAYS]
if EMBEDDER.name.startswith("sentence-transformers:"):
    PATHWAY_EMBEDDER = EMBEDDER
    PATHWAY_MATRIX = EMBEDDER.embed_texts(PATHWAY_DOCS)
else:
    PATHWAY_EMBEDDER, PATHWAY_MATRIX = create_embedder(PATHWAY_DOCS)

app = FastAPI(title="Paramedic Handover Semantic Suggestions", version="1.0.0") if FastAPI else None


class SuggestRequest(BaseModel):
    text: str = Field(..., max_length=2000)
    delta: float = Field(0.12, ge=0.0, le=1.0)
    min_score: Optional[float] = Field(None, ge=0.0)
    max_results: int = Field(8, ge=1, le=50)
    min_results: int = Field(3, ge=1, le=20)
    session_id: Optional[str] = None


class Suggestion(BaseModel):
    id: str
    title: str
    final_score: float
    semantic_score: float
    rule_boost: float
    why: List[str]


class SuggestResponse(BaseModel):
    suggestions: List[Suggestion]
    meta: Dict[str, object]


class PathwaySuggestRequest(BaseModel):
    text: str = Field(..., max_length=2000)
    min_score: Optional[float] = Field(None, ge=0.0, le=1.0)
    session_id: Optional[str] = None


class PathwaySuggestion(BaseModel):
    id: str
    title: str
    score: float
    why: List[str]


class PathwaySuggestResponse(BaseModel):
    suggestion: Optional[PathwaySuggestion]
    meta: Dict[str, object]


@dataclass
class Candidate:
    id: str
    title: str
    final_score: float
    semantic_score: float
    rule_boost: float
    why: List[str]
    forced: bool


@dataclass
class PathwayCandidate:
    id: str
    title: str
    semantic_score: float
    why: List[str]


def select_categories(
    candidates: List[Candidate],
    delta: float,
    min_score: Optional[float],
    min_results: int,
    max_results: int,
) -> Tuple[List[Candidate], Dict[str, object]]:
    s_max = max((c.semantic_score for c in candidates), default=0.0)
    low_confidence_mode = s_max < LOW_CONF_THRESHOLD
    floor_score = min_score if min_score is not None else LOW_CONF_THRESHOLD
    relative_threshold = s_max - delta
    threshold_score = max(relative_threshold, floor_score)

    if min_score is not None and threshold_score == min_score:
        strategy_used = "combined"
    elif threshold_score == floor_score and floor_score > relative_threshold:
        strategy_used = "floor"
    else:
        strategy_used = "relative"

    candidate_ids = {c.id for c in candidates if c.semantic_score >= threshold_score}
    selected_ids: set[str] = set(candidate_ids)
    floor_added_ids: List[str] = []
    topk_added_ids: List[str] = []

    if len(selected_ids) < min_results:
        for candidate in sorted(candidates, key=lambda c: c.semantic_score, reverse=True):
            if candidate.id in selected_ids:
                continue
            selected_ids.add(candidate.id)
            if candidate.semantic_score >= floor_score:
                floor_added_ids.append(candidate.id)
            else:
                topk_added_ids.append(candidate.id)
            if len(selected_ids) >= min_results:
                break

    if len(selected_ids) > max_results:
        limited = sorted(
            (c for c in candidates if c.id in selected_ids),
            key=lambda c: c.semantic_score,
            reverse=True,
        )
        selected_ids = {c.id for c in limited[:max_results]}

    selected = [c for c in candidates if c.id in selected_ids]
    selected.sort(key=lambda c: c.semantic_score, reverse=True)

    return selected, {
        "strategy_used": strategy_used,
        "s_max": s_max,
        "forced_ids": [],
        "baseline_added_ids": [],
        "max_exceeded_due_to_forced": False,
        "low_confidence_mode": low_confidence_mode,
        "low_conf_threshold": LOW_CONF_THRESHOLD,
        "threshold_score": threshold_score,
        "floor_score": floor_score,
        "floor_added_ids": floor_added_ids,
        "topk_added_ids": topk_added_ids,
    }


def select_pathway(
    candidates: List[PathwayCandidate],
    min_score: Optional[float],
) -> Tuple[Optional[PathwayCandidate], Dict[str, object]]:
    if not candidates:
        return None, {
            "min_score": min_score,
            "threshold_score": min_score if min_score is not None else PATHWAY_MIN_SCORE,
            "top_score": 0.0,
        }

    top = max(candidates, key=lambda c: c.semantic_score)
    threshold = min_score if min_score is not None else PATHWAY_MIN_SCORE
    selected = top if top.semantic_score >= threshold else None
    return selected, {
        "min_score": min_score,
        "threshold_score": threshold,
        "top_score": top.semantic_score,
    }


def _score_candidates(text: str) -> List[Candidate]:
    if text.strip():
        query_vec = EMBEDDER.embed_text(text)
        sem_scores = similarity_scores(EMBEDDER, query_vec, CATEGORY_MATRIX)
    else:
        sem_scores = [0.0] * len(CATEGORIES)

    candidates: List[Candidate] = []

    for idx, cat in enumerate(CATEGORIES):
        sem_score = float(sem_scores[idx])
        why: List[str] = []
        why.append(f"semantic: {sem_score:.2f}")
        candidates.append(
            Candidate(
                id=cat.id,
                title=cat.title,
                final_score=sem_score,
                semantic_score=sem_score,
                rule_boost=0.0,
                why=_dedupe_preserve(why),
                forced=False,
            )
        )

    return candidates


def _score_pathways(text: str) -> List[PathwayCandidate]:
    if not text.strip():
        return []

    query_vec = PATHWAY_EMBEDDER.embed_text(text)
    sem_scores = similarity_scores(PATHWAY_EMBEDDER, query_vec, PATHWAY_MATRIX)

    candidates: List[PathwayCandidate] = []
    for idx, pathway in enumerate(PATHWAYS):
        sem_score = float(sem_scores[idx])
        candidates.append(
            PathwayCandidate(
                id=pathway.id,
                title=pathway.title,
                semantic_score=sem_score,
                why=[f"semantic: {sem_score:.2f}"],
            )
        )
    return candidates


if app is not None:
    @app.post("/suggest", response_model=SuggestResponse)
    def suggest(request: SuggestRequest) -> SuggestResponse:
        start = perf_counter()
        scored = _score_candidates(request.text)
        candidates, selection_meta = select_categories(
            scored,
            request.delta,
            request.min_score,
            request.min_results,
            request.max_results,
        )
        latency_ms = int((perf_counter() - start) * 1000)

        logger.info("suggest latency_ms=%d model=%s", latency_ms, EMBEDDER.name)

        floor_added_ids = set(selection_meta.get("floor_added_ids", []))
        topk_added_ids = set(selection_meta.get("topk_added_ids", []))

        suggestions = [
            Suggestion(
                id=c.id,
                title=c.title,
                final_score=round(c.final_score, 4),
                semantic_score=round(c.semantic_score, 4),
                rule_boost=round(c.rule_boost, 4),
                why=_dedupe_preserve(
                    c.why
                    + (
                        ["selected_by_floor"]
                        if c.id in floor_added_ids
                        else (
                            ["selected_by_topk"]
                            if c.id in topk_added_ids
                            else ["selected_by_threshold"]
                        )
                    )
                ),
            )
            for c in candidates
        ]
        return SuggestResponse(
            suggestions=suggestions,
            meta={
                "model": EMBEDDER.name,
                "latency_ms": latency_ms,
                "disclaimer": DISCLAIMER,
                "delta": request.delta,
                "min_score": request.min_score,
                "max_results": request.max_results,
                "min_results": request.min_results,
                **selection_meta,
            },
        )

    @app.post("/pathways/suggest", response_model=PathwaySuggestResponse)
    def suggest_pathway(request: PathwaySuggestRequest) -> PathwaySuggestResponse:
        start = perf_counter()
        candidates = _score_pathways(request.text)
        selected, selection_meta = select_pathway(candidates, request.min_score)
        latency_ms = int((perf_counter() - start) * 1000)

        logger.info("pathway_suggest latency_ms=%d model=%s", latency_ms, PATHWAY_EMBEDDER.name)

        suggestion = None
        if selected:
            suggestion = PathwaySuggestion(
                id=selected.id,
                title=selected.title,
                score=round(selected.semantic_score, 4),
                why=_dedupe_preserve(selected.why + ["selected_by_threshold"]),
            )

        return PathwaySuggestResponse(
            suggestion=suggestion,
            meta={
                "model": PATHWAY_EMBEDDER.name,
                "latency_ms": latency_ms,
                "disclaimer": DISCLAIMER,
                **selection_meta,
            },
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
