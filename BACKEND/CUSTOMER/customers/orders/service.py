"""Orders: place (COD), list, detail, cancel, reorder and invoice.

What the database already does, and the service therefore does NOT repeat:
  * order_number / invoice_number / COD receipt numbers come from column defaults,
  * every `order_status` change writes `order_status_history` (trigger),
  * delivery bumps `products.sales_count` (trigger), a collected COD payment marks the order paid (trigger),
  * coupon usage counters (`remaining_uses`) are kept by trigger, stock counters by the inventory-movement trigger.
What the service does: the order rows, `S`/`C` inventory movements, coupon usage, COD/invoice rows and the tracking timeline.
"""
from __future__ import annotations

import logging
from decimal import Decimal

from fastapi import BackgroundTasks, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import settings
from core.constants import (
    CANCELLABLE_STATUSES, CART_CONVERTED, NOTIF_ORDER, ORDER_CANCELLED, ORDER_DELIVERED, ORDER_PLACED, ORDER_STATUS_DISPLAY,
    ORDER_STATUS_LABELS, PAYMENT_STATUS_LABELS,
)
from core.database import get_db, set_audit_user
from core.exceptions import ConflictError, NotFoundError, UnprocessableError
from core.schemas import Page
from customers.auth.models import User
from customers.cart.service import CartService
from customers.checkout.schemas import CheckoutRequest
from customers.checkout.service import CheckoutService
from customers.coupons.service import CouponError, CouponService
from customers.notifications.service import NotificationService
from customers.orders.invoice_pdf import InvoiceData, InvoiceLine, InvoiceParty, build_invoice_pdf
from customers.orders.models import CodTransaction, Invoice, Order, OrderItem
from customers.orders.repository import AddressRow, OrderRepository
from customers.orders.schemas import (
    AddressSnapshotOut, InvoiceOut, OrderDetailOut, OrderItemOut, OrderSummaryOut, ReorderOut,
)
from customers.products.models import InventoryMovement
from customers.products.repository import ProductRepository
from customers.referrals.service import ReferralService
from utils.helpers import utcnow
from utils.pagination import PageParams, paginate
from utils.pricing import q2

logger = logging.getLogger("rtcrackers.orders")


def _snapshot(row: AddressRow) -> AddressSnapshotOut:
    a = row.address
    return AddressSnapshotOut(address_id=a.address_id, recipient_name=a.recipient_name, recipient_phone=a.recipient_phone, house_no=a.house_no,
                              street=a.street, area=a.area, landmark=a.landmark, city=row.city, district=row.district, state=row.state,
                              postal_code=row.postal_code, delivery_instructions=a.delivery_instructions)


