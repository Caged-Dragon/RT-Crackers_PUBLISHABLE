from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class Setting(Base,TimestampMixin):
 __tablename__='settings'; setting_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); setting_key:Mapped[str]=mapped_column(String(80),unique=True); setting_value:Mapped[str]=mapped_column(Text); value_type:Mapped[str]=mapped_column(CHAR(1)); description:Mapped[str|None]=mapped_column(String(255)); is_public:Mapped[bool]=mapped_column(Boolean); updated_by:Mapped[int|None]=mapped_column(Integer)
class SystemConfiguration(Base,TimestampMixin):
 __tablename__='system_configurations'; config_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); config_group:Mapped[str]=mapped_column(String(40)); config_key:Mapped[str]=mapped_column(String(80)); config_value:Mapped[str]=mapped_column(Text); is_encrypted:Mapped[bool]=mapped_column(Boolean); description:Mapped[str|None]=mapped_column(String(255))
