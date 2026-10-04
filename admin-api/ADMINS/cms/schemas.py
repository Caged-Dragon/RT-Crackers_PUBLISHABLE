from ADMINS.base import Schema
from typing import Any
class Create(Schema): data:dict[str,Any]
class Update(Schema): data:dict[str,Any]
