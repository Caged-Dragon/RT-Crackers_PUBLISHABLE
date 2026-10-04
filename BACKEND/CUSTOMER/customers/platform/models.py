from __future__ import annotations
from datetime import datetime
from sqlalchemy import BigInteger, Boolean, DateTime, Identity, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from core.database import Base, TimestampMixin

class SiteRelease(Base, TimestampMixin):
    __tablename__ = "site_releases"
    release_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    version: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(160))
    message: Mapped[str] = mapped_column(Text, default="")
    snapshot: Mapped[dict] = mapped_column(JSON, default=dict)
    status: Mapped[str] = mapped_column(String(20), default="DRAFT", index=True)
    created_by: Mapped[int | None] = mapped_column(Integer)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime)
    published_at: Mapped[datetime | None] = mapped_column(DateTime)
    verification_error: Mapped[str | None] = mapped_column(Text)
    is_current: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

class SiteContentRevision(Base, TimestampMixin):
    __tablename__ = "site_content_revisions"
    revision_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    content_key: Mapped[str] = mapped_column(String(180), index=True)
    page_path: Mapped[str] = mapped_column(String(240), default="/")
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    status: Mapped[str] = mapped_column(String(20), default="DRAFT", index=True)
    release_id: Mapped[int | None] = mapped_column(BigInteger)
    edited_by: Mapped[int | None] = mapped_column(Integer)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime)
    published_at: Mapped[datetime | None] = mapped_column(DateTime)
    verification_error: Mapped[str | None] = mapped_column(Text)
