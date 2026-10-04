"""Product reviews.

* A review by someone who received the product (a delivered order line) is a verified purchase and is published
  immediately; any other review waits in the moderation queue (status P) until the shop approves it.
* (product, user) is unique in the schema, so a deleted review is revived rather than duplicated.
* Ratings shown on products (`rating_average`/`rating_count`) are maintained by a database trigger.
"""
from __future__ import annotations

import logging
from decimal import Decimal

from fastapi import Depends, UploadFile
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import MAX_REVIEW_IMAGES, REVIEW_APPROVED, REVIEW_PENDING, REVIEW_STATUS_LABELS
from core.database import get_db, set_audit_user, soft_delete
from core.exceptions import ConflictError, ForbiddenError, NotFoundError, UnprocessableError
from core.schemas import MessageResponse, Page
from customers.auth.models import User
from customers.reviews.models import Review, ReviewImage, ReviewReport
from customers.reviews.repository import SORTS, ReviewRepository
from customers.reviews.schemas import (
    ProductRatingOut, RatingDistribution, ReviewCreate, ReviewImageOut, ReviewOut, ReviewReportRequest, ReviewUpdate,
)
from utils.helpers import mask_name
from utils.pagination import PageParams, paginate
from utils.storage import save_image

logger = logging.getLogger("rtcrackers.reviews")


