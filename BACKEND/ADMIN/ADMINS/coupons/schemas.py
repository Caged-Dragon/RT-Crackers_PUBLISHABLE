from __future__ import annotations
from datetime import datetime,date,time
from decimal import Decimal
from typing import Any
from ADMINS.base import Schema
class Create(Schema): data:dict[str,Any]
class Update(Schema): data:dict[str,Any]
class Out(Schema): id:int; data:dict[str,Any]
