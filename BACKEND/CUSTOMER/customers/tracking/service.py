"""Order tracking: the delivery journey, timestamps from `order_status_history`, and the notes in `order_tracking_events`."""
from __future__ import annotations

from fastapi import Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import ORDER_CANCELLED, ORDER_DELIVERED, ORDER_FLOW, ORDER_RETURNED, ORDER_STATUS_DISPLAY, ORDER_STATUS_LABELS
from core.database import get_db
from core.exceptions import NotFoundError
from customers.auth.models import User
from customers.orders.models import Order, Shipment
from customers.orders.repository import OrderRepository
from customers.tracking.schemas import ShipmentInfo, TrackingEventOut, TrackingLookup, TrackingOut, TrackingStep

EVENT_LABELS = {
    "P": "Order placed", "C": "Order confirmed", "K": "Packed", "S": "Shipped", "T": "In transit", "O": "Out for delivery",
    "D": "Delivered", "F": "Delivery attempt failed", "X": "Cancelled", "R": "Returned",
}
_TERMINAL = {ORDER_DELIVERED, ORDER_CANCELLED, ORDER_RETURNED}


class TrackingService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = OrderRepository(session)

    async def _build(self, order: Order) -> TrackingOut:
        history = await self.repo.status_history(order.order_id)
        reached: dict[str, object] = {}
        for h in history:  # first time each status was reached
            reached.setdefault(h.new_status, h.created_at)
        flow = list(ORDER_FLOW)
        if order.order_status == ORDER_CANCELLED:
            flow = [s for s in ORDER_FLOW if s in reached] + [ORDER_CANCELLED]
        elif order.order_status == ORDER_RETURNED:
            flow = list(ORDER_FLOW) + [ORDER_RETURNED]
        steps = [TrackingStep(status=s, label=ORDER_STATUS_DISPLAY[s], completed=s in reached, current=s == order.order_status,
                              reached_at=reached.get(s)) for s in flow]  # type: ignore[arg-type]
        events = [TrackingEventOut(status=e.status, label=EVENT_LABELS.get(e.status, e.status), description=e.description,
                                   location=e.location, event_time=e.event_time) for e in reversed(await self.repo.tracking_events(order.order_id))]
        shipment = (await self.session.execute(select(Shipment).where(Shipment.order_id == order.order_id)
                                               .order_by(Shipment.shipment_id.desc()).limit(1))).scalar_one_or_none()
        ship = ShipmentInfo(delivery_partner=shipment.delivery_partner, carrier_awb_number=shipment.carrier_awb_number,
                            shipped_at=shipment.shipped_at, notes=shipment.notes) if shipment else None
        return TrackingOut(
            order_number=order.order_number, order_status=order.order_status, status_label=ORDER_STATUS_LABELS.get(order.order_status, order.order_status),
            status_display=ORDER_STATUS_DISPLAY.get(order.order_status, order.order_status), is_terminal=order.order_status in _TERMINAL,
            tracking_number=order.tracking_number, expected_delivery_date=order.expected_delivery_date, delivery_date=order.delivery_date,
            cancellation_reason=order.cancellation_reason, shipment=ship, steps=steps, events=events)

    async def for_user(self, user: User, ref: str) -> TrackingOut:
        order = await self.repo.get_for_user(user.user_id, ref)
        if order is None:
            raise NotFoundError("Order not found", code="order_not_found")
        return await self._build(order)

    async def lookup(self, data: TrackingLookup) -> TrackingOut:
        """Guest tracking: the order number plus the phone number on the delivery address (generic error on any mismatch)."""
        order = (await self.session.execute(select(Order).where(Order.order_number == data.order_number, Order.is_deleted.is_(False)))).scalar_one_or_none()
        if order is not None:
            row = await self.repo.address_row(order.shipping_address_id)
            owner = await self.session.get(User, order.user_id)
            phones = {row.address.recipient_phone.strip() if row else None, owner.phone.strip() if owner and owner.phone else None}
            if data.phone in phones:
                return await self._build(order)
        raise NotFoundError("No order matches those details", code="order_not_found")


def get_tracking_service(session: AsyncSession = Depends(get_db)) -> TrackingService:
    return TrackingService(session)
