from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class Banner(Base,TimestampMixin):
 __tablename__='banners'; banner_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); title:Mapped[str]=mapped_column(String(150)); subtitle:Mapped[str|None]=mapped_column(String(255)); image_url:Mapped[str]=mapped_column(String(500)); mobile_image_url:Mapped[str|None]=mapped_column(String(500)); link_url:Mapped[str|None]=mapped_column(String(500)); position:Mapped[str]=mapped_column(CHAR(1)); display_order:Mapped[int]=mapped_column(SmallInteger); start_at:Mapped[datetime|None]=mapped_column(DateTime); end_at:Mapped[datetime|None]=mapped_column(DateTime); is_active:Mapped[bool]=mapped_column(Boolean); created_by:Mapped[int|None]=mapped_column(Integer)
class FestivalBanner(Base,TimestampMixin):
 __tablename__='festival_banners'; festival_banner_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); festival_id:Mapped[int]=mapped_column(Integer); banner_id:Mapped[int]=mapped_column(Integer); display_order:Mapped[int]=mapped_column(SmallInteger); is_active:Mapped[bool]=mapped_column(Boolean)
