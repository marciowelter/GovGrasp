"""S3 storage for raw OCDS JSON payloads."""

from __future__ import annotations

import json
import os
from typing import Any

import structlog

log = structlog.get_logger()

_BUCKET = os.getenv("S3_BUCKET_DATA", "")
_REGION = os.getenv("AWS_DEFAULT_REGION", "eu-west-2")


def upload_raw_json(ocid: str, data: dict[str, Any]) -> str | None:
    """Upload a raw OCDS release to S3 and return its key, or None if S3 is not configured."""
    if not _BUCKET:
        log.debug("s3.skip", reason="S3_BUCKET_DATA not set")
        return None

    try:
        import boto3

        key = f"raw/{ocid}.json"
        boto3.client("s3", region_name=_REGION).put_object(
            Bucket=_BUCKET,
            Key=key,
            Body=json.dumps(data, ensure_ascii=False).encode(),
            ContentType="application/json",
        )
        log.info("s3.uploaded", key=key, bucket=_BUCKET)
        return key
    except Exception as exc:  # noqa: BLE001
        log.warning("s3.upload_failed", ocid=ocid, error=str(exc))
        return None
