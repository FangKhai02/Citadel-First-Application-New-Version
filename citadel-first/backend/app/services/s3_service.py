"""
S3 service for generating presigned upload/download URLs.

Images are uploaded by the mobile app directly to S3 using a presigned PUT URL,
bypassing the backend to avoid routing large files through the API server.
"""

import logging
from uuid import uuid4

import boto3
from botocore.exceptions import ClientError

from app.core.config import settings

logger = logging.getLogger(__name__)

_s3_client = boto3.client(
    "s3",
    aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
    aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    region_name=settings.AWS_REGION,
    endpoint_url=settings.AWS_ENDPOINT or None,
)


def generate_presigned_upload_url(
    key: str,
    content_type: str = "image/jpeg",
    expires_in: int = 300,
) -> str:
    """
    Generate a presigned PUT URL for the mobile app to upload an image directly to S3.
    """
    return _s3_client.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": settings.AWS_S3_BUCKET,
            "Key": key,
            "ContentType": content_type,
        },
        ExpiresIn=expires_in,
    )


def generate_presigned_download_url(
    key: str,
    expires_in: int = 300,
) -> str:
    """
    Generate a presigned GET URL to retrieve a stored document image.
    """
    return _s3_client.generate_presigned_url(
        "get_object",
        Params={
            "Bucket": settings.AWS_S3_BUCKET,
            "Key": key,
        },
        ExpiresIn=expires_in,
    )


def build_identity_doc_key(
    app_user_id: int,
    doc_type: str,
    side: str,
    filename: str | None = None,
) -> str:
    """
    Build a deterministic S3 key for identity document uploads.

    Format: identity-docs/{app_user_id}/{timestamp}_{side}_{doc_type}.jpg
    """
    import time

    ts = int(time.time())
    safe_filename = filename or f"{ts}_{side}_{doc_type}"
    return f"identity-docs/{app_user_id}/{safe_filename}"
