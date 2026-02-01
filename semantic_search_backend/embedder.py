from __future__ import annotations

from dataclasses import dataclass
import os
from typing import Sequence, Tuple

import numpy as np

try:
    from sentence_transformers import SentenceTransformer

    _HAS_ST = True
except Exception:
    _HAS_ST = False

from sklearn.feature_extraction.text import TfidfVectorizer


@dataclass
class Embedder:
    name: str
    score_range: str  # "0-1" or "cosine-1-1"

    def embed_texts(self, texts: Sequence[str]) -> np.ndarray:  # pragma: no cover - interface
        raise NotImplementedError

    def embed_text(self, text: str) -> np.ndarray:
        return self.embed_texts([text])[0]


class SentenceTransformerEmbedder(Embedder):
    def __init__(self, model_name: str = "all-MiniLM-L6-v2", device: str = "cpu") -> None:
        self.model = SentenceTransformer(model_name, device=device)
        super().__init__(name=f"sentence-transformers:{model_name}", score_range="cosine-1-1")

    def embed_texts(self, texts: Sequence[str]) -> np.ndarray:
        vectors = self.model.encode(list(texts), normalize_embeddings=True)
        return np.asarray(vectors, dtype=np.float32)


class TfidfEmbedder(Embedder):
    def __init__(self, corpus: Sequence[str]) -> None:
        self.vectorizer = TfidfVectorizer(
            lowercase=True,
            stop_words="english",
            ngram_range=(1, 2),
            norm="l2",
        )
        self._matrix = self.vectorizer.fit_transform(list(corpus))
        super().__init__(name="tfidf", score_range="0-1")

    @property
    def category_matrix(self) -> np.ndarray:
        return self._matrix.toarray().astype(np.float32)

    def embed_texts(self, texts: Sequence[str]) -> np.ndarray:
        return self.vectorizer.transform(list(texts)).toarray().astype(np.float32)


def create_embedder(corpus: Sequence[str]) -> Tuple[Embedder, np.ndarray]:
    mode = os.getenv("EMBEDDER_MODE", "").strip().lower()
    if mode != "tfidf" and _HAS_ST:
        model_name = os.getenv("EMBEDDER_MODEL", "all-MiniLM-L6-v2")
        embedder = SentenceTransformerEmbedder(model_name=model_name)
        category_vectors = embedder.embed_texts(corpus)
        return embedder, category_vectors

    embedder = TfidfEmbedder(corpus)
    return embedder, embedder.category_matrix


def similarity_scores(embedder: Embedder, query_vec: np.ndarray, category_matrix: np.ndarray) -> np.ndarray:
    scores = category_matrix @ query_vec
    if embedder.score_range == "cosine-1-1":
        scores = (scores + 1.0) / 2.0
    return np.clip(scores, 0.0, 1.0)
