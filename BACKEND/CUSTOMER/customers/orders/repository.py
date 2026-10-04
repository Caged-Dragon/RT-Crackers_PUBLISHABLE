from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from customers.addresses.models import Address, City, District, PostalCode, State
from customers.coupons.models import Coupon
from customers.orders.models import (
    CodTransaction, Invoice, Order, OrderItem, OrderStatusHistory, OrderTrackingEvent, PaymentMethod, ShippingMethod,
)
from customers.products.models import Product
from customers.products.repository import _PRIMARY_IMAGE
from utils.pagination import PageParams


@dataclass(slots=True)
class AddressRow:
    address: Address
    city: str
    district: str
    state: str
    postal_code: str


class OrderRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # --------------------------------------------------------------- orders
    async def get_for_user(self, user_id: int, ref: str, *, lock: bool = False) -> Order | None:
        """`ref` is the public order number (RTC...) or the numeric order id."""
        stmt = select(Order).where(Order.user_id == user_id, Order.is_deleted.is_(False))
        ref = ref.strip()
        stmt = stmt.where(Order.order_id == int(ref)) if ref.isdigit() else stmt.where(Order.order_number == ref.upper())
        if lock:
            stmt = stmt.with_for_update()
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def page(self, user_id: int, page: PageParams, status: str | None) -> tuple[list[Order], int]:
        base = select(Order).where(Order.user_id == user_id, Order.is_deleted.is_(False))
        if status:
            base = base.where(Order.order_status == status)
        total = int((await self.session.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
        rows = (await self.session.execute(base.order_by(Order.created_at.desc(), Order.order_id.desc())
                                           .limit(page.limit).offset(page.offset))).scalars()
        return list(rows), total

    async def recent(self, user_id: int, limit: int) -> list[Order]:
        stmt = (select(Order).where(Order.user_id == user_id, Order.is_deleted.is_(False))
                .order_by(Order.created_at.desc(), Order.order_id.desc()).limit(limit))
        return list((await self.session.execute(stmt)).scalars())

    async def counts_by_status(self, user_id: int) -> dict[str, int]:
        stmt = (select(Order.order_status, func.count()).where(Order.user_id == user_id, Order.is_deleted.is_(False))
                .group_by(Order.order_status))
        return {s: int(c) for s, c in (await self.session.execute(stmt)).all()}

    async def total_spent(self, user_id: int):
        stmt = select(func.coalesce(func.sum(Order.total_amount), 0)).where(
            Order.user_id == user_id, Order.is_deleted.is_(False), Order.order_status.notin_(("X", "R")))
        return (await self.session.execute(stmt)).scalar_one()

    # ---------------------------------------------------------------- items
    async def items_for(self, order_ids: list[int]) -> dict[int, list[OrderItem]]:
        if not order_ids:
            return {}
        stmt = select(OrderItem).where(OrderItem.order_id.in_(order_ids)).order_by(OrderItem.order_item_id)
        grouped: dict[int, list[OrderItem]] = defaultdict(list)
        for item in (await self.session.execute(stmt)).scalars():
            grouped[item.order_id].append(item)
        return grouped

    async def images(self, product_ids: list[int]) -> dict[int, str | None]:
        if not product_ids:
            return {}
        rows = (await self.session.execute(select(Product.product_id, _PRIMARY_IMAGE.label("image"))
                                           .where(Product.product_id.in_(set(product_ids))))).all()
        return {r.product_id: r.image for r in rows}

    # -------------------------------------------------------------- lookups
    async def address_row(self, address_id: int) -> AddressRow | None:
        """Order addresses are read even after the customer archived them, so past orders keep their address."""
        stmt = (select(Address, City.city_name, District.district_name, State.state_name, PostalCode.postal_code)
                .join(PostalCode, PostalCode.postal_code_id == Address.postal_code_id)
                .join(City, City.city_id == PostalCode.city_id).join(District, District.district_id == City.district_id)
                .join(State, State.state_id == District.state_id).where(Address.address_id == address_id))
        row = (await self.session.execute(stmt)).first()
        return AddressRow(row[0], row[1], row[2], row[3], row[4].strip()) if row else None

    async def method_names(self, order: Order) -> tuple[str, str]:
        pm = await self.session.get(PaymentMethod, order.payment_method_id)
        sm = await self.session.get(ShippingMethod, order.shipping_method_id)
        return (pm.method_name if pm else "Cash On Delivery"), (sm.method_name if sm else "Standard")

    async def coupon_code(self, coupon_id: int | None) -> str | None:
        if coupon_id is None:
            return None
        return (await self.session.execute(select(Coupon.coupon_code).where(Coupon.coupon_id == coupon_id))).scalar_one_or_none()

    async def invoice(self, order_id: int, *, lock: bool = False) -> Invoice | None:
        stmt = select(Invoice).where(Invoice.order_id == order_id)
        if lock:
            stmt = stmt.with_for_update()
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def cod(self, order_id: int, *, lock: bool = False) -> CodTransaction | None:
        stmt = select(CodTransaction).where(CodTransaction.order_id == order_id)
        if lock:
            stmt = stmt.with_for_update()
        return (await self.session.execute(stmt)).scalar_one_or_none()

    # ---------------------------------------------------------------- writes
    async def add(self, obj) -> None:
        self.session.add(obj)
        await self.session.flush()

    async def add_tracking_event(self, order_id: int, status: str, description: str, *, location: str | None = None,
                                 event_time: datetime | None = None) -> OrderTrackingEvent:
        event = OrderTrackingEvent(order_id=order_id, status=status, description=description[:500], location=location)
        if event_time is not None:
            event.event_time = event_time
        self.session.add(event)
        await self.session.flush()
        return event

    # --------------------------------------------------------------- history
    async def tracking_events(self, order_id: int) -> list[OrderTrackingEvent]:
        stmt = select(OrderTrackingEvent).where(OrderTrackingEvent.order_id == order_id).order_by(
            OrderTrackingEvent.event_time, OrderTrackingEvent.tracking_event_id)
        return list((await self.session.execute(stmt)).scalars())

    async def status_history(self, order_id: int) -> list[OrderStatusHistory]:
        stmt = select(OrderStatusHistory).where(OrderStatusHistory.order_id == order_id).order_by(
            OrderStatusHistory.created_at, OrderStatusHistory.history_id)
        return list((await self.session.execute(stmt)).scalars())
