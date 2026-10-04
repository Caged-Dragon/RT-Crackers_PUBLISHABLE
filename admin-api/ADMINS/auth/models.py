from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class User(Base,TimestampMixin):
    __tablename__="users"
    user_id:Mapped[int]=mapped_column(BigInteger,Identity(always=True),primary_key=True)
    email:Mapped[str]=mapped_column(String(255),unique=True)
    password_hash:Mapped[str]=mapped_column(String(255))
    phone:Mapped[str]=mapped_column(String(10),unique=True)
    first_name:Mapped[str]=mapped_column(String(60)); middle_name:Mapped[str|None]=mapped_column(String(60)); last_name:Mapped[str|None]=mapped_column(String(60))
    status:Mapped[str]=mapped_column(CHAR(1),default='A'); email_verified:Mapped[bool]=mapped_column(Boolean,default=False); phone_verified:Mapped[bool]=mapped_column(Boolean,default=False)
    failed_login_count:Mapped[int]=mapped_column(SmallInteger,default=0); account_locked:Mapped[bool]=mapped_column(Boolean,default=False); last_login:Mapped[datetime|None]=mapped_column(DateTime); last_password_change:Mapped[datetime|None]=mapped_column(DateTime)
class Admin(Base,TimestampMixin):
    __tablename__="admins"
    admin_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); user_id:Mapped[int]=mapped_column(BigInteger,ForeignKey('users.user_id'),unique=True)
    employee_code:Mapped[str]=mapped_column(String(20),unique=True); department:Mapped[str|None]=mapped_column(String(50)); designation:Mapped[str|None]=mapped_column(String(60)); hired_date:Mapped[date|None]=mapped_column(Date); status:Mapped[str]=mapped_column(CHAR(1),default='A'); last_admin_login:Mapped[datetime|None]=mapped_column(DateTime)
class Session(Base):
    __tablename__="sessions"
    session_id:Mapped[UUID]=mapped_column(PGUUID(as_uuid=True),primary_key=True); user_id:Mapped[int]=mapped_column(BigInteger,ForeignKey('users.user_id')); ip_address:Mapped[str|None]=mapped_column(INET); user_agent:Mapped[str|None]=mapped_column(String(500)); device_type:Mapped[str]=mapped_column(CHAR(1),default='W'); last_activity_at:Mapped[datetime|None]=mapped_column(DateTime); expires_at:Mapped[datetime]=mapped_column(DateTime); ended_at:Mapped[datetime|None]=mapped_column(DateTime); created_at:Mapped[datetime]=mapped_column(DateTime); updated_at:Mapped[datetime]=mapped_column(DateTime)
class RefreshToken(Base,TimestampMixin):
    __tablename__="refresh_tokens"
    refresh_token_id:Mapped[int]=mapped_column(BigInteger,Identity(always=True),primary_key=True); user_id:Mapped[int]=mapped_column(BigInteger,ForeignKey('users.user_id')); session_id:Mapped[UUID|None]=mapped_column(PGUUID(as_uuid=True)); token_hash:Mapped[str]=mapped_column(String(255),unique=True); expires_at:Mapped[datetime]=mapped_column(DateTime); revoked_at:Mapped[datetime|None]=mapped_column(DateTime); replaced_by_token_id:Mapped[int|None]=mapped_column(BigInteger)
class PasswordResetToken(Base):
    __tablename__="password_reset_tokens"
    token_id:Mapped[int]=mapped_column(BigInteger,Identity(always=True),primary_key=True); user_id:Mapped[int]=mapped_column(BigInteger,ForeignKey('users.user_id')); token_hash:Mapped[str]=mapped_column(String(255),unique=True); requested_ip:Mapped[str|None]=mapped_column(INET); expires_at:Mapped[datetime]=mapped_column(DateTime); used_at:Mapped[datetime|None]=mapped_column(DateTime); created_at:Mapped[datetime]=mapped_column(DateTime)
