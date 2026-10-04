"""Image upload handling: validates, re-encodes (strips EXIF) and stores on Supabase Storage or local disk."""
from __future__ import annotations

import asyncio
import io
import uuid
from pathlib import Path

import httpx
from fastapi import UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError

from core.config import settings
from core.constants import ALLOWED_IMAGE_TYPES
from core.exceptions import BadRequestError, ServiceUnavailableError


def _process(data: bytes, max_side: int) -> bytes:
    try:
        with Image.open(io.BytesIO(data)) as img:
            img.verify()
        with Image.open(io.BytesIO(data)) as img:
            img = ImageOps.exif_transpose(img)
            img.thumbnail((max_side, max_side))
            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGB")
            out = io.BytesIO()
            img.save(out, format="WEBP", quality=85)
            return out.getvalue()
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError) as exc:
        raise BadRequestError("The uploaded file is not a valid image", code="invalid_image") from exc


async def read_upload(file: UploadFile) -> bytes:
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise BadRequestError("Only JPEG, PNG or WebP images are allowed", code="invalid_image_type")
    limit = settings.MAX_UPLOAD_MB * 1024 * 1024
    data = await file.read(limit + 1)
    if len(data) > limit:
        raise BadRequestError(f"Image exceeds the {settings.MAX_UPLOAD_MB} MB limit", code="file_too_large")
    if not data:
        raise BadRequestError("Empty file", code="invalid_image")
    return data


async def save_image(file: UploadFile, folder: str, max_side: int = 1024) -> str:
    """Stores the image and returns its public URL."""
    data = await asyncio.to_thread(_process, await read_upload(file), max_side)
    name = f"{folder}/{uuid.uuid4().hex}.webp"
    if settings.STORAGE_BACKEND == "supabase":
        return await _upload_supabase(name, data)
    return await asyncio.to_thread(_write_local, name, data)


def _write_local(name: str, data: bytes) -> str:
    path = Path(settings.LOCAL_MEDIA_DIR) / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return f"{settings.MEDIA_URL_PREFIX}/{name}"


async def _upload_supabase(name: str, data: bytes) -> str:
    base = settings.SUPABASE_URL.rstrip("/")  # type: ignore[union-attr]
    headers = {"Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}", "apikey": settings.SUPABASE_SERVICE_ROLE_KEY or "",
               "Content-Type": "image/webp", "x-upsert": "true"}
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(f"{base}/storage/v1/object/{settings.SUPABASE_STORAGE_BUCKET}/{name}", headers=headers, content=data)
        resp.raise_for_status()
    except httpx.HTTPError as exc:
        raise ServiceUnavailableError("Image storage is temporarily unavailable", code="storage_unavailable") from exc
    return f"{base}/storage/v1/object/public/{settings.SUPABASE_STORAGE_BUCKET}/{name}"
