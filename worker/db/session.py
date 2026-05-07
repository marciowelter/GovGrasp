"""Database session management."""

from __future__ import annotations

import os

from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session, sessionmaker

from .models import Base

_engine: Engine | None = None
_SessionLocal = None


def _ensure_engine() -> None:
    global _engine, _SessionLocal
    if _engine is not None:
        return
    db_url = (
        "postgresql+psycopg2://"
        f"{os.getenv('DB_USER', 'postgres')}:{os.getenv('DB_PASSWORD', 'secret')}"
        f"@{os.getenv('DB_HOST', 'db')}:{os.getenv('DB_PORT', '5432')}"
        f"/{os.getenv('DB_NAME', 'govgrasp')}"
    )
    _engine = create_engine(db_url, pool_pre_ping=True, pool_size=5, max_overflow=10)
    _SessionLocal = sessionmaker(bind=_engine, autoflush=True, autocommit=False)


def init_db() -> None:
    """Create any tables not yet managed by Laravel migrations (safety net for dev)."""
    _ensure_engine()
    Base.metadata.create_all(bind=_engine, checkfirst=True)


def get_session() -> Session:
    _ensure_engine()
    return _SessionLocal()