class OrderService:
    def __init__(self, session: AsyncSession, background: BackgroundTasks | None = None):
        self.session = session
        self.bg = background
        self.repo = OrderRepository(session)
        self.checkout = CheckoutService(session)
        self.carts = CartService(session)
        self.coupons = CouponService(session)
        self.products = ProductRepository(session)
        self.notifications = NotificationService(session, background)
        self.referrals = ReferralService(session, background)

    # --------------------------------------------------------------- output
    def _summary(self, order: Order, items: list[OrderItem], images: dict[int, str | None]) -> dict:
        names = [i.product_name_snapshot for i in items]
        return dict(
            order_id=order.order_id, order_number=order.order_number, order_status=order.order_status,
            status_label=ORDER_STATUS_LABELS.get(order.order_status, order.order_status),
            status_display=ORDER_STATUS_DISPLAY.get(order.order_status, order.order_status), payment_status=order.payment_status,
            payment_status_label=PAYMENT_STATUS_LABELS.get(order.payment_status, order.payment_status), total_amount=order.total_amount,
            item_count=sum(i.quantity for i in items), items_preview=names[:3], image=images.get(items[0].product_id) if items else None,
            placed_at=order.created_at, expected_delivery_date=order.expected_delivery_date, delivery_date=order.delivery_date,
            can_cancel=order.order_status in CANCELLABLE_STATUSES)

    async def _list_out(self, orders: list[Order]) -> list[OrderSummaryOut]:
        items = await self.repo.items_for([o.order_id for o in orders])
        images = await self.repo.images([i.product_id for rows in items.values() for i in rows[:1]])
        return [OrderSummaryOut(**self._summary(o, items.get(o.order_id, []), images)) for o in orders]

    async def detail_out(self, order: Order) -> OrderDetailOut:
        items = (await self.repo.items_for([order.order_id])).get(order.order_id, [])
        images = await self.repo.images([i.product_id for i in items])
        delivered = order.order_status == ORDER_DELIVERED
        item_out = [OrderItemOut(order_item_id=i.order_item_id, product_id=i.product_id, variant_id=i.variant_id, sku=i.sku_snapshot,
                                 name=i.product_name_snapshot, image=images.get(i.product_id), quantity=i.quantity, mrp=i.mrp,
                                 unit_price=i.unit_price, gst_percentage=i.gst_percentage, discount_amount=i.discount_amount,
                                 tax_amount=i.tax_amount, line_total=i.line_total, can_review=delivered) for i in items]
        shipping = await self.repo.address_row(order.shipping_address_id)
        billing = shipping if order.billing_address_id == order.shipping_address_id else await self.repo.address_row(order.billing_address_id)
        payment_name, shipping_name = await self.repo.method_names(order)
        invoice = await self.repo.invoice(order.order_id)
        cod = await self.repo.cod(order.order_id)
        invoice_out = (InvoiceOut(invoice_number=invoice.invoice_number, invoice_date=invoice.invoice_date, status=invoice.status,
                                  status_label="cancelled" if invoice.status == "C" else "generated",
                                  download_path=f"/api/v1/orders/{order.order_number}/invoice") if invoice else None)
        return OrderDetailOut(
            **self._summary(order, items, images), subtotal=order.subtotal, discount_amount=order.discount_amount, tax_amount=order.tax_amount,
            shipping_amount=order.shipping_amount, coupon_code=await self.repo.coupon_code(order.coupon_id), shipping_method=shipping_name,
            payment_method=payment_name, tracking_number=order.tracking_number, cancellation_reason=order.cancellation_reason, notes=order.notes,
            receipt_number=cod.receipt_number if cod else None, shipping_address=_snapshot(shipping), billing_address=_snapshot(billing),
            items=item_out, invoice=invoice_out, updated_at=order.updated_at)

    async def _require(self, user: User, ref: str, *, lock: bool = False) -> Order:
        order = await self.repo.get_for_user(user.user_id, ref, lock=lock)
        if order is None:
            raise NotFoundError("Order not found", code="order_not_found")
        return order

    # ---------------------------------------------------------------- reads
    async def list(self, user: User, page: PageParams, status: str | None) -> Page[OrderSummaryOut]:
        orders, total = await self.repo.page(user.user_id, page, status)
        return paginate(await self._list_out(orders), total, page)

    async def get(self, user: User, ref: str) -> OrderDetailOut:
        return await self.detail_out(await self._require(user, ref))

    # ---------------------------------------------------------------- place
    async def place(self, user: User, req: CheckoutRequest) -> OrderDetailOut:
        await set_audit_user(self.session, user.user_id)
        is_first_order = not await self.coupons.repo.user_has_prior_orders(user.user_id)
        quote = await self.checkout.quote(user, req, lock=True)  # row-locks the cart: a double click cannot place two orders
        if not quote.ok:
            raise UnprocessableError("Your order cannot be placed yet", code="checkout_invalid", details={"issues": quote.blocking})
        cart, priced, pricing = quote.cart, quote.priced, quote.priced.pricing
        assert cart is not None and priced.buy_lines

        # stock: lock the inventory rows (sorted, deadlock safe) and re-check availability under the lock
        keys = sorted({(l.raw.product_id, l.raw.variant_id) for l in priced.buy_lines}, key=lambda k: (k[0], k[1] or 0))
        inventory = await self.products.lock_inventory(keys)
        shortages: list[str] = []
        for line in priced.buy_lines:
            row = inventory.get((line.raw.product_id, line.raw.variant_id))
            have = row.available if row else 0
            if have < line.raw.quantity:
                shortages.append(f"{line.name}: only {have} left in stock" if have else f"{line.name}: out of stock")
        if shortages:
            raise UnprocessableError("Some items are no longer available in the requested quantity", code="insufficient_stock",
                                     details={"issues": shortages})

        # coupon: re-validate under a row lock so the usage limit holds even when many orders race
        coupon = None
        if priced.coupon is not None:
            coupon = await self.coupons.repo.get(priced.coupon.coupon_id, lock=True)
            if coupon is None:
                raise CouponError("This coupon is no longer available", code="coupon_not_found")
            check = await self.coupons.evaluate_loaded(coupon, user_id=user.user_id, subtotal=pricing.subtotal)
            if q2(check.discount) != q2(pricing.discount):
                raise CouponError("The coupon discount changed, please review your order", code="coupon_changed")

        order = Order(
            user_id=user.user_id, billing_address_id=quote.billing_address.address_id, shipping_address_id=quote.shipping_address.address_id,
            coupon_id=coupon.coupon_id if coupon else None, payment_method_id=quote.payment_method.payment_method_id,
            shipping_method_id=quote.shipping_method.shipping_method_id, subtotal=pricing.subtotal, discount_amount=pricing.discount,
            tax_amount=pricing.tax, shipping_amount=quote.shipping_amount, order_status=ORDER_PLACED,
            expected_delivery_date=quote.shipping_option.expected_delivery_date, notes=req.notes)
        await self.repo.add(order)

        by_key = {lp.key: lp for lp in pricing.lines}
        for line in priced.buy_lines:
            lp = by_key[line.raw.key]
            name = line.name if not line.variant else f"{line.name} - {line.variant.variant_name}"
            sku = line.variant.variant_sku if line.variant else line.product.sku
            self.session.add(OrderItem(
                order_id=order.order_id, product_id=line.raw.product_id, variant_id=line.raw.variant_id, sku_snapshot=sku,
                product_name_snapshot=name[:200], quantity=line.raw.quantity, mrp=lp.mrp, unit_price=lp.unit_price,
                gst_percentage=lp.gst_percentage, discount_amount=lp.discount, tax_amount=lp.tax))
            inv = inventory[(line.raw.product_id, line.raw.variant_id)]
            await self.products.add_movement(InventoryMovement(
                inventory_id=inv.inventory_id, movement_type="S", quantity_change=-line.raw.quantity, reference_type="O",
                reference_id=order.order_id, notes=f"Order {order.order_number}"))
        await self.session.flush()

        if coupon is not None:
            await self.coupons.repo.add_usage(order_id=order.order_id, user_id=user.user_id, coupon_id=coupon.coupon_id, discount=pricing.discount)
        await self.repo.add(CodTransaction(order_id=order.order_id, amount_collected=Decimal("0.00"), status="P"))
        await self.repo.add(Invoice(order_id=order.order_id))
        await self.repo.add_tracking_event(order.order_id, "P", "Your order has been placed")
        await self.carts.repo.set_status(cart, CART_CONVERTED)
        await self.referrals.on_order_placed(user.user_id, order.order_id, is_first_order=is_first_order)

        expected = order.expected_delivery_date.strftime("%d %b %Y") if order.expected_delivery_date else "soon"
        deliveries = await self.notifications.create(
            user, NOTIF_ORDER, f"Order {order.order_number} placed",
            f"Thank you! Your order of \u20b9{order.total_amount:,.2f} is placed. Pay in cash on delivery. Expected by {expected}.",
            reference_type="order", reference_id=order.order_number, email_template="ORDER_PLACED",
            email_context={"order_number": order.order_number, "total": f"{order.total_amount:,.2f}", "expected_delivery": expected},
            sms_text=f"{settings.STORE_NAME}: order {order.order_number} placed, \u20b9{order.total_amount:,.2f} payable on delivery.")
        await self.session.commit()
        self.notifications.schedule(deliveries)

        # Notify the configured admin mailbox(es) that a new order needs confirmation.
        # This is intentionally scheduled after commit so a rolled-back order can never trigger an alert.
        admin_emails = [x.strip() for x in settings.ORDER_ADMIN_EMAILS.split(",") if x.strip()]
        if admin_emails and self.bg is not None:
            from utils.email import safe_send_template_email
            admin_context = {
                "order_number": order.order_number,
                "customer_name": user.full_name,
                "total": f"{order.total_amount:,.2f}",
                "expected_delivery": expected,
            }
            for admin_email in admin_emails:
                self.bg.add_task(safe_send_template_email, admin_email, "ORDER_ADMIN_NEW", admin_context)

        logger.info("order placed", extra={"order_number": order.order_number, "user_id": user.user_id})
        await self.session.refresh(order)
        return await self.detail_out(order)

    # --------------------------------------------------------------- cancel
    async def cancel(self, user: User, ref: str, reason: str) -> OrderDetailOut:
        await set_audit_user(self.session, user.user_id)
        order = await self._require(user, ref, lock=True)
        if order.order_status == ORDER_CANCELLED:
            raise ConflictError("This order is already cancelled", code="order_already_cancelled")
        if order.order_status not in CANCELLABLE_STATUSES:
            raise UnprocessableError(
                f"An order that is {ORDER_STATUS_LABELS.get(order.order_status, 'in progress').replace('_', ' ')} can no longer be cancelled. "
                "Please contact support.", code="order_not_cancellable")
        items = (await self.repo.items_for([order.order_id])).get(order.order_id, [])
        inventory = await self.products.lock_inventory(sorted({(i.product_id, i.variant_id) for i in items}, key=lambda k: (k[0], k[1] or 0)))
        for item in items:  # put the stock back
            inv = inventory.get((item.product_id, item.variant_id))
            if inv is None:
                logger.error("inventory row missing while restocking", extra={"order_id": order.order_id, "product_id": item.product_id})
                continue
            await self.products.add_movement(InventoryMovement(
                inventory_id=inv.inventory_id, movement_type="C", quantity_change=item.quantity, reference_type="O",
                reference_id=order.order_id, notes=f"Cancelled {order.order_number}"))
        order.order_status = ORDER_CANCELLED
        order.cancellation_reason = reason
        await self.session.flush()
        await self.coupons.repo.reverse_usage(order.order_id)
        await self.referrals.on_order_cancelled(order.order_id)
        cod = await self.repo.cod(order.order_id, lock=True)
        if cod is not None and cod.status == "P":
            cod.status = "X"
        invoice = await self.repo.invoice(order.order_id, lock=True)
        if invoice is not None and invoice.status != "C":
            invoice.status, invoice.cancelled_at = "C", utcnow()
        await self.repo.add_tracking_event(order.order_id, "X", f"Order cancelled: {reason}")
        deliveries = await self.notifications.create(
            user, NOTIF_ORDER, f"Order {order.order_number} cancelled", f"Your order {order.order_number} was cancelled. Reason: {reason}",
            reference_type="order", reference_id=order.order_number, email_template="ORDER_CANCELLED",
            email_context={"order_number": order.order_number, "reason": reason})
        await self.session.commit()
        self.notifications.schedule(deliveries)
        await self.session.refresh(order)
        return await self.detail_out(order)

    # -------------------------------------------------------------- reorder
    async def reorder(self, user: User, ref: str) -> ReorderOut:
        order = await self._require(user, ref)
        items = (await self.repo.items_for([order.order_id])).get(order.order_id, [])
        entries = [(i.product_id, i.variant_id, i.quantity, i.product_name_snapshot) for i in items]
        added, skipped = await self.carts.bulk_add(user, entries)
        return ReorderOut(cart=await self.carts.current_out(user), added_lines=added, skipped=skipped)

    # -------------------------------------------------------------- invoice
    async def invoice_pdf(self, user: User, ref: str) -> tuple[str, bytes]:
        order = await self._require(user, ref)
        invoice = await self.repo.invoice(order.order_id)
        if invoice is None:
            raise NotFoundError("No invoice has been generated for this order", code="invoice_not_found")
        items = (await self.repo.items_for([order.order_id])).get(order.order_id, [])
        shipping = await self.repo.address_row(order.shipping_address_id)
        billing = shipping if order.billing_address_id == order.shipping_address_id else await self.repo.address_row(order.billing_address_id)
        payment_name, _ = await self.repo.method_names(order)
        cod = await self.repo.cod(order.order_id)

        def party(row: AddressRow) -> InvoiceParty:
            a = row.address
            lines = [", ".join(x for x in (a.house_no, a.street, a.area) if x)]
            if a.landmark:
                lines.append(f"Near {a.landmark}")
            lines.append(f"{row.city}, {row.district}, {row.state} - {row.postal_code}")
            return InvoiceParty(a.recipient_name, lines, a.recipient_phone)

        data = InvoiceData(
            store_name=settings.STORE_NAME, store_address=settings.STORE_ADDRESS, store_gstin=settings.STORE_GSTIN,
            store_phone=settings.STORE_PHONE, store_email=settings.STORE_EMAIL, invoice_number=invoice.invoice_number,
            invoice_date=invoice.invoice_date, order_number=order.order_number, order_date=order.created_at, payment_method=payment_name,
            receipt_number=cod.receipt_number if cod else None, billing=party(billing), shipping=party(shipping),
            lines=[InvoiceLine(i.sku_snapshot, i.product_name_snapshot, i.quantity, i.unit_price, i.gst_percentage, i.discount_amount,
                               i.tax_amount, i.line_total) for i in items],
            subtotal=order.subtotal, discount=order.discount_amount, tax=order.tax_amount, shipping_amount=order.shipping_amount,
            total=order.total_amount, coupon_code=await self.repo.coupon_code(order.coupon_id), cancelled=invoice.status == "C")
        return f"{invoice.invoice_number}.pdf", build_invoice_pdf(data)


def get_order_service(background: BackgroundTasks, session: AsyncSession = Depends(get_db)) -> OrderService:
    return OrderService(session, background)
