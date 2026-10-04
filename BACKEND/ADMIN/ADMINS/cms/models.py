from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class CMSPage(Base,TimestampMixin):
 __tablename__='cms_pages'; page_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); slug:Mapped[str]=mapped_column(String(160),unique=True); title:Mapped[str]=mapped_column(String(200)); content_html:Mapped[str]=mapped_column(Text); status:Mapped[str]=mapped_column(CHAR(1),default='D'); meta_title:Mapped[str|None]=mapped_column(String(160)); meta_description:Mapped[str|None]=mapped_column(String(320)); published_at:Mapped[datetime|None]=mapped_column(DateTime); updated_by:Mapped[int|None]=mapped_column(Integer)
class CMSHomeSection(Base,TimestampMixin):
 __tablename__='cms_home_sections'; section_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); section_key:Mapped[str]=mapped_column(String(80),unique=True); title:Mapped[str]=mapped_column(String(150)); content_json:Mapped[dict]=mapped_column(JSONB); display_order:Mapped[int]=mapped_column(SmallInteger,default=0); is_active:Mapped[bool]=mapped_column(Boolean,default=True); updated_by:Mapped[int|None]=mapped_column(Integer)
class CMSMenu(Base,TimestampMixin):
 __tablename__='cms_menus'; menu_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); menu_key:Mapped[str]=mapped_column(String(60),unique=True); menu_name:Mapped[str]=mapped_column(String(100)); is_active:Mapped[bool]=mapped_column(Boolean,default=True)
class CMSMenuItem(Base,TimestampMixin):
 __tablename__='cms_menu_items'; item_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); menu_id:Mapped[int]=mapped_column(Integer); parent_item_id:Mapped[int|None]=mapped_column(Integer); label:Mapped[str]=mapped_column(String(100)); url:Mapped[str]=mapped_column(String(500)); display_order:Mapped[int]=mapped_column(SmallInteger,default=0); is_active:Mapped[bool]=mapped_column(Boolean,default=True)
class CMSFooterLink(Base,TimestampMixin):
 __tablename__='cms_footer_links'; link_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); group_name:Mapped[str]=mapped_column(String(80)); label:Mapped[str]=mapped_column(String(100)); url:Mapped[str]=mapped_column(String(500)); display_order:Mapped[int]=mapped_column(SmallInteger,default=0); is_active:Mapped[bool]=mapped_column(Boolean,default=True)
class CMSFAQ(Base,TimestampMixin):
 __tablename__='cms_faqs'; faq_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); question:Mapped[str]=mapped_column(String(500)); answer_html:Mapped[str]=mapped_column(Text); display_order:Mapped[int]=mapped_column(SmallInteger,default=0); is_active:Mapped[bool]=mapped_column(Boolean,default=True)
class CMSPolicy(Base,TimestampMixin):
 __tablename__='cms_policies'; policy_id:Mapped[int]=mapped_column(Integer,Identity(always=True),primary_key=True); policy_key:Mapped[str]=mapped_column(String(60),unique=True); title:Mapped[str]=mapped_column(String(150)); content_html:Mapped[str]=mapped_column(Text); is_active:Mapped[bool]=mapped_column(Boolean,default=True); updated_by:Mapped[int|None]=mapped_column(Integer)
