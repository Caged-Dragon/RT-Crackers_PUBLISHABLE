"""Shared Pydantic v2 building blocks."""
from __future__ import annotations

from decimal import Decimal
from typing import Annotated, Generic, TypeVar

from pydantic import BaseModel, ConfigDict, PlainSerializer

# Money is stored as NUMERIC; expose it to JSON clients as a number, not a string.
Money = Annotated[Decimal, PlainSerializer(lambda v: float(v), return_type=float, when_used="json")]

T = TypeVar("T")


class BaseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True, str_strip_whitespace=True)


class MessageResponse(BaseSchema):
    message: str


class Page(BaseSchema, Generic[T]):
    items: list[T]
    total: int
    page: int
    page_size: int
    pages: int
