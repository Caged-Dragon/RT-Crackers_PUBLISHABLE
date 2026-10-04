from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class Role(Base,TimestampMixin):
    __tablename__="roles"
    role_id:Mapped[int]=mapped_column(SmallInteger,Identity(always=True),primary_key=True); role_code:Mapped[str]=mapped_column(String(30),unique=True); role_name:Mapped[str]=mapped_column(String(60),unique=True); role_scope:Mapped[str]=mapped_column(CHAR(1),default='U'); description:Mapped[str|None]=mapped_column(String(255)); is_system:Mapped[bool]=mapped_column(Boolean,default=False); is_active:Mapped[bool]=mapped_column(Boolean,default=True)
class AdminRole(Base):
    __tablename__="admin_roles"
    admin_id:Mapped[int]=mapped_column(Integer,ForeignKey('admins.admin_id'),primary_key=True); role_id:Mapped[int]=mapped_column(SmallInteger,ForeignKey('roles.role_id'),primary_key=True); assigned_by:Mapped[int|None]=mapped_column(Integer); created_at:Mapped[datetime]=mapped_column(DateTime); updated_at:Mapped[datetime]=mapped_column(DateTime)
