"""Pagination dependency and helper."""
from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any, Sequence

from fastapi import Query

from core.schemas import Page


@dataclass
class PageParams:
    page: int = Query(1, ge=1, description="1-based page number")
    page_size: int = Query(20, ge=1, le=100, description="Items per page (max 100)")

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size

    @property
    def limit(self) -> int:
        return self.page_size


def paginate(items: Sequence[Any], total: int, params: PageParams) -> Page:
    return Page(items=list(items), total=total, page=params.page, page_size=params.page_size,
                pages=math.ceil(total / params.page_size) if total else 0)
