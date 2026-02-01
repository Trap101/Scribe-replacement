from __future__ import annotations

import unittest


try:
    import numpy  # noqa: F401
    import sklearn  # noqa: F401
except ModuleNotFoundError as exc:  # pragma: no cover - dependency gate
    raise unittest.SkipTest(f"Semantic tests require numpy/sklearn. Missing: {exc}")

from main import (
    _score_candidates,
    _score_pathways,
    select_categories,
    select_pathway,
)


def _any_prefix_match(ids: list[str], prefixes: list[str]) -> bool:
    for prefix in prefixes:
        for cid in ids:
            if cid == prefix or cid.startswith(prefix + "."):
                return True
    return False


class CategorySemanticExamplesTest(unittest.TestCase):
    def test_category_semantics_top10(self) -> None:
        cases = [
            {
                "text": "SOB with wheeze, sats 88% on room air, increased work of breathing",
                "expect_prefixes": ["Breathing Assessment", "Pulse Oximetry"],
            },
            {
                "text": "BP 90/60, hypotensive, cool peripheries",
                "expect_prefixes": ["Blood Pressure"],
            },
            {
                "text": "BGL 2.9, sweaty and shaky, low sugar",
                "expect_prefixes": ["Blood Glucose"],
            },
            {
                "text": "Temp 39, febrile, rigors noted",
                "expect_prefixes": ["Body Temperature"],
            },
            {
                "text": "GCS 12, eyes 3, verbal 4, motor 5",
                "expect_prefixes": ["Glasgow Coma Scale"],
            },
            {
                "text": "Airway obstructed with vomit, gurgling sounds",
                "expect_prefixes": ["Airway Assessment"],
            },
            {
                "text": "Pain 8/10 in chest, severe pain",
                "expect_prefixes": ["Pain Assessment"],
            },
        ]

        for case in cases:
            with self.subTest(text=case["text"]):
                scored = _score_candidates(case["text"])
                top = sorted(scored, key=lambda c: c.semantic_score, reverse=True)[:10]
                ids = [c.id for c in top]
                self.assertTrue(
                    _any_prefix_match(ids, case["expect_prefixes"]),
                    msg=f"Expected one of {case['expect_prefixes']} in top 10 for text: {case['text']}",
                )

    def test_category_semantics_selected(self) -> None:
        text = "SOB with wheeze, sats 88% on room air, increased work of breathing"
        scored = _score_candidates(text)
        selected, meta = select_categories(
            scored,
            delta=0.12,
            min_score=None,
            min_results=3,
            max_results=8,
        )
        ids = [c.id for c in selected]
        self.assertTrue(
            _any_prefix_match(ids, ["Breathing Assessment", "Pulse Oximetry"]),
            msg=f"Expected breathing or SpO2 categories in selected set. Meta: {meta}",
        )


class PathwaySemanticExamplesTest(unittest.TestCase):
    def test_pathway_confident_matches(self) -> None:
        cases = [
            {
                "text": "Wheezy, tight chest, sats 88%, uses inhaler at home",
                "expect_title_contains": "asthma",
            },
            {
                "text": "Facial droop, slurred speech, arm weakness started an hour ago",
                "expect_title_contains": "stroke",
            },
            {
                "text": "Itchy rash, hives, lip swelling after peanuts, breathing difficulty",
                "expect_title_contains": "anaphylaxis",
            },
            {
                "text": "Central chest pressure radiating to left arm, sweaty, nausea",
                "expect_title_contains": "chest pain",
            },
        ]

        for case in cases:
            with self.subTest(text=case["text"]):
                candidates = _score_pathways(case["text"])
                selected, meta = select_pathway(candidates, min_score=0.6)
                self.assertIsNotNone(
                    selected,
                    msg=f"No pathway returned. Meta: {meta}",
                )
                assert selected is not None
                self.assertIn(
                    case["expect_title_contains"],
                    selected.title.lower(),
                    msg=f"Expected pathway containing '{case['expect_title_contains']}' for text: {case['text']}",
                )

    def test_pathway_vague_returns_none(self) -> None:
        text = "Feeling unwell today, tired, no specific complaints"
        candidates = _score_pathways(text)
        selected, meta = select_pathway(candidates, min_score=0.9)
        self.assertIsNone(selected, msg=f"Expected None for vague text. Meta: {meta}")


if __name__ == "__main__":
    unittest.main()
