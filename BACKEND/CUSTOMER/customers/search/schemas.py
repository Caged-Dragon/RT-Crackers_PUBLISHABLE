from __future__ import annotations

from core.schemas import BaseSchema, Money
from customers.products.schemas import ProductCard

class FacetOption(BaseSchema):
    id: int
    name: str
    count: int

class SearchFacets(BaseSchema):
    categories: list[FacetOption]
    brands: list[FacetOption]
    price_min: Money | None = None
    price_max: Money | None = None

class SearchResponse(BaseSchema):
    query: str | None = None
    sort: str
    items: list[ProductCard]
    total: int
    page: int
    page_size: int
    pages: int
    facets: SearchFacets

class SuggestedProduct(BaseSchema):
    product_id: int
    name: str
    slug: str
    image: str | None = None
    selling_price: Money

class SuggestedLink(BaseSchema):
    id: int
    name: str
    slug: str

class SuggestionsResponse(BaseSchema):
    query: str
    products: list[SuggestedProduct]
    categories: list[SuggestedLink]
    brands: list[SuggestedLink]
    popular_searches: list[str]
