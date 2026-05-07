"""Analyst Agent — classifies opportunities using a local LLM via Ollama."""

from __future__ import annotations

import json
import os
from typing import Any

import ollama
import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

log = structlog.get_logger()

_SYSTEM_PROMPT = """You are a B2B technology sales analyst specialising in UK government procurement.
Evaluate whether a government tender is relevant for a software development company.

RELEVANT: software development, digital services, IT infrastructure, cloud services, data engineering,
cybersecurity, AI/ML, SaaS, web/mobile development, tech consultancy, G-Cloud, DOS framework.

IRRELEVANT: construction, logistics, catering, facilities management, clinical healthcare, non-tech legal.

Respond ONLY with a valid JSON object — no markdown, no extra text:
{
  "qualified": <boolean>,
  "score": <integer 0-100, 100 = perfect match>,
  "reasoning": "<max 200 chars>",
  "framework": "<e.g. G-Cloud, DOS, CCS RM6259, or null>"
}"""


class AnalystAgent:
    """Uses a local LLM (LLaMA 3.1 8B via Ollama) to qualify and score procurement opportunities."""

    def __init__(self) -> None:
        ollama_host = os.getenv("OLLAMA_HOST", "http://ollama:11434")
        self._model = os.getenv("LLM_MODEL", "llama3.1:8b")
        self._client = ollama.Client(host=ollama_host)

        # Ensure the model is available locally; pull it if not yet cached.
        try:
            self._client.show(self._model)
            log.info("analyst.model_ready", model=self._model, host=ollama_host)
        except ollama.ResponseError:
            log.info("analyst.pulling_model", model=self._model, host=ollama_host)
            for progress in self._client.pull(self._model, stream=True):
                status = progress.get("status", "")
                if status:
                    log.info("analyst.pull_progress", status=status)
            log.info("analyst.model_ready", model=self._model)

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=2, max=8))
    def analyse(self, opportunity: dict[str, Any]) -> dict[str, Any]:
        """Return classification dict for a normalised opportunity."""
        user_msg = (
            f"Title: {opportunity.get('title', '')}\n"
            f"Buyer: {opportunity.get('buyer_name', '')}\n"
            f"Value: {opportunity.get('value_amount')} {opportunity.get('value_currency', 'GBP')}\n"
            f"Description: {(opportunity.get('description') or '')[:1200]}"
        )

        response = self._client.chat(
            model=self._model,
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": user_msg},
            ],
            format="json",
            options={"temperature": 0},
        )

        result: dict[str, Any] = json.loads(response.message.content)
        log.info(
            "analyst.classified",
            ocid=opportunity.get("ocid"),
            qualified=result.get("qualified"),
            score=result.get("score"),
        )
        return result
