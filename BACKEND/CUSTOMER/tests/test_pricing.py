from decimal import Decimal
from utils.pricing import compute_coupon_discount, compute_shipping, q2

def test_coupon_percentage():
    assert compute_coupon_discount(discount_type="P",percentage=Decimal("10"),amount=None,max_discount=None,subtotal=Decimal("1000")) == Decimal("100.00")

def test_shipping_free_threshold():
    assert compute_shipping(base_charge=Decimal("50"),per_kg_charge=Decimal("10"),free_threshold=Decimal("500"),taxable_total=Decimal("600"),total_weight=Decimal("2")) == Decimal("0.00")

def test_q2():
    assert q2(Decimal("1.005")) == Decimal("1.01")
