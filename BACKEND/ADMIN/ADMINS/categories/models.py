from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class Category(Base,TimestampMixin):
 __tablename__='categories'; category_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); category_name:Mapped[str]=mapped_column(String(100),unique=True); slug:Mapped[str]=mapped_column(String(120),unique=True); description:Mapped[str|None]=mapped_column(Text); image_url:Mapped[str|None]=mapped_column(String(500)); display_order:Mapped[int]=mapped_column(SmallInteger,default=0); is_active:Mapped[bool]=mapped_column(Boolean,default=True)
class Subcategory(Base,TimestampMixin):
 __tablename__='subcategories'; subcategory_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); category_id:Mapped[int]=mapped_column(Integer); subcategory_name:Mapped[str]=mapped_column(String(100)); slug:Mapped[str]=mapped_column(String(120)); description:Mapped[str|None]=mapped_column(Text); image_url:Mapped[str|None]=mapped_column(String(500)); display_order:Mapped[int]=mapped_column(SmallInteger,default=0); is_active:Mapped[bool]=mapped_column(Boolean,default=True)
