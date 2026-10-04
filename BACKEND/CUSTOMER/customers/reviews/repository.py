from __future__ import annotations

from collections import defaultdict

from sqlalchemy import case, delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import ORDER_DELIVERED, PRODUCT_ACTIVE, REVIEW_APPROVED
from customers.auth.models import User
from customers.categories.models import Category
from customers.orders.models import Order, OrderItem
from customers.products.models import Product
from customers.reviews.models import Review, ReviewImage, ReviewReport
from utils.pagination import PageParams

SORTS = {
    "newest": (Review.created_at.desc(), Review.review_id.desc()),
    "oldest": (Review.created_at.asc(), Review.review_id.asc()),
    "highest": (Review.rating.desc(), Review.created_at.desc()),
    "lowest": (Review.rating.asc(), Review.created_at.desc()),
    "helpful": (Review.helpful_count.desc(), Review.created_at.desc()),
}


class ReviewRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # -------------------------------------------------------------- products
    async def active_product(self, product_id: int) -> Product | None:
        stmt = (select(Product).join(Category, Category.category_id == Product.category_id)
                .where(Product.product_id == product_id, Product.status == PRODUCT_ACTIVE, Product.is_deleted.is_(False),
                       Category.is_deleted.is_(False)))
        return (await self.session.execute(stmt)).scalar_one_or_none()

    # --------------------------------------------------------------- reviews
    async def by_user_product(self, user_id: int, product_id: int, *, lock: bool = False) -> Review | None:
        """Includes soft-deleted rows: (product, user) is unique, so a deleted review is revived instead of duplicated."""
        stmt = select(Review).where(Review.user_id == user_id, Review.product_id == product_id)
        if lock:
            stmt = stmt.with_for_update()
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def get(self, review_id: int, *, lock: bool = False) -> Review | None:
        stmt = select(Review).where(Review.review_id == review_id, Review.is_deleted.is_(False))
        if lock:
            stmt = stmt.with_for_update()
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def purchased_item(self, user_id: int, product_id: int, order_item_id: int | None) -> OrderItem | None:
        """A delivered order line of this user for the product that no other review is attached to yet."""
        taken = select(Review.order_item_id).where(Review.order_item_id.is_not(None))
        stmt = (select(OrderItem).join(Order, Order.order_id == OrderItem.order_id)
                .where(Order.user_id == user_id, Order.is_deleted.is_(False), Order.order_status == ORDER_DELIVERED,
                       OrderItem.product_id == product_id))
        if order_item_id is not None:
            stmt = stmt.where(OrderItem.order_item_id == order_item_id)
        else:
            stmt = stmt.where(OrderItem.order_item_id.not_in(taken))
        return (await self.session.execute(stmt.order_by(OrderItem.order_item_id.desc()).limit(1))).scalar_one_or_none()

    async def order_item_in_use(self, order_item_id: int, except_review_id: int | None = None) -> bool:
        stmt = select(Review.review_id).where(Review.order_item_id == order_item_id)
        if except_review_id is not None:
            stmt = stmt.where(Review.review_id != except_review_id)
        return (await self.session.execute(stmt)).first() is not None

    async def add(self, obj) -> None:
        self.session.add(obj)
        await self.session.flush()

    # ----------------------------------------------------------------- lists
    async def page_for_product(self, product_id: int, page: PageParams, sort: str, rating: int | None, verified_only: bool):
        base = (select(Review, User.first_name, User.last_name).join(User, User.user_id == Review.user_id)
                .where(Review.product_id == product_id, Review.is_deleted.is_(False), Review.status == REVIEW_APPROVED))
        if rating:
            base = base.where(Review.rating == rating)
        if verified_only:
            base = base.where(Review.verified_purchase.is_(True))
        total = int((await self.session.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
        rows = (await self.session.execute(base.order_by(*SORTS[sort]).limit(page.limit).offset(page.offset))).all()
        return rows, total

    async def page_for_user(self, user_id: int, page: PageParams):
        base = (select(Review, User.first_name, User.last_name, Product.product_name, Product.slug)
                .join(User, User.user_id == Review.user_id).join(Product, Product.product_id == Review.product_id)
                .where(Review.user_id == user_id, Review.is_deleted.is_(False)))
        total = int((await self.session.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
        rows = (await self.session.execute(base.order_by(Review.created_at.desc(), Review.review_id.desc())
                                           .limit(page.limit).offset(page.offset))).all()
        return rows, total

    async def images_for(self, review_ids: list[int]) -> dict[int, list[ReviewImage]]:
        if not review_ids:
            return {}
        stmt = select(ReviewImage).where(ReviewImage.review_id.in_(review_ids)).order_by(ReviewImage.display_order, ReviewImage.review_image_id)
        grouped: dict[int, list[ReviewImage]] = defaultdict(list)
        for img in (await self.session.execute(stmt)).scalars():
            grouped[img.review_id].append(img)
        return grouped

    async def distribution(self, product_id: int) -> tuple[dict[int, int], int]:
        stmt = (select(Review.rating, func.count(), func.count(case((Review.verified_purchase.is_(True), 1))))
                .where(Review.product_id == product_id, Review.is_deleted.is_(False), Review.status == REVIEW_APPROVED)
                .group_by(Review.rating))
        counts, verified = {}, 0
        for rating, n, v in (await self.session.execute(stmt)).all():
            counts[int(rating)] = int(n)
            verified += int(v)
        return counts, verified

    # ---------------------------------------------------------------- images
    async def image_count(self, review_id: int) -> int:
        return int((await self.session.execute(select(func.count()).select_from(ReviewImage).where(ReviewImage.review_id == review_id))).scalar_one())

    async def get_image(self, review_id: int, image_id: int) -> ReviewImage | None:
        stmt = select(ReviewImage).where(ReviewImage.review_id == review_id, ReviewImage.review_image_id == image_id)
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def delete_image(self, image: ReviewImage) -> None:
        await self.session.execute(delete(ReviewImage).where(ReviewImage.review_image_id == image.review_image_id))

    # --------------------------------------------------------------- reports
    async def has_reported(self, review_id: int, user_id: int) -> bool:
        stmt = select(ReviewReport.report_id).where(ReviewReport.review_id == review_id, ReviewReport.reported_by == user_id)
        return (await self.session.execute(stmt)).first() is not None
