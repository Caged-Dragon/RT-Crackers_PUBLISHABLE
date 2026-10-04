from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from pydantic import Field, field_validator, model_validator

from core.constants import REVIEW_REPORT_REASONS
from core.schemas import BaseSchema, Money


def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    value = " ".join(value.split()) if "\n" not in value else value.strip()
    return value or None


class ReviewCreate(BaseSchema):
    product_id: int = Field(gt=0)
    rating: int = Field(ge=1, le=5)
    title: str | None = Field(default=None, max_length=150)
    review_text: str | None = Field(default=None, max_length=3000)
    order_item_id: int | None = Field(default=None, gt=0, description="Optional: the purchased order line this review is about (auto-detected otherwise)")

    _title = field_validator("title")(lambda cls, v: _clean(v))
    _text = field_validator("review_text")(lambda cls, v: _clean(v))


class ReviewUpdate(BaseSchema):
    rating: int | None = Field(default=None, ge=1, le=5)
    title: str | None = Field(default=None, max_length=150)
    review_text: str | None = Field(default=None, max_length=3000)

    _title = field_validator("title")(lambda cls, v: _clean(v))
    _text = field_validator("review_text")(lambda cls, v: _clean(v))

    @model_validator(mode="after")
    def _something(self):
        if not self.model_fields_set:
            raise ValueError("Nothing to update")
        if "rating" in self.model_fields_set and self.rating is None:
            raise ValueError("rating cannot be empty")
        return self


class ReviewImageOut(BaseSchema):
    review_image_id: int
    image_url: str
    display_order: int


class ReviewOut(BaseSchema):
    review_id: int
    product_id: int
    rating: int
    title: str | None = None
    review_text: str | None = None
    verified_purchase: bool
    helpful_count: int
    status: str
    status_label: str
    author: str
    is_mine: bool = False
    images: list[ReviewImageOut] = []
    created_at: datetime
    updated_at: datetime
    product_name: str | None = None
    product_slug: str | None = None


class RatingDistribution(BaseSchema):
    five: int = 0
    four: int = 0
    three: int = 0
    two: int = 0
    one: int = 0


class ProductRatingOut(BaseSchema):
    product_id: int
    average_rating: Money = Decimal("0.00")
    rating_count: int = 0
    verified_count: int = 0
    distribution: RatingDistribution


class ReviewReportRequest(BaseSchema):
    reason: str = Field(description="spam, abusive, fake, irrelevant or other (a single-letter code S/A/F/I/O also works)")
    description: str | None = Field(default=None, max_length=500)

    @field_validator("reason")
    @classmethod
    def _reason(cls, v: str) -> str:
        v = v.strip()
        by_name = {name: code for code, name in REVIEW_REPORT_REASONS.items()}
        if v.lower() in by_name:
            return by_name[v.lower()]
        if v.upper() in REVIEW_REPORT_REASONS:
            return v.upper()
        raise ValueError(f"reason must be one of: {', '.join(REVIEW_REPORT_REASONS.values())}")
