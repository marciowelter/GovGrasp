"""Analyst Agent — classifies opportunities with an LLM (Open Claw / OpenAI-compatible)."""

from __future__ import annotations

import json
import os
from typing import Any

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
    """Uses an OpenAI-compatible LLM to qualify and score procurement opportunities."""

    def __init__(self) -> None:
        api_key = os.getenv("OPEN_CLAW_API_KEY", "")
        base_url = os.getenv(
            "OPEN_CLAW_BASE_URL"
        )  # Optional: point to any compatible endpoint
        self._model = os.getenv("LLM_MODEL", "gpt-4o-mini")
        self._client = None

        if not api_key:
            log.warning("analyst.disabled", reason="OPEN_CLAW_API_KEY not set")
            return

        try:
            from openai import OpenAI

            self._client = OpenAI(api_key=api_key, base_url=base_url)
        except Exception as exc:
            log.error("analyst.init_failed", error=str(exc))

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=2, max=8))
    def analyse(self, opportunity: dict[str, Any]) -> dict[str, Any]:
        """Return classification dict for a normalised opportunity."""
        if self._client is None:
            return {
                "qualified": False,
                "score": 0,
                "reasoning": "AI analysis disabled — OPEN_CLAW_API_KEY not configured.",
                "framework": None,
            }

        user_msg = (
            f"Title: {opportunity.get('title', '')}\n"
            f"Buyer: {opportunity.get('buyer_name', '')}\n"
            f"Value: {opportunity.get('value_amount')} {opportunity.get('value_currency', 'GBP')}\n"
            f"Description: {(opportunity.get('description') or '')[:1200]}"
        )

        response = self._client.chat.completions.create(
            model=self._model,
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": user_msg},
            ],
            temperature=0,
            max_tokens=300,
            response_format={"type": "json_object"},
        )

        result: dict[str, Any] = json.loads(response.choices[0].message.content)
        log.info(
            "analyst.classified",
            ocid=opportunity.get("ocid"),
            qualified=result.get("qualified"),
            score=result.get("score"),
        )
        return result
