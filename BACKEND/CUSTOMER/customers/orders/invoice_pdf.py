"""Tax-invoice PDF (ReportLab). Pure function: takes plain data, returns bytes."""
from __future__ import annotations

import io
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


@dataclass
class InvoiceLine:
    sku: str
    name: str
    quantity: int
    unit_price: Decimal
    gst_percentage: Decimal
    discount: Decimal
    tax: Decimal
    total: Decimal


@dataclass
class InvoiceParty:
    name: str
    lines: list[str]
    phone: str | None = None


@dataclass
class InvoiceData:
    store_name: str
    store_address: str
    store_gstin: str
    store_phone: str
    store_email: str
    invoice_number: str
    invoice_date: date
    order_number: str
    order_date: datetime
    payment_method: str
    receipt_number: str | None
    billing: InvoiceParty
    shipping: InvoiceParty
    lines: list[InvoiceLine]
    subtotal: Decimal
    discount: Decimal
    tax: Decimal
    shipping_amount: Decimal
    total: Decimal
    coupon_code: str | None = None
    cancelled: bool = False


def _money(value: Decimal) -> str:
    # Helvetica has no rupee glyph, so the invoice uses "Rs."
    return f"Rs. {Decimal(value):,.2f}"


def _esc(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def build_invoice_pdf(data: InvoiceData) -> bytes:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm, topMargin=15 * mm, bottomMargin=15 * mm,
                            title=f"Invoice {data.invoice_number}", author=data.store_name)
    styles = getSampleStyleSheet()
    normal = ParagraphStyle("n", parent=styles["Normal"], fontSize=9, leading=12)
    small = ParagraphStyle("s", parent=normal, fontSize=8, textColor=colors.HexColor("#555555"))
    bold = ParagraphStyle("b", parent=normal, fontName="Helvetica-Bold")
    title = ParagraphStyle("t", parent=styles["Title"], fontSize=18, alignment=0, textColor=colors.HexColor("#c0392b"))
    right = ParagraphStyle("r", parent=normal, alignment=2)
    story: list = []

    head = [[Paragraph(_esc(data.store_name), title), Paragraph("<b>TAX INVOICE</b>" + ("<br/><font color='#c0392b'>CANCELLED</font>" if data.cancelled else ""), right)]]
    story.append(Table(head, colWidths=[110 * mm, 70 * mm], style=[("VALIGN", (0, 0), (-1, -1), "TOP")]))
    store_lines = [data.store_address]
    if data.store_gstin:
        store_lines.append(f"GSTIN: {data.store_gstin}")
    contact = " | ".join(x for x in (data.store_phone, data.store_email) if x)
    if contact:
        store_lines.append(contact)
    story.append(Paragraph(_esc("<br/>".join(store_lines)).replace("&lt;br/&gt;", "<br/>"), small))
    story.append(Spacer(1, 6 * mm))

    meta = [
        [Paragraph(f"<b>Invoice no:</b> {_esc(data.invoice_number)}", normal), Paragraph(f"<b>Order no:</b> {_esc(data.order_number)}", normal)],
        [Paragraph(f"<b>Invoice date:</b> {data.invoice_date:%d %b %Y}", normal), Paragraph(f"<b>Order date:</b> {data.order_date:%d %b %Y}", normal)],
        [Paragraph(f"<b>Payment:</b> {_esc(data.payment_method)}", normal),
         Paragraph(f"<b>Receipt:</b> {_esc(data.receipt_number or '-')}", normal)],
    ]
    story.append(Table(meta, colWidths=[90 * mm, 90 * mm]))
    story.append(Spacer(1, 4 * mm))

    def party(label: str, p: InvoiceParty) -> Paragraph:
        body = "<br/>".join(_esc(x) for x in p.lines)
        phone = f"<br/>Phone: {_esc(p.phone)}" if p.phone else ""
        return Paragraph(f"<b>{label}</b><br/>{_esc(p.name)}<br/>{body}{phone}", normal)

    story.append(Table([[party("Bill to", data.billing), party("Ship to", data.shipping)]], colWidths=[90 * mm, 90 * mm],
                       style=[("VALIGN", (0, 0), (-1, -1), "TOP"), ("BOX", (0, 0), (-1, -1), 0.5, colors.lightgrey),
                              ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.lightgrey), ("PADDING", (0, 0), (-1, -1), 6)]))
    story.append(Spacer(1, 6 * mm))

    rows = [["#", "Item", "Qty", "Rate", "GST %", "Discount", "GST", "Amount"]]
    for i, l in enumerate(data.lines, 1):
        rows.append([str(i), Paragraph(f"{_esc(l.name)}<br/><font size=7 color='#777777'>SKU {_esc(l.sku)}</font>", normal), str(l.quantity),
                     _money(l.unit_price), f"{l.gst_percentage:g}", _money(l.discount), _money(l.tax), _money(l.total)])
    items = Table(rows, colWidths=[8 * mm, 62 * mm, 10 * mm, 24 * mm, 13 * mm, 22 * mm, 20 * mm, 24 * mm], repeatRows=1)
    items.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#c0392b")), ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"), ("FONTSIZE", (0, 0), (-1, -1), 8),
        ("ALIGN", (2, 0), (-1, -1), "RIGHT"), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f7f7f7")]),
        ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.lightgrey)]))
    story.append(items)
    story.append(Spacer(1, 4 * mm))

    totals = [["Subtotal", _money(data.subtotal)]]
    if data.discount:
        totals.append([f"Discount{' (' + data.coupon_code + ')' if data.coupon_code else ''}", "- " + _money(data.discount)])
    totals += [["GST", _money(data.tax)], ["Shipping", _money(data.shipping_amount)], ["Total (payable on delivery)", _money(data.total)]]
    t = Table(totals, colWidths=[60 * mm, 35 * mm], hAlign="RIGHT")
    t.setStyle(TableStyle([("ALIGN", (1, 0), (1, -1), "RIGHT"), ("FONTSIZE", (0, 0), (-1, -1), 9),
                           ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"), ("LINEABOVE", (0, -1), (-1, -1), 0.75, colors.black)]))
    story.append(t)
    story.append(Spacer(1, 8 * mm))
    story.append(Paragraph("This is a computer generated invoice. Amount is payable in cash on delivery.", small))
    doc.build(story)
    return buffer.getvalue()
