from decimal import Decimal,ROUND_HALF_UP
def money(v): return Decimal(str(v)).quantize(Decimal('0.01'),rounding=ROUND_HALF_UP)
