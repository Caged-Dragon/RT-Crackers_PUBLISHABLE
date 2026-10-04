from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class Newsletter(Base,TimestampMixin):
 __tablename__='newsletters'; newsletter_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); subject:Mapped[str]=mapped_column(String(200)); body_html:Mapped[str]=mapped_column(Text); status:Mapped[str]=mapped_column(CHAR(1)); scheduled_at:Mapped[datetime|None]=mapped_column(DateTime); sent_at:Mapped[datetime|None]=mapped_column(DateTime); created_by:Mapped[int|None]=mapped_column(Integer)
class NewsletterSubscriber(Base,TimestampMixin):
 __tablename__='newsletter_subscribers'; subscriber_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); email:Mapped[str]=mapped_column(String(255),unique=True); user_id:Mapped[int|None]=mapped_column(BigInteger); is_subscribed:Mapped[bool]=mapped_column(Boolean); subscribed_at:Mapped[datetime]=mapped_column(DateTime); unsubscribed_at:Mapped[datetime|None]=mapped_column(DateTime); unsubscribe_token:Mapped[str]=mapped_column(String(64),unique=True)
