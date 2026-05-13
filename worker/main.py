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
from agents.analyst import _DEFAULT_COMPANY_PROFILE, AnalystAgent
from agents.scout import ScoutAgent
from db.models import Opportunity, WorkerRun
from db.session import get_session, init_db
from dotenv import load_dotenv
from fastapi import BackgroundTasks, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from storage.s3 import upload_raw_json

load_dotenv()

structlog.configure(wrapper_class=structlog.make_filtering_bound_logger(logging.INFO))
log = structlog.get_logger()

SCHEDULE_HOURS = int(os.getenv("SCHEDULE_HOURS", "12"))
AUTO_RUN_ON_STARTUP = os.getenv("AUTO_RUN_ON_STARTUP", "false").lower() in {
    "1",
    "true",
    "yes",
    "on",
}
COMMIT_EVERY_N = int(os.getenv("COMMIT_EVERY_N", "25"))

_pipeline_lock = asyncio.Lock()
_cancel_requested = asyncio.Event()


class PipelineRequest(BaseModel):
    """Optional body for POST /trigger — all fields are optional."""

    start_date: str | None = Field(
        default=None,
        description="ISO-8601 date (YYYY-MM-DD). Start of the search window.",
        examples=["2026-05-01"],
    )
    end_date: str | None = Field(
        default=None,
        description="ISO-8601 date (YYYY-MM-DD). End of the search window.",
        examples=["2026-05-07"],
    )
    days_back: int = Field(
        default=1,
        ge=1,
        description="Fallback window in days when start_date is not supplied.",
    )
    company_profile: str | None = Field(
        default=None,
        description="Free-text description of the company used by the Analyst to score relevance.",
    )
    reanalyse: bool = Field(
        default=False,
        description="When true, re-run AI analysis even on already-scored opportunities.",
    )


def _parse_dt(value: str | None) -> datetime.datetime | None:
    if not value:
        return None
    try:
        return datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _mark_run_failed(run_id: int, error_message: str) -> None:
    """Persist failed terminal state even if the primary session is broken."""
    failed_at = datetime.datetime.now(datetime.UTC)
    fallback = get_session()
    try:
        fallback.query(WorkerRun).filter(WorkerRun.id == run_id).update(
            {
                "status": "failed",
                "error_message": error_message,
                "completed_at": failed_at,
            },
            synchronize_session=False,
        )
        fallback.commit()
    except Exception as persist_exc:
        fallback.rollback()
        log.error(
            "pipeline.fail_persist_error",
            run_id=run_id,
            error=str(persist_exc),
        )
    finally:
        fallback.close()