class ReviewService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = ReviewRepository(session)

    # ---------------------------------------------------------------- output
    @staticmethod
    def _out(review: Review, first: str, last: str | None, images, viewer_id: int | None, product=None) -> ReviewOut:
        return ReviewOut(
            review_id=review.review_id, product_id=review.product_id, rating=review.rating, title=review.title, review_text=review.review_text,
            verified_purchase=bool(review.verified_purchase), helpful_count=review.helpful_count, status=review.status,
            status_label=REVIEW_STATUS_LABELS.get(review.status, review.status), author=mask_name(first, last),
            is_mine=viewer_id is not None and review.user_id == viewer_id,
            images=[ReviewImageOut(review_image_id=i.review_image_id, image_url=i.image_url, display_order=i.display_order) for i in images],
            created_at=review.created_at, updated_at=review.updated_at,
            product_name=product[0] if product else None, product_slug=product[1] if product else None)

    async def _one(self, review: Review, user: User) -> ReviewOut:
        await self.session.refresh(review)
        images = (await self.repo.images_for([review.review_id])).get(review.review_id, [])
        return self._out(review, user.first_name, user.last_name, images, user.user_id)

    async def _owned(self, user: User, review_id: int, *, lock: bool = False) -> Review:
        review = await self.repo.get(review_id, lock=lock)
        if review is None:
            raise NotFoundError("Review not found", code="review_not_found")
        if review.user_id != user.user_id:
            raise ForbiddenError("You can only change your own reviews", code="not_review_owner")
        return review

    # ----------------------------------------------------------------- reads
    async def for_product(self, product_id: int, page: PageParams, sort: str, rating: int | None, verified_only: bool,
                          viewer: User | None) -> Page[ReviewOut]:
        if await self.repo.active_product(product_id) is None:
            raise NotFoundError("Product not found", code="product_not_found")
        rows, total = await self.repo.page_for_product(product_id, page, sort, rating, verified_only)
        images = await self.repo.images_for([r.Review.review_id for r in rows])
        items = [self._out(r.Review, r.first_name, r.last_name, images.get(r.Review.review_id, []), viewer.user_id if viewer else None) for r in rows]
        return paginate(items, total, page)

    async def rating_summary(self, product_id: int) -> ProductRatingOut:
        if await self.repo.active_product(product_id) is None:
            raise NotFoundError("Product not found", code="product_not_found")
        counts, verified = await self.repo.distribution(product_id)
        total = sum(counts.values())
        average = (Decimal(sum(k * v for k, v in counts.items())) / Decimal(total)).quantize(Decimal("0.01")) if total else Decimal("0.00")
        return ProductRatingOut(product_id=product_id, average_rating=average, rating_count=total, verified_count=verified,
                                distribution=RatingDistribution(five=counts.get(5, 0), four=counts.get(4, 0), three=counts.get(3, 0),
                                                                two=counts.get(2, 0), one=counts.get(1, 0)))

    async def mine(self, user: User, page: PageParams) -> Page[ReviewOut]:
        rows, total = await self.repo.page_for_user(user.user_id, page)
        images = await self.repo.images_for([r.Review.review_id for r in rows])
        items = [self._out(r.Review, r.first_name, r.last_name, images.get(r.Review.review_id, []), user.user_id, (r.product_name, r.slug)) for r in rows]
        return paginate(items, total, page)

    # ---------------------------------------------------------------- writes
    async def create(self, user: User, data: ReviewCreate) -> ReviewOut:
        await set_audit_user(self.session, user.user_id)
        if await self.repo.active_product(data.product_id) is None:
            raise NotFoundError("Product not found", code="product_not_found")
        existing = await self.repo.by_user_product(user.user_id, data.product_id, lock=True)
        if existing is not None and not existing.is_deleted:
            raise ConflictError("You have already reviewed this product. Edit your review instead.", code="review_exists")
        purchase = await self.repo.purchased_item(user.user_id, data.product_id, data.order_item_id)
        if data.order_item_id is not None and purchase is None:
            raise UnprocessableError("That order item is not a delivered purchase of this product", code="invalid_order_item")
        if purchase is not None and await self.repo.order_item_in_use(purchase.order_item_id, existing.review_id if existing else None):
            purchase = None
        status = REVIEW_APPROVED if purchase is not None else REVIEW_PENDING
        try:
            if existing is not None:  # revive the soft-deleted row
                existing.is_deleted, existing.deleted_at, existing.deleted_by = False, None, None
                existing.rating, existing.title, existing.review_text = data.rating, data.title, data.review_text
                existing.order_item_id = purchase.order_item_id if purchase else None
                existing.status = status
                review = existing
                await self.session.flush()
            else:
                review = Review(product_id=data.product_id, user_id=user.user_id, rating=data.rating, title=data.title,
                                review_text=data.review_text, order_item_id=purchase.order_item_id if purchase else None, status=status)
                await self.repo.add(review)
            await self.session.commit()
        except IntegrityError as exc:
            await self.session.rollback()
            raise ConflictError("You have already reviewed this product", code="review_exists") from exc
        return await self._one(review, user)

    async def update(self, user: User, review_id: int, data: ReviewUpdate) -> ReviewOut:
        await set_audit_user(self.session, user.user_id)
        review = await self._owned(user, review_id, lock=True)
        if "rating" in data.model_fields_set:
            review.rating = data.rating  # type: ignore[assignment]
        if "title" in data.model_fields_set:
            review.title = data.title
        if "review_text" in data.model_fields_set:
            review.review_text = data.review_text
        # an edited review that was rejected/hidden, or is not a verified purchase, is looked at again
        if review.status != REVIEW_APPROVED or not review.verified_purchase:
            review.status = REVIEW_PENDING
        await self.session.flush()
        await self.session.commit()
        return await self._one(review, user)

    async def delete(self, user: User, review_id: int) -> MessageResponse:
        await set_audit_user(self.session, user.user_id)
        review = await self._owned(user, review_id, lock=True)
        soft_delete(review, user.user_id)
        await self.session.flush()
        await self.session.commit()
        return MessageResponse(message="Your review was deleted")

    # ---------------------------------------------------------------- images
    async def add_image(self, user: User, review_id: int, file: UploadFile) -> ReviewOut:
        review = await self._owned(user, review_id, lock=True)
        count = await self.repo.image_count(review.review_id)
        if count >= MAX_REVIEW_IMAGES:
            raise UnprocessableError(f"A review can have at most {MAX_REVIEW_IMAGES} photos", code="too_many_images")
        url = await save_image(file, f"reviews/{review.review_id}", max_side=1600)
        await self.repo.add(ReviewImage(review_id=review.review_id, image_url=url, display_order=count))
        await self.session.commit()
        return await self._one(review, user)

    async def delete_image(self, user: User, review_id: int, image_id: int) -> ReviewOut:
        review = await self._owned(user, review_id)
        image = await self.repo.get_image(review.review_id, image_id)
        if image is None:
            raise NotFoundError("Photo not found", code="image_not_found")
        await self.repo.delete_image(image)
        await self.session.commit()
        return await self._one(review, user)

    # --------------------------------------------------------------- reports
    async def report(self, user: User, review_id: int, data: ReviewReportRequest) -> MessageResponse:
        review = await self.repo.get(review_id)
        if review is None:
            raise NotFoundError("Review not found", code="review_not_found")
        if review.user_id == user.user_id:
            raise UnprocessableError("You cannot report your own review", code="own_review")
        if await self.repo.has_reported(review_id, user.user_id):
            raise ConflictError("You have already reported this review", code="already_reported")
        try:
            await self.repo.add(ReviewReport(review_id=review_id, reported_by=user.user_id, reason_code=data.reason, description=data.description))
            await self.session.commit()
        except IntegrityError as exc:
            await self.session.rollback()
            raise ConflictError("You have already reported this review", code="already_reported") from exc
        return MessageResponse(message="Thanks, our team will look into this review")


def get_review_service(session: AsyncSession = Depends(get_db)) -> ReviewService:
    return ReviewService(session)
