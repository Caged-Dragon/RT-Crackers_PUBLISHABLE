from decimal import Decimal
from app.modules.tax.api.routes import TaxIn

def test_tax_model():
    body = TaxIn(amount=Decimal('1000'), gst_percentage=Decimal('18'), intra_state=True)
    assert body.amount == 1000
