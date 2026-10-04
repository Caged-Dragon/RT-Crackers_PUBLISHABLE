from __future__ import annotations

from datetime import datetime

from core.schemas import BaseSchema, Money
from customers.addresses.schemas import AddressOut
from customers.orders.schemas import OrderSummaryOut
from customers.referrals.schemas import ReferralStats


class DashboardProfile(BaseSchema):
    user_id: int
    full_name: str
    email: str
    email_verified: bool
    member_since: datetime
    profile_image: str | None = None


class OrderCounts(BaseSchema):
    total: int
    active: int
    delivered: int
    cancelled: int
    returned: int
    total_spent: Money
    by_status: dict[str, int]


class CartCounts(BaseSchema):
    line_count: int
    item_count: int


class DashboardOut(BaseSchema):
    profile: DashboardProfile
    orders: OrderCounts
    wishlist_count: int
    cart: CartCounts
    unread_notifications: int
    recent_orders: list[OrderSummaryOut]
    saved_addresses: list[AddressOut]
    referral: ReferralStats | None = None
