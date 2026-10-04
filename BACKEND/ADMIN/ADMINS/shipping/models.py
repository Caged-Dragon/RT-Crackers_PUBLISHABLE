from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from uuid import UUID
from sqlalchemy import BigInteger,Integer,SmallInteger,String,Text,Boolean,DateTime,Date,Time,Numeric,ForeignKey,Identity,JSON,CHAR
from sqlalchemy.dialects.postgresql import INET,UUID as PGUUID,JSONB
from sqlalchemy.orm import Mapped,mapped_column
from core.database import Base,TimestampMixin
class ShippingMethod(Base,TimestampMixin):
 __tablename__='shipping_methods'; shipping_method_id:Mapped[int]=mapped_column(SmallInteger,Identity(always=True),primary_key=True); method_code:Mapped[str]=mapped_column(String(10),unique=True); method_name:Mapped[str]=mapped_column(String(60),unique=True); description:Mapped[str|None]=mapped_column(String(255)); min_delivery_days:Mapped[int]=mapped_column(SmallInteger); max_delivery_days:Mapped[int]=mapped_column(SmallInteger); slot_start:Mapped[time|None]=mapped_column(Time); slot_end:Mapped[time|None]=mapped_column(Time); is_active:Mapped[bool]=mapped_column(Boolean)
class DeliveryZone(Base,TimestampMixin):
 __tablename__='delivery_zones'; zone_id:Mapped[int]=mapped_column(SmallInteger,Identity(always=True),primary_key=True); zone_code:Mapped[str]=mapped_column(String(10),unique=True); zone_name:Mapped[str]=mapped_column(String(80),unique=True); description:Mapped[str|None]=mapped_column(String(255)); order_cutoff_time:Mapped[time]=mapped_column(Time); is_active:Mapped[bool]=mapped_column(Boolean)
class Pincode(Base,TimestampMixin):
 __tablename__='pincodes'; pincode:Mapped[str]=mapped_column(String(6),primary_key=True); district:Mapped[str]=mapped_column(String(80)); state:Mapped[str]=mapped_column(String(80)); country_code:Mapped[str]=mapped_column(CHAR(2)); zone_id:Mapped[int]=mapped_column(SmallInteger); is_serviceable:Mapped[bool]=mapped_column(Boolean); cod_available:Mapped[bool]=mapped_column(Boolean)
class ZoneShippingRate(Base,TimestampMixin):
 __tablename__='zone_shipping_rates'; zone_id:Mapped[int]=mapped_column(SmallInteger,primary_key=True); shipping_method_id:Mapped[int]=mapped_column(SmallInteger,primary_key=True); base_charge:Mapped[Decimal]=mapped_column(Numeric(10,2)); per_kg_charge:Mapped[Decimal]=mapped_column(Numeric(10,2)); free_shipping_threshold:Mapped[Decimal|None]=mapped_column(Numeric(12,2)); is_active:Mapped[bool]=mapped_column(Boolean)
class Shipment(Base,TimestampMixin):
 __tablename__='shipments'; shipment_id:Mapped[int]=mapped_column(BigInteger,Identity(always=True),primary_key=True); order_id:Mapped[int]=mapped_column(BigInteger); carrier_awb_number:Mapped[str|None]=mapped_column(String(40)); delivery_partner:Mapped[str|None]=mapped_column(String(80)); delivery_agent_id:Mapped[int|None]=mapped_column(Integer); package_count:Mapped[int]=mapped_column(SmallInteger); package_weight_kg:Mapped[float|None]=mapped_column(); packed_at:Mapped[datetime|None]=mapped_column(DateTime); shipped_at:Mapped[datetime|None]=mapped_column(DateTime); notes:Mapped[str|None]=mapped_column(String(500))
