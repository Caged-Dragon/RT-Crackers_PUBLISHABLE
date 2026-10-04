"""Pure pricing engine: coupon discount, proportional allocation, GST and shipping.

The schema uses a tax-exclusive model:  total = subtotal - discount + tax + shipping
where tax is computed per line on (unit_price * qty - allocated discount).
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from decimal import ROUND_HALF_UP, Decimal

ZERO = Decimal("0.00")
_CENT = Decimal("0.01")
_HUNDRED = Decimal("100")


def q2(value: Decimal | int | float | str) -> Decimal:
    return Decimal(str(value)).quantize(_CENT, rounding=ROUND_HALF_UP)


@dataclass
class LineInput:
    key: str
    unit_price: Decimal
    mrp: Decimal
    quantity: int
    gst_percentage: Decimal
    weight: Decimal = Decimal("0")


@dataclass
class LinePricing:
    key: str
    unit_price: Decimal
    mrp: Decimal
    quantity: int
    gst_percentage: Decimal
    gross: Decimal
    discount: Decimal
    taxable: Decimal
    tax: Decimal
    total: Decimal
    savings: Decimal


@dataclass
class PricingResult:
    lines: list[LinePricing] = field(default_factory=list)
    subtotal: Decimal = ZERO
    discount: Decimal = ZERO
    tax: Decimal = ZERO
    total_before_shipping: Decimal = ZERO
    mrp_savings: Decimal = ZERO
    total_weight: Decimal = Decimal("0")
    item_count: int = 0


def compute_coupon_discount(*, discount_type: str, percentage: Decimal | None, amount: Decimal | None,
                            max_discount: Decimal | None, subtotal: Decimal) -> Decimal:
    if subtotal <= 0:
        return ZERO
    if discount_type == "P":
        raw = subtotal * (percentage or Decimal(0)) / _HUNDRED
    else:
        raw = amount or Decimal(0)
    if max_discount is not None:
        raw = min(raw, max_discount)
    return q2(min(raw, subtotal))


def allocate_discount(grosses: list[Decimal], discount: Decimal) -> list[Decimal]:
    """Split `discount` across lines proportionally; the last line absorbs rounding; never exceeds a line's gross."""
    total = sum(grosses, ZERO)
    if discount <= 0 or total <= 0:
        return [ZERO for _ in grosses]
    shares: list[Decimal] = []
    allocated = ZERO
    for i, gross in enumerate(grosses):
        share = (discount - allocated) if i == len(grosses) - 1 else q2(discount * gross / total)
        share = max(ZERO, min(share, gross))
        shares.append(share)
        allocated += share
    return shares


def price_lines(lines: list[LineInput], discount: Decimal = ZERO) -> PricingResult:
    grosses = [q2(l.unit_price * l.quantity) for l in lines]
    subtotal = sum(grosses, ZERO)
    discount = min(discount, subtotal)
    shares = allocate_discount(grosses, discount)
    result = PricingResult(subtotal=subtotal, discount=sum(shares, ZERO))
    for line, gross, share in zip(lines, grosses, shares):
        taxable = gross - share
        tax = q2(taxable * line.gst_percentage / _HUNDRED)
        savings = q2((line.mrp - line.unit_price) * line.quantity)
        result.lines.append(LinePricing(line.key, line.unit_price, line.mrp, line.quantity, line.gst_percentage,
                                        gross, share, taxable, tax, taxable + tax, savings))
        result.tax += tax
        result.mrp_savings += savings
        result.total_weight += line.weight * line.quantity
        result.item_count += line.quantity
    result.total_before_shipping = subtotal - result.discount + result.tax
    return result


def compute_shipping(*, base_charge: Decimal, per_kg_charge: Decimal, free_threshold: Decimal | None,
                     taxable_total: Decimal, total_weight: Decimal) -> Decimal:
    """Free above the threshold; otherwise base + per-kg rate for every started kilogram."""
    if free_threshold is not None and taxable_total >= free_threshold:
        return ZERO
    kgs = Decimal(math.ceil(total_weight)) if total_weight > 0 else Decimal(0)
    return q2(base_charge + per_kg_charge * kgs)
