"""Checkout quoting and shipping/payment validation."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date, timedelta
from decimal import Decimal
from fastapi import Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from core.constants import COD_METHOD_CODE, SETTING_COD_ENABLED
from core.database import get_db
from core.exceptions import NotFoundError, UnprocessableError
from core.system_models import get_setting
from customers.addresses.models import Address, DeliveryZone
from customers.addresses.repository import AddressRepository, PostalInfo
from customers.addresses.service import to_address_out
from customers.auth.models import User
from customers.cart.models import Cart
from customers.cart.service import CartService, PricedCart
from customers.checkout.schemas import CheckoutRequest, CheckoutSummary, CheckoutTotals, PaymentOut, ShippingOption, ShippingOptionsOut
from customers.coupons.service import CouponError
from customers.orders.models import PaymentMethod, ShippingMethod, ZoneShippingRate
from utils.helpers import now_ist
from utils.pricing import ZERO, compute_shipping, q2

@dataclass
class Quote:
    cart: Cart | None
    priced: PricedCart
    shipping_address: Address
    shipping_postal: PostalInfo
    billing_address: Address
    billing_postal: PostalInfo
    shipping_method: ShippingMethod
    shipping_option: ShippingOption
    payment_method: PaymentMethod | None
    payment: PaymentOut
    total: Decimal
    warnings: list[str] = field(default_factory=list)
    blocking: list[str] = field(default_factory=list)
    @property
    def shipping_amount(self) -> Decimal: return self.shipping_option.charge if self.shipping_option.available else ZERO
    @property
    def ok(self) -> bool: return not self.blocking

class CheckoutService:
    def __init__(self, session: AsyncSession):
        self.session=session; self.carts=CartService(session); self.addresses=AddressRepository(session)
    async def _shipping_method(self, code: str) -> ShippingMethod:
        method=(await self.session.execute(select(ShippingMethod).where(ShippingMethod.method_code==code))).scalar_one_or_none()
        if method is None or not method.is_active: raise UnprocessableError("This shipping method is not available", code="shipping_method_unavailable")
        return method
    async def _active_methods(self):
        return list((await self.session.execute(select(ShippingMethod).where(ShippingMethod.is_active.is_(True)).order_by(ShippingMethod.min_delivery_days, ShippingMethod.shipping_method_id))).scalars())
    async def _address(self,user_id:int,address_id:int,label:str):
        found=await self.addresses.get_with_postal(address_id,user_id)
        if found is None: raise NotFoundError(f"The {label} address was not found", code="address_not_found")
        return found
    async def _option(self, postal:PostalInfo, method:ShippingMethod, *, taxable_total:Decimal, weight:Decimal)->ShippingOption:
        base=dict(method_code=method.method_code,method_name=method.method_name,description=method.description,min_delivery_days=method.min_delivery_days,max_delivery_days=method.max_delivery_days)
        zone=await self.session.get(DeliveryZone,postal.zone_id)
        rate=(await self.session.execute(select(ZoneShippingRate).where(ZoneShippingRate.zone_id==postal.zone_id,ZoneShippingRate.shipping_method_id==method.shipping_method_id,ZoneShippingRate.is_active.is_(True)))).scalar_one_or_none()
        reason=None
        if not postal.is_serviceable: reason="We do not deliver to this postal code yet"
        elif zone is None or not zone.is_active: reason="Delivery to this area is currently paused"
        elif rate is None: reason=f"{method.method_name} is not available for this area"
        if reason or rate is None or zone is None:
            return ShippingOption(**base,available=False,reason=reason,charge=ZERO,is_free=False,free_shipping_threshold=None,expected_delivery_date=None)
        charge=compute_shipping(base_charge=rate.base_charge,per_kg_charge=rate.per_kg_charge,free_threshold=rate.free_shipping_threshold,taxable_total=taxable_total,total_weight=weight)
        now=now_ist(); start=now.date()+(timedelta(days=1) if now.time()>=zone.order_cutoff_time else timedelta(0))
        return ShippingOption(**base,available=True,reason=None,charge=charge,is_free=charge==ZERO,free_shipping_threshold=rate.free_shipping_threshold,expected_delivery_date=start+timedelta(days=method.max_delivery_days))
    async def _payment(self,code:str,postal:PostalInfo,total:Decimal):
        method=(await self.session.execute(select(PaymentMethod).where(PaymentMethod.method_code==code))).scalar_one_or_none(); name=method.method_name if method else "Cash On Delivery"; reason=None
        if code!=COD_METHOD_CODE or method is None: reason="Only Cash on Delivery is available"
        elif not method.is_active or not bool(await get_setting(self.session,SETTING_COD_ENABLED,True)): reason="Cash on Delivery is currently unavailable"
        elif not postal.cod_available: reason="Cash on Delivery is not available for this postal code"
        elif total<method.min_order_amount: reason=f"Cash on Delivery needs an order total of at least ₹{method.min_order_amount:,.2f}"
        elif method.max_order_amount is not None and total>method.max_order_amount: reason=f"Cash on Delivery is limited to orders up to ₹{method.max_order_amount:,.2f}"
        return method,PaymentOut(method_code=code,method_name=name,available=reason is None,reason=reason,amount_payable_on_delivery=total)
    async def quote(self,user:User,req:CheckoutRequest,*,lock:bool=False)->Quote:
        shipping_addr,shipping_postal=await self._address(user.user_id,req.shipping_address_id,"shipping")
        if req.billing_address_id and req.billing_address_id!=req.shipping_address_id: billing_addr,billing_postal=await self._address(user.user_id,req.billing_address_id,"billing")
        else: billing_addr,billing_postal=shipping_addr,shipping_postal
        method=await self._shipping_method(req.shipping_method); blocking=[]
        try: cart,priced=await self.carts.priced_user_cart(user.user_id,lock=lock,coupon_code=req.coupon_code)
        except CouponError as exc:
            blocking.append(exc.message); cart,priced=await self.carts.priced_user_cart(user.user_id,lock=lock)
        if req.coupon_code and priced.coupon is None and priced.coupon_error: blocking.append(f"Coupon {req.coupon_code}: {priced.coupon_error}")
        pricing=priced.pricing
        if not priced.lines: blocking.append("Your cart is empty")
        else:
            blocking += [f"{l.name}: {l.issue}" for l in priced.lines if not l.purchasable]
            if priced.buy_lines and pricing.subtotal < priced.min_order_amount: blocking.append(f"The minimum order amount is ₹{priced.min_order_amount:,.2f}; add ₹{priced.min_order_amount-pricing.subtotal:,.2f} more")
        taxable=pricing.subtotal-pricing.discount; option=await self._option(shipping_postal,method,taxable_total=taxable,weight=pricing.total_weight)
        if not option.available: blocking.append(option.reason or "Delivery is not available")
        total=q2(pricing.total_before_shipping+(option.charge if option.available else ZERO)); payment_method,payment=await self._payment(req.payment_method,shipping_postal,total)
        if not payment.available: blocking.append(payment.reason or "Payment method unavailable")
        return Quote(cart=cart,priced=priced,shipping_address=shipping_addr,shipping_postal=shipping_postal,billing_address=billing_addr,billing_postal=billing_postal,shipping_method=method,shipping_option=option,payment_method=payment_method,payment=payment,total=total,warnings=list(priced.warnings),blocking=blocking)
    def summary(self,quote:Quote)->CheckoutSummary:
        cart_out=self.carts.to_out(quote.priced,is_guest=False,token=None); p=quote.priced.pricing
        totals=CheckoutTotals(subtotal=p.subtotal,discount=p.discount,tax=p.tax,shipping=quote.shipping_amount,total=quote.total,mrp_savings=p.mrp_savings,item_count=p.item_count)
        return CheckoutSummary(items=cart_out.items,totals=totals,coupon=cart_out.coupon,shipping_address=to_address_out(quote.shipping_address,quote.shipping_postal),billing_address=to_address_out(quote.billing_address,quote.billing_postal),shipping=quote.shipping_option,payment=quote.payment,warnings=quote.warnings,blocking_issues=quote.blocking,can_place_order=quote.ok)
    async def summary_for(self,user:User,req:CheckoutRequest)->CheckoutSummary: return self.summary(await self.quote(user,req))
    async def shipping_options(self,user:User,address_id:int)->ShippingOptionsOut:
        address,postal=await self._address(user.user_id,address_id,"shipping"); _,priced=await self.carts.priced_user_cart(user.user_id); taxable=priced.pricing.subtotal-priced.pricing.discount
        options=[await self._option(postal,m,taxable_total=taxable,weight=priced.pricing.total_weight) for m in await self._active_methods()]
        return ShippingOptionsOut(address_id=address.address_id,postal_code=postal.postal_code,is_serviceable=postal.is_serviceable,cod_available=postal.cod_available,options=options)

def get_checkout_service(session:AsyncSession=Depends(get_db))->CheckoutService: return CheckoutService(session)
