"""Scout Agent — fetches UK government procurement data from Contracts Finder (OCDS API)."""

from __future__ import annotations

import datetime
from typing import Any
from urllib.parse import urlencode

import httpx
import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

log = structlog.get_logger()

CONTRACTS_FINDER_BASE = "https://www.contractsfinder.service.gov.uk"
SEARCH_PATH = "/Published/Notices/OCDS/Search"
PAGE_SIZE = 100


class ScoutAgent:
    """Fetches and normalises releases from the UK Contracts Finder OCDS API."""

    def __init__(self, days_back: int = 1) -> None:
        self.days_back = days_back
        self._client = httpx.Client(
            timeout=30.0, headers={"Accept": "application/json"}
        )

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=2, max=10))
    def _fetch_page(self, start_date: str, end_date: str, page: int) -> dict[str, Any]:
        params = {
            "startDate": start_date,
            "endDate": end_date,
            "page": page,
            "size": PAGE_SIZE,
        }
        url = f"{CONTRACTS_FINDER_BASE}{SEARCH_PATH}?{urlencode(params)}"
        log.info("scout.fetch_page", page=page, url=url)
        resp = self._client.get(url)
        resp.raise_for_status()
        return resp.json()

    def fetch(self) -> list[dict[str, Any]]:
        """Return all OCDS releases published in the last ``days_back`` days."""
        end = datetime.date.today()
        start = end - datetime.timedelta(days=self.days_back)
        releases: list[dict[str, Any]] = []
        page = 1  # Contracts Finder API is 1-indexed
        while True:
            data = self._fetch_page(start.isoformat(), end.isoformat(), page)
            batch: list[dict[str, Any]] = data.get("releases", [])
            if not batch:
                break
            releases.extend(batch)
            total_pages: int = data.get("totalPages", 1)
            log.info(
                "scout.page_done",
                page=page,
                total_pages=total_pages,
                batch=len(batch),
                total=len(releases),
            )
            if page >= total_pages or len(batch) < PAGE_SIZE:
                break
            page += 1
        log.info("scout.fetch_complete", total=len(releases))
        return releases

    @staticmethod
    def normalise(release: dict[str, Any]) -> dict[str, Any]:
        """Flatten an OCDS release into a plain dict suitable for the DB."""
        tender = release.get("tender", {})
        buyer = release.get("buyer", {})
        value = tender.get("value", {})
        period = tender.get("tenderPeriod", {})
        return {
            "ocid": release.get("ocid", ""),
            "title": (tender.get("title") or "")[:500],
            "description": tender.get("description") or "",
            "buyer_name": (buyer.get("name") or "")[:255],
            "value_amount": value.get("amount"),
            "value_currency": value.get("currency", "GBP"),
            "deadline": period.get("endDate"),
            "published_at": release.get("date"),
            "source": "contracts_finder",
            "raw": release,
        }

    def __del__(self) -> None:
        self._client.close()
