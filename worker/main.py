"""
GovGrasp Worker — UK Government Procurement Intelligence Pipeline.

Exposes a FastAPI HTTP server so Laravel can trigger the pipeline on-demand.
Also runs the pipeline on a configurable schedule (default: every 12 hours).
"""

from __future__ import annotations

import asyncio
import datetime
import logging
import os
from contextlib import asynccontextmanager
from typing import Any

import structlog
from agents.analyst import AnalystAgent
from agents.scout import ScoutAgent
from db.models import Opportunity, WorkerRun
from db.session import get_session, init_db
from dotenv import load_dotenv
from fastapi import BackgroundTasks, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from storage.s3 import upload_raw_json

load_dotenv()

structlog.configure(wrapper_class=structlog.make_filtering_bound_logger(logging.INFO))
log = structlog.get_logger()

SCHEDULE_HOURS = int(os.getenv("SCHEDULE_HOURS", "12"))

_pipeline_lock = asyncio.Lock()


def _parse_dt(value: str | None) -> datetime.datetime | None:
    if not value:
        return None
    try:
        return datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


async def run_pipeline(days_back: int = 1) -> dict[str, Any]:
    """Scout → Analyst → Persist. Returns a summary dict."""
    if _pipeline_lock.locked():
        log.warning("pipeline.skipped", reason="already running")
        return {"status": "skipped", "reason": "pipeline already running"}

    async with _pipeline_lock:
        session = get_session()
        run = WorkerRun(status="running", started_at=datetime.datetime.utcnow())
        session.add(run)
        session.commit()
        session.refresh(run)

        try:
            scout = ScoutAgent(days_back=days_back)
            analyst = AnalystAgent()

            # Fetch releases in a thread so we don't block the event loop
            releases = await asyncio.to_thread(scout.fetch)
            run.opportunities_fetched = len(releases)
            session.commit()

            qualified_count = 0
            for release in releases:
                normalised = scout.normalise(release)
                ocid = normalised["ocid"]
                if not ocid:
                    continue

                # Skip duplicates
                if session.query(Opportunity).filter_by(ocid=ocid).first():
                    continue

                s3_key = await asyncio.to_thread(upload_raw_json, ocid, release)
                analysis = await asyncio.to_thread(analyst.analyse, normalised)

                status = "qualified" if analysis.get("qualified") else "rejected"
                if analysis.get("qualified"):
                    qualified_count += 1

                session.add(
                    Opportunity(
                        ocid=ocid,
                        title=normalised["title"],
                        description=normalised.get("description"),
                        buyer_name=normalised.get("buyer_name"),
                        value_amount=normalised.get("value_amount"),
                        value_currency=normalised.get("value_currency", "GBP"),
                        deadline=_parse_dt(normalised.get("deadline")),
                        published_at=_parse_dt(normalised.get("published_at")),
                        source=normalised.get("source", "contracts_finder"),
                        status=status,
                        qualified=analysis.get("qualified"),
                        ai_score=analysis.get("score"),
                        ai_reasoning=analysis.get("reasoning"),
                        framework=analysis.get("framework"),
                        raw_s3_key=s3_key,
                    )
                )

            session.commit()

            run.status = "completed"
            run.opportunities_qualified = qualified_count
            run.completed_at = datetime.datetime.utcnow()
            session.commit()

            summary = {
                "status": "completed",
                "fetched": run.opportunities_fetched,
                "qualified": qualified_count,
            }
            log.info("pipeline.done", **summary)
            return summary

        except Exception as exc:
            log.error("pipeline.failed", error=str(exc))
            run.status = "failed"
            run.error_message = str(exc)
            run.completed_at = datetime.datetime.utcnow()
            session.commit()
            raise
        finally:
            session.close()


async def _scheduler() -> None:
    log.info("scheduler.start", interval_hours=SCHEDULE_HOURS)
    # First run immediately on startup
    await run_pipeline()
    while True:
        await asyncio.sleep(SCHEDULE_HOURS * 3600)
        await run_pipeline()


@asynccontextmanager
async def lifespan(app: FastAPI):  # type: ignore[type-arg]
    init_db()
    task = asyncio.create_task(_scheduler())
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


app = FastAPI(title="GovGrasp Worker", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/trigger")
async def trigger(background_tasks: BackgroundTasks) -> JSONResponse:
    """Trigger the pipeline immediately (called by the Laravel API)."""
    if _pipeline_lock.locked():
        return JSONResponse(
            {"status": "skipped", "reason": "pipeline already running"}, status_code=202
        )
    background_tasks.add_task(run_pipeline)
    return JSONResponse({"status": "triggered"})


@app.get("/status")
async def status() -> dict[str, Any]:
    """Return the last pipeline run summary."""
    session = get_session()
    try:
        last = session.query(WorkerRun).order_by(WorkerRun.id.desc()).first()
        if not last:
            return {"last_run": None, "is_running": _pipeline_lock.locked()}
        return {
            "is_running": _pipeline_lock.locked(),
            "last_run": {
                "id": last.id,
                "status": last.status,
                "opportunities_fetched": last.opportunities_fetched,
                "opportunities_qualified": last.opportunities_qualified,
                "started_at": last.started_at.isoformat() if last.started_at else None,
                "completed_at": last.completed_at.isoformat()
                if last.completed_at
                else None,
                "error_message": last.error_message,
            },
        }
    finally:
        session.close()
