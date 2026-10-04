"""Seed RTCrackers CMS content from the supplied About Us and Policy documents.

Customer-facing return/refund language is intentionally excluded from the published
terms and CMS navigation per the current storefront requirement.
"""
from alembic import op
import sqlalchemy as sa

revision = "0003_rtcrackers_cms_seed"
down_revision = "0002_admin_rbac_seed"
branch_labels = None
depends_on = None

ABOUT = """<p>Makka &amp; Wheat brand, the leading cracker and fireworks brand of Rajukanna Fireworks, Sivakasi have served millions of people all over India from 1995.</p><p>Buy Like Boss Internet Services is ready to enhance the joy of celebrations through the online web portal rtcrackers.com. The Makka &amp; Wheat brand crackers are now online as rtcrackers.com.</p><p>Ordering crackers is simple: select products, provide quantities, select the payment mode, provide the delivery address and place the order. Orders are delivered by the professional delivery team.</p><p>Wide ranges include Sparklers, Hot Wheels, Ground Wheels, Flower Pots, Rockets, Fancy items, Festival Garlands and combo packs.</p><h3>Mission</h3><p>Lighten up millions of faces through our professional service and quality cracker products in the fireworks industry.</p><h3>Vision</h3><p>Make celebrations more memorable with superior quality rtcrackers.com crackers all over Tamil Nadu.</p>"""

SHIPPING = """<h3>Shipping &amp; Delivery</h3><p>Door-to-door delivery is currently available to Chennai and Kumbakonam. For the rest of Tamil Nadu, crackers are delivered to the nearest transporter warehouse / godown.</p><p>A flat shipping fee of Rs.250 is added for orders in Chennai and Kumbakonam. For the rest of Tamil Nadu, the delivery fee is paid by the customer directly to the transporter while collecting the parcel from the nearest transport office.</p><h3>Delivery Schedule</h3><ul><li>Pre-orders booked by 15-Sep: delivered on or before 15-Oct.</li><li>Orders placed 16-Sep to 15-Oct: delivered on or before 30-Oct.</li><li>Orders placed 16-Oct to 26-Oct: delivered on or before 2-Nov.</li></ul><h3>Delivery Policy</h3><ul><li>Consignment is shipped only to the address confirmed while placing the order.</li><li>Address changes must be informed to customer support within 6 hours of placing the order; otherwise the original delivery address is used.</li><li>Maximum 2 delivery attempts are made.</li></ul><p>For clarification, contact sales@rtcrackers.com.</p>"""

TERMS = """<h2>Buying Terms</h2><ul><li>Minimum order value: Rs. 2000 after discount.</li><li>Flat shipping fee: Rs. 250 for purchase between Rs. 2000 and Rs. 9999.</li><li>Free delivery for order value equal to or more than Rs. 10,000.</li><li>For Chennai and Kumbakonam, a flat shipping fee of Rs. 250 is added for all orders.</li><li>For the rest of Tamil Nadu, delivery charges are paid directly to the transporter at parcel collection.</li><li>Eligible discounts and promotions are applied as displayed on the website and calculated towards the bill amount.</li><li>Orders are processed only after payment realization.</li></ul><h2>Customer Helpline</h2><p>Email: sales@rtcrackers.com</p><p>Phone: 7358737658</p>"""


def upgrade():
    bind = op.get_bind()
    pages = [
        ("about", "About RT Crackers", ABOUT, "P", "RT Crackers — About Us", "Makka & Wheat brand crackers and Rajukanna Fireworks heritage."),
        ("shipping", "Shipping & Delivery", SHIPPING, "P", "RT Crackers — Shipping & Delivery", "Delivery areas, charges and delivery schedule."),
        ("terms-and-conditions", "Buying Terms", TERMS, "P", "RT Crackers — Buying Terms", "Ordering, minimum order and delivery charge terms."),
    ]
    for slug, title, content, status, meta_title, meta_description in pages:
        bind.execute(sa.text("""
            INSERT INTO cms_pages(slug,title,content_html,status,meta_title,meta_description,published_at)
            VALUES (:slug,:title,:content,:status,:meta_title,:meta_description,NOW())
            ON CONFLICT (slug) DO UPDATE SET
              title=EXCLUDED.title,
              content_html=EXCLUDED.content_html,
              status=EXCLUDED.status,
              meta_title=EXCLUDED.meta_title,
              meta_description=EXCLUDED.meta_description,
              published_at=EXCLUDED.published_at,
              updated_at=NOW()
        """), dict(slug=slug,title=title,content=content,status=status,meta_title=meta_title,meta_description=meta_description))
    bind.execute(sa.text("""
        INSERT INTO cms_home_sections(section_key,title,content_json,display_order,is_active)
        VALUES ('hero','RT Crackers Home Banner',CAST(:content AS jsonb),0,true)
        ON CONFLICT (section_key) DO UPDATE SET content_json=EXCLUDED.content_json, title=EXCLUDED.title, is_active=true, updated_at=NOW()
    """), {"content": '{"image_url":"/assets/branding/rtcrackers-home-banner.jpeg","alt":"RT Crackers Red Thunder crackers banner","cta":"Shop Crackers","cta_url":"/shop"}'})


def downgrade():
    bind = op.get_bind()
    bind.execute(sa.text("DELETE FROM cms_home_sections WHERE section_key='hero'"))
    bind.execute(sa.text("DELETE FROM cms_pages WHERE slug IN ('about','shipping','terms-and-conditions')"))
