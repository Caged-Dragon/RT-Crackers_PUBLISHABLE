from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class Inventory(Base,TimestampMixin):
 __tablename__='inventory'; inventory_id:Mapped[int]=mapped_column(BigInteger,Identity(always=True),primary_key=True); product_id:Mapped[int]=mapped_column(BigInteger); variant_id:Mapped[int|None]=mapped_column(BigInteger); quantity_on_hand:Mapped[int]=mapped_column(Integer,default=0); reserved_quantity:Mapped[int]=mapped_column(Integer,default=0); rack_location:Mapped[str|None]=mapped_column(String(40)); last_restocked_at:Mapped[datetime|None]=mapped_column(DateTime)
class InventoryMovement(Base):
 __tablename__='inventory_movements'; movement_id:Mapped[int]=mapped_column(BigInteger,Identity(always=True),primary_key=True); inventory_id:Mapped[int]=mapped_column(BigInteger); movement_type:Mapped[str]=mapped_column(CHAR(1)); quantity_change:Mapped[int]=mapped_column(Integer); unit_cost:Mapped[Decimal|None]=mapped_column(Numeric(12,2)); reference_type:Mapped[str|None]=mapped_column(CHAR(1)); reference_id:Mapped[int|None]=mapped_column(BigInteger); notes:Mapped[str|None]=mapped_column(String(255)); performed_by:Mapped[int|None]=mapped_column(Integer); created_at:Mapped[datetime]=mapped_column(DateTime)
