from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class Permission(Base,TimestampMixin):
    __tablename__="permissions"
    permission_id:Mapped[int]=mapped_column(SmallInteger,Identity(always=True),primary_key=True); permission_code:Mapped[str]=mapped_column(String(60),unique=True); module_name:Mapped[str]=mapped_column(String(40)); description:Mapped[str|None]=mapped_column(String(255))
class RolePermission(Base):
    __tablename__="role_permissions"
    role_id:Mapped[int]=mapped_column(SmallInteger,ForeignKey('roles.role_id'),primary_key=True); permission_id:Mapped[int]=mapped_column(SmallInteger,ForeignKey('permissions.permission_id'),primary_key=True); created_at:Mapped[datetime]=mapped_column(DateTime)
class AdminPermission(Base):
    __tablename__="admin_permissions"
    admin_id:Mapped[int]=mapped_column(Integer,ForeignKey('admins.admin_id'),primary_key=True); permission_id:Mapped[int]=mapped_column(SmallInteger,ForeignKey('permissions.permission_id'),primary_key=True); is_granted:Mapped[bool]=mapped_column(Boolean,default=True); granted_by:Mapped[int|None]=mapped_column(Integer); created_at:Mapped[datetime]=mapped_column(DateTime); updated_at:Mapped[datetime]=mapped_column(DateTime)
