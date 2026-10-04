from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class AdminActivityLog(Base):
 __tablename__='admin_activity_logs'; log_id:Mapped[int]=mapped_column(BigInteger,Identity(always=True),primary_key=True); admin_id:Mapped[int]=mapped_column(Integer); action:Mapped[str]=mapped_column(String(100)); module_name:Mapped[str|None]=mapped_column(String(40)); entity_type:Mapped[str|None]=mapped_column(String(40)); entity_id:Mapped[str|None]=mapped_column(String(64)); details:Mapped[dict|None]=mapped_column(JSONB); ip_address:Mapped[str|None]=mapped_column(INET); user_agent:Mapped[str|None]=mapped_column(String(500)); created_at:Mapped[datetime]=mapped_column(DateTime)
class LoginHistory(Base):
 __tablename__='login_history'; login_id:Mapped[int]=mapped_column(BigInteger,Identity(always=True),primary_key=True); user_id:Mapped[int|None]=mapped_column(BigInteger); attempted_email:Mapped[str]=mapped_column(String(255)); login_status:Mapped[str]=mapped_column(CHAR(1)); failure_reason:Mapped[str|None]=mapped_column(String(100)); ip_address:Mapped[str|None]=mapped_column(INET); user_agent:Mapped[str|None]=mapped_column(String(500)); session_id:Mapped[UUID|None]=mapped_column(PGUUID(as_uuid=True)); created_at:Mapped[datetime]=mapped_column(DateTime)
class AuditLog(Base):
 __tablename__='audit_logs'; audit_log_id:Mapped[int]=mapped_column(BigInteger,Identity(always=True),primary_key=True); table_name:Mapped[str]=mapped_column(String(63)); record_id:Mapped[str]=mapped_column(String(64)); action:Mapped[str]=mapped_column(CHAR(1)); old_data:Mapped[dict|None]=mapped_column(JSONB); new_data:Mapped[dict|None]=mapped_column(JSONB); changed_by:Mapped[int|None]=mapped_column(BigInteger); created_at:Mapped[datetime]=mapped_column(DateTime)
