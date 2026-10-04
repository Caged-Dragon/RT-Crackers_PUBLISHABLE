from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, File, Path, Query, UploadFile, status

from core.schemas import MessageResponse, Page
from customers.auth.dependencies import CurrentUser, OptionalUser
from customers.reviews.repository import SORTS
from customers.reviews.schemas import ProductRatingOut, ReviewCreate, ReviewOut, ReviewReportRequest, ReviewUpdate
from customers.reviews.service import ReviewService, get_review_service
from utils.pagination import PageParams

router = APIRouter(prefix="/reviews", tags=["Reviews"])
Service = Annotated[ReviewService, Depends(get_review_service)]
ReviewId = Annotated[int, Path(gt=0)]
SortParam = Annotated[str, Query(pattern="^(" + "|".join(SORTS) + ")$", description="newest, oldest, highest, lowest or helpful")]


@router.post("", response_model=ReviewOut, status_code=status.HTTP_201_CREATED, summary="Add a review (verified when you bought the product)")
async def add_review(body: ReviewCreate, user: CurrentUser, service: Service) -> ReviewOut:
    return await service.create(user, body)


@router.get("/mine", response_model=Page[ReviewOut], summary="My reviews")
async def my_reviews(user: CurrentUser, service: Service, page: Annotated[PageParams, Depends()]) -> Page[ReviewOut]:
    return await service.mine(user, page)


@router.get("/product/{product_id}", response_model=Page[ReviewOut], summary="Published reviews of a product")
async def product_reviews(product_id: Annotated[int, Path(gt=0)], service: Service, page: Annotated[PageParams, Depends()], viewer: OptionalUser,
                          sort: SortParam = "newest", rating: Annotated[int | None, Query(ge=1, le=5)] = None,
                          verified_only: bool = False) -> Page[ReviewOut]:
    return await service.for_product(product_id, page, sort, rating, verified_only, viewer)


@router.get("/product/{product_id}/rating", response_model=ProductRatingOut, summary="Average rating and star distribution of a product")
async def product_rating(product_id: Annotated[int, Path(gt=0)], service: Service) -> ProductRatingOut:
    return await service.rating_summary(product_id)


@router.patch("/{review_id}", response_model=ReviewOut, summary="Edit my review")
async def edit_review(review_id: ReviewId, body: ReviewUpdate, user: CurrentUser, service: Service) -> ReviewOut:
    return await service.update(user, review_id, body)


@router.delete("/{review_id}", response_model=MessageResponse, summary="Delete my review")
async def delete_review(review_id: ReviewId, user: CurrentUser, service: Service) -> MessageResponse:
    return await service.delete(user, review_id)


@router.post("/{review_id}/images", response_model=ReviewOut, status_code=status.HTTP_201_CREATED, summary="Attach a photo (JPEG/PNG/WebP)")
async def add_image(review_id: ReviewId, user: CurrentUser, service: Service, file: UploadFile = File(...)) -> ReviewOut:
    return await service.add_image(user, review_id, file)


@router.delete("/{review_id}/images/{image_id}", response_model=ReviewOut, summary="Remove one of my review photos")
async def remove_image(review_id: ReviewId, image_id: Annotated[int, Path(gt=0)], user: CurrentUser, service: Service) -> ReviewOut:
    return await service.delete_image(user, review_id, image_id)


@router.post("/{review_id}/report", response_model=MessageResponse, summary="Report a review")
async def report_review(review_id: ReviewId, body: ReviewReportRequest, user: CurrentUser, service: Service) -> MessageResponse:
    return await service.report(user, review_id, body)