async def run_pipeline(
    start_date: str | None = None,
    end_date: str | None = None,
    days_back: int = 1,
    company_profile: str | None = None,
    reanalyse: bool = False,
) -> dict[str, Any]:
    """Scout → Analyst → Persist. Returns a summary dict.

    Parameters
    ----------
    start_date / end_date:
        Explicit ISO-8601 dates for the UK Gov search window.
        If omitted, falls back to the last ``days_back`` days.
    company_profile:
        Free-text description injected into the Analyst system prompt.
    reanalyse:
        When *True*, re-score records that already have an AI score.
    """
    if _pipeline_lock.locked():
        log.warning("pipeline.skipped", reason="already running")
        return {"status": "skipped", "reason": "pipeline already running"}

    async with _pipeline_lock:
        _cancel_requested.clear()
        session = get_session()
        run = WorkerRun(
            status="running", started_at=datetime.datetime.now(datetime.UTC)
        )
        session.add(run)
        session.commit()
        session.refresh(run)

        try:
            scout = ScoutAgent(
                start_date=start_date,
                end_date=end_date,
                days_back=days_back,
            )
            analyst = AnalystAgent(company_profile=company_profile)

            qualified_count = 0
            skipped_count = 0
            processed_count = 0
            fetched_count = 0

            for release in scout.iter_releases():
                fetched_count += 1
                run.opportunities_fetched = fetched_count

                if _cancel_requested.is_set():
                    run.status = "cancelled"
                    run.opportunities_qualified = qualified_count
                    run.completed_at = datetime.datetime.now(datetime.UTC)
                    session.commit()
                    summary = {
                        "status": "cancelled",
                        "fetched": fetched_count,
                        "qualified": qualified_count,
                        "processed": processed_count,
                        "skipped_already_scored": skipped_count,
                    }
                    log.warning("pipeline.cancelled", **summary)
                    return summary

                normalised = scout.normalise(release)
                ocid = normalised["ocid"]
                if not ocid:
                    continue

                existing: Opportunity | None = (
                    session.query(Opportunity).filter_by(ocid=ocid).first()
                )

                # Skip if already scored and reanalyse was not requested
                if (
                    existing is not None
                    and existing.ai_score is not None
                    and not reanalyse
                ):
                    skipped_count += 1
                    log.debug(
                        "pipeline.skip_scored", ocid=ocid, ai_score=existing.ai_score
                    )
                    if existing.qualified:
                        qualified_count += 1
                    continue

                s3_key = await asyncio.to_thread(upload_raw_json, ocid, release)
                analysis = await asyncio.to_thread(analyst.analyse, normalised)
                processed_count += 1

                opp_status = "qualified" if analysis.get("qualified") else "rejected"
                if analysis.get("qualified"):
                    qualified_count += 1

                if existing is not None:
                    # Update the existing row with fresh analysis
                    existing.status = opp_status
                    existing.qualified = analysis.get("qualified")
                    existing.ai_score = analysis.get("score")
                    existing.ai_reasoning = analysis.get("reasoning")
                    existing.framework = analysis.get("framework")
                    existing.raw_s3_key = s3_key or existing.raw_s3_key
                else:
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
                            status=opp_status,
                            qualified=analysis.get("qualified"),
                            ai_score=analysis.get("score"),
                            ai_reasoning=analysis.get("reasoning"),
                            framework=analysis.get("framework"),
                            raw_s3_key=s3_key,
                        )
                    )

                # Persist progress incrementally so long runs are resumable and visible.
                if COMMIT_EVERY_N > 0 and processed_count % COMMIT_EVERY_N == 0:
                    run.opportunities_fetched = fetched_count
                    run.processed_count = processed_count
                    run.opportunities_qualified = qualified_count
                    session.commit()
                    log.info(
                        "pipeline.progress",
                        processed=processed_count,
                        fetched=fetched_count,
                        qualified=qualified_count,
                    )

            run.opportunities_fetched = fetched_count
            run.processed_count = processed_count
            session.commit()

            run.status = "completed"
            run.opportunities_qualified = qualified_count
            run.completed_at = datetime.datetime.now(datetime.UTC)
            session.commit()

            summary = {
                "status": "completed",
                "fetched": fetched_count,
                "qualified": qualified_count,
                "processed": processed_count,
                "skipped_already_scored": skipped_count,
            }
            log.info("pipeline.done", **summary)
            return summary

        except Exception as exc:
            error_message = str(exc)
            log.error("pipeline.failed", error=error_message)

            # SQLAlchemy marks the transaction as failed after flush/autoflush
            # exceptions, so rollback first and persist failure in a fresh session.
            try:
                session.rollback()
            except Exception as rollback_exc:
                log.error("pipeline.rollback_failed", error=str(rollback_exc))

            _mark_run_failed(run.id, error_message)
            raise
        finally:
            session.close()


async def _scheduler() -> None:
    log.info("scheduler.start", interval_hours=SCHEDULE_HOURS)
    if AUTO_RUN_ON_STARTUP:
        await run_pipeline()
    else:
        log.info("scheduler.autorun_disabled")
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
        raise


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
async def trigger(
    background_tasks: BackgroundTasks,
    body: PipelineRequest = PipelineRequest(),
) -> JSONResponse:
    """Trigger the pipeline immediately.

    All body fields are optional — pass start_date, end_date, company_profile,
    days_back, and reanalyse as needed.
    """
    if _pipeline_lock.locked():
        return JSONResponse(
            {"status": "skipped", "reason": "pipeline already running"}, status_code=202
        )
    background_tasks.add_task(
        run_pipeline,
        start_date=body.start_date,
        end_date=body.end_date,
        days_back=body.days_back,
        company_profile=body.company_profile,
        reanalyse=body.reanalyse,
    )
    return JSONResponse({"status": "triggered"})


@app.post("/abort")
async def abort_pipeline() -> JSONResponse:
    """Request graceful cancellation of the active pipeline run."""
    if not _pipeline_lock.locked():
        return JSONResponse({"status": "idle", "message": "no active pipeline"})
    _cancel_requested.set()
    return JSONResponse({"status": "cancelling"})


@app.get("/config/defaults")
async def get_defaults() -> dict[str, Any]:
    """Return default pipeline configuration values."""
    return {"default_company_profile": _DEFAULT_COMPANY_PROFILE}


@app.get("/status")
async def pipeline_status() -> dict[str, Any]:
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
                "processed_count": last.processed_count,
                "opportunities_qualified": last.opportunities_qualified,
                "started_at": last.started_at.isoformat() if last.started_at else None,
                "completed_at": (
                    last.completed_at.isoformat() if last.completed_at else None
                ),
                "error_message": last.error_message,
            },
        }
    finally:
        session.close()
