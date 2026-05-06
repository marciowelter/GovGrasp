"""
GovGrasp Worker — UK Government Procurement Intelligence Pipeline.

This worker periodically scrapes procurement data from Find a Tender (FTS)
and Contracts Finder, processes it, and stores results in the database.
"""

import logging
import os
import time

import schedule
import structlog
from dotenv import load_dotenv

load_dotenv()

structlog.configure(
    wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
)
log = structlog.get_logger()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "govgrasp")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
OPEN_CLAW_API_KEY = os.getenv("OPEN_CLAW_API_KEY", "")


def fetch_contracts() -> None:
    """Fetch and process new procurement contracts."""
    log.info("fetch_contracts.start")
    # TODO: Implement procurement data fetching from:
    # - Find a Tender Service (FTS): https://www.find-tender.service.gov.uk
    # - Contracts Finder: https://www.contractsfinder.service.gov.uk
    log.info("fetch_contracts.done")


def main() -> None:
    log.info("worker.starting", db_host=DB_HOST, db_port=DB_PORT)

    schedule.every(1).hours.do(fetch_contracts)

    # Run immediately on start
    fetch_contracts()

    while True:
        schedule.run_pending()
        time.sleep(60)


if __name__ == "__main__":
    main()
