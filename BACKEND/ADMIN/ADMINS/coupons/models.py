from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class Coupon(Base,TimestampMixin):
 __tablename__='coupons'; coupon_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); coupon_code:Mapped[str]=mapped_column(String(30),unique=True); description:Mapped[str|None]=mapped_column(String(255)); discount_type:Mapped[str]=mapped_column(CHAR(1)); discount_percentage:Mapped[Decimal|None]=mapped_column(Numeric(5,2)); discount_amount:Mapped[Decimal|None]=mapped_column(Numeric(12,2)); max_discount_amount:Mapped[Decimal|None]=mapped_column(Numeric(12,2)); min_order_amount:Mapped[Decimal]=mapped_column(Numeric(12,2)); usage_limit:Mapped[int|None]=mapped_column(Integer); usage_limit_per_user:Mapped[int]=mapped_column(SmallInteger); valid_from:Mapped[datetime]=mapped_column(DateTime); valid_until:Mapped[datetime]=mapped_column(DateTime); first_order_only:Mapped[bool]=mapped_column(Boolean); is_active:Mapped[bool]=mapped_column(Boolean); created_by:Mapped[int|None]=mapped_column(Integer)
