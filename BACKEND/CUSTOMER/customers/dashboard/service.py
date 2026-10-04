"""Customer dashboard: one call that gathers the account overview (reads only, each piece comes from its own module)."""
from __future__ import annotations

import logging

from fastapi import BackgroundTasks, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import FLAG_REFERRAL, ORDER_CANCELLED, ORDER_DELIVERED, ORDER_RETURNED, ORDER_STATUS_LABELS
from core.database import get_db
from core.system_models import is_feature_enabled
from customers.addresses.service import AddressService
from customers.auth.models import User
from customers.cart.repository import CartRepository
from customers.dashboard.schemas import CartCounts, DashboardOut, DashboardProfile, OrderCounts
from customers.notifications.repository import NotificationRepository
from customers.orders.service import OrderService
from customers.referrals.service import ReferralService
from customers.wishlist.repository import WishlistRepository

logger = logging.getLogger("rtcrackers.dashboard")
RECENT_ORDERS = 5


class DashboardService:
    def __init__(self, session: AsyncSession, background: BackgroundTasks | None = None):
        self.session = session
        self.orders = OrderService(session, background)
        self.addresses = AddressService(session)
        self.referrals = ReferralService(session, background)
        self.wishlist = WishlistRepository(session)
        self.carts = CartRepository(session)
        self.notifications = NotificationRepository(session)

    async def overview(self, user: User) -> DashboardOut:
        counts = await self.orders.repo.counts_by_status(user.user_id)
        total = sum(counts.values())
        delivered, cancelled, returned = counts.get(ORDER_DELIVERED, 0), counts.get(ORDER_CANCELLED, 0), counts.get(ORDER_RETURNED, 0)
        order_counts = OrderCounts(
            total=total, active=total - delivered - cancelled - returned, delivered=delivered, cancelled=cancelled, returned=returned,
            total_spent=await self.orders.repo.total_spent(user.user_id),
            by_status={ORDER_STATUS_LABELS.get(code, code): n for code, n in sorted(counts.items())})
        recent = await self.orders._list_out(await self.orders.repo.recent(user.user_id, RECENT_ORDERS))
        lines, units = await self.carts.user_cart_summary(user.user_id)
        referral = None
        if await is_feature_enabled(self.session, FLAG_REFERRAL, True):
            try:
                referral = await self.referrals.stats(user, sync=False)
            except Exception:  # noqa: BLE001 - a referral hiccup must not take the whole dashboard down
                logger.exception("referral stats unavailable")
        return DashboardOut(
            profile=DashboardProfile(user_id=user.user_id, full_name=user.full_name, email=user.email, email_verified=bool(user.email_verified),
                                     member_since=user.created_at, profile_image=getattr(user, "profile_image", None)),
            orders=order_counts, wishlist_count=await self.wishlist.count_for_user(user.user_id), cart=CartCounts(line_count=lines, item_count=units),
            unread_notifications=await self.notifications.unread_count(user.user_id), recent_orders=recent,
            saved_addresses=await self.addresses.list(user.user_id), referral=referral)


def get_dashboard_service(background: BackgroundTasks, session: AsyncSession = Depends(get_db)) -> DashboardService:
    return DashboardService(session, background)
