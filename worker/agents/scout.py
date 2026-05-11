"""Scout Agent — fetches UK government procurement data from Contracts Finder (OCDS API)."""

from __future__ import annotations

import datetime
from collections.abc import Iterator
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
    """Fetches and normalises releases from the UK Contracts Finder OCDS API.

    Parameters
    ----------
    start_date:
        Inclusive start of the search window (ISO-8601 date string, e.g. ``"2026-05-01"``).
        If *None*, defaults to ``days_back`` days before today.
    end_date:
        Inclusive end of the search window (ISO-8601 date string, e.g. ``"2026-05-07"``).
        If *None*, defaults to today.
    days_back:
        Fallback window size in days when ``start_date`` is not supplied.
    """

    def __init__(
        self,
        start_date: str | None = None,
        end_date: str | None = None,
        days_back: int = 1,
    ) -> None:
        today = datetime.date.today()
        self._end_date: str = end_date or today.isoformat()
        self._start_date: str = (
            start_date or (today - datetime.timedelta(days=days_back)).isoformat()
        )
        self._client = httpx.Client(
            timeout=30.0, headers={"Accept": "application/json"}
        )

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=2, max=10))
    def _fetch_url(self, url: str) -> dict[str, Any]:
        """GET a single URL and return the parsed JSON response."""
        log.info("scout.fetch_page", url=url)
        resp = self._client.get(url)
        resp.raise_for_status()
        return resp.json()

    def iter_releases(self) -> Iterator[dict[str, Any]]:
        """Yield OCDS releases page by page for the configured date window.

        The Contracts Finder OCDS API uses cursor-based pagination: each
        response contains a ``links.next`` URL with an opaque cursor token.
        Incrementing the ``page`` query-string parameter has no effect.
        """
        log.info(
            "scout.fetch_start",
            start_date=self._start_date,
            end_date=self._end_date,
        )
        # Build the URL for the first page only; subsequent pages use the
        # cursor URLs returned by the API in links.next.
        first_url = (
            f"{CONTRACTS_FINDER_BASE}{SEARCH_PATH}"
            f"?{urlencode({'startDate': self._start_date, 'endDate': self._end_date, 'page': 1, 'size': PAGE_SIZE})}"
        )

        next_url: str | None = first_url
        page = 1
        total = 0

        while next_url:
            data = self._fetch_url(next_url)
            batch: list[dict[str, Any]] = data.get("releases", [])
            if not batch:
                break
            total += len(batch)
            # The API signals the next page via links.next (cursor-based).
            # When links.next is absent or empty the current page is the last.
            next_url = data.get("links", {}).get("next") or None
            log.info(
                "scout.page_done",
                page=page,
                batch=len(batch),
                total=total,
                has_next=bool(next_url),
            )
            for release in batch:
                yield release
            page += 1

        log.info("scout.fetch_complete", total=total)

    def fetch(self) -> list[dict[str, Any]]:
        """Return ALL OCDS releases as a list.

        Kept for backwards compatibility. Prefer ``iter_releases`` for
        memory-efficient streaming in long date ranges.
        """
        releases = list(self.iter_releases())
        log.info("scout.fetch_materialized", total=len(releases))
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
