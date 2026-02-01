from __future__ import annotations

from main import _score_candidates, select_categories


SAMPLES = [
    {
        "label": "Clear input (few attributes)",
        "text": "Chest pain radiating left arm, sweaty",
    },
    {
        "label": "Vague input (floor gate)",
        "text": "Feels unwell today",
    },
    {
        "label": "Multi-signal input (multiple sections)",
        "text": "SOB with wheeze, sats 88%, allergic reaction, hives",
    },
]


def run() -> None:
    for sample in SAMPLES:
        text = sample["text"]
        scored = _score_candidates(text)
        results, meta = select_categories(
            scored,
            delta=0.12,
            min_score=None,
            min_results=3,
            max_results=8,
        )
        ids = [r.id for r in results]
        print(f"\n{sample['label']}: {text}")
        print("Suggestions:", ids)
        print(
            "Meta:",
            {
                k: meta[k]
                for k in (
                    "strategy_used",
                    "s_max",
                    "low_confidence_mode",
                    "threshold_score",
                    "floor_score",
                    "floor_added_ids",
                    "topk_added_ids",
                )
            },
        )


if __name__ == "__main__":
    run()
