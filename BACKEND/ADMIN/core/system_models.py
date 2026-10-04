"""Runtime configuration helpers mapped to the V2/V3 RTCrackers schema."""
from __future__ import annotations

import json
from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import Boolean, DateTime, Identity, Integer, SmallInteger, String, Text, select
from sqlalchemy.dialects.postgresql import CHAR
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin
from utils.helpers import utcnow

class SystemConfiguration(Base, TimestampMixin):
    __tablename__ = "system_configurations"
    config_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    config_group: Mapped[str] = mapped_column(String(40))
    config_key: Mapped[str] = mapped_column(String(80))
    config_value: Mapped[str] = mapped_column(Text)
    is_encrypted: Mapped[bool] = mapped_column(Boolean, server_default="false")
    description: Mapped[str | None] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default="true")
    value_type: Mapped[str] = mapped_column(CHAR(1), server_default="S")
    is_public: Mapped[bool] = mapped_column(Boolean, server_default="false")
    updated_by: Mapped[int | None] = mapped_column(Integer)

class LegacySetting(Base, TimestampMixin):
    __tablename__ = "settings"
    setting_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    setting_key: Mapped[str] = mapped_column(String(80), unique=True)
    setting_value: Mapped[str] = mapped_column(Text)
    value_type: Mapped[str] = mapped_column(CHAR(1), server_default="S")
    description: Mapped[str | None] = mapped_column(String(255))
    is_public: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_by: Mapped[int | None] = mapped_column(Integer)

class FeatureFlag(Base, TimestampMixin):
    __tablename__ = "feature_flags"
    feature_id: Mapped[int] = mapped_column(SmallInteger, Identity(always=True), primary_key=True)
    feature_name: Mapped[str] = mapped_column(String(60), unique=True)
    description: Mapped[str | None] = mapped_column(String(255))
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    rollout_percentage: Mapped[int] = mapped_column(SmallInteger, default=100)
    enabled_from: Mapped[datetime | None] = mapped_column(DateTime)
    enabled_until: Mapped[datetime | None] = mapped_column(DateTime)

def _cast(value: str, value_type: str) -> Any:
    if value_type == "N": return Decimal(value)
    if value_type == "B": return value.strip().lower() in {"true", "1", "yes", "t"}
    if value_type == "J": return json.loads(value)
    return value

async def get_setting(session: AsyncSession, key: str, default: Any = None) -> Any:
    stmt = select(SystemConfiguration.config_value, SystemConfiguration.value_type).where(
        SystemConfiguration.config_key == key, SystemConfiguration.is_active.is_(True))
    row = (await session.execute(stmt)).first()
    if row is None:
        legacy = (await session.execute(select(LegacySetting.setting_value, LegacySetting.value_type).where(LegacySetting.setting_key == key))).first()
        if legacy is None: return default
        try: return _cast(legacy.setting_value, legacy.value_type)
        except (ValueError, ArithmeticError, json.JSONDecodeError): return default
    try: return _cast(row.config_value, row.value_type)
    except (ValueError, ArithmeticError, json.JSONDecodeError): return default

async def is_feature_enabled(session: AsyncSession, key: str, default: bool = False) -> bool:
    flag = (await session.execute(select(FeatureFlag).where(FeatureFlag.feature_name == key))).scalar_one_or_none()
    if flag is None or not flag.is_enabled: return False if flag is not None else default
    now = utcnow()
    if flag.enabled_from and now < flag.enabled_from: return False
    if flag.enabled_until and now > flag.enabled_until: return False
    return True
