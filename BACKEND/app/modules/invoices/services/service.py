from io import BytesIO
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from sqlalchemy import text
from ....core.config import settings
from ....utils.storage import storage
async def generate(db,order_id:int):
 o=(await db.execute(text('select o.*,u.first_name,u.last_name,u.email,u.phone from orders o join users u on u.user_id=o.user_id where o.order_id=:id'),{'id':order_id})).mappings().first()
 if not o: raise ValueError('Order not found')
 items=(await db.execute(text('select * from order_items where order_id=:id order by order_item_id'),{'id':order_id})).mappings().all()
 buf=BytesIO(); c=canvas.Canvas(buf,pagesize=A4); y=800; c.setFont('Helvetica-Bold',16); c.drawString(50,y,settings.STORE_NAME+' - GST INVOICE'); y-=30; c.setFont('Helvetica',10); c.drawString(50,y,f"Invoice for Order {o['order_number']}"); y-=18; c.drawString(50,y,f"Customer: {o['first_name']} {o['last_name'] or ''} | GSTIN: {settings.GSTIN or 'N/A'}"); y-=30
 for i in items: c.drawString(50,y,f"{i['product_name_snapshot'][:45]} x {i['quantity']} @ {i['unit_price']} = {i['line_total']}"); y-=18; 
 y-=10; c.drawString(50,y,f"Subtotal: {o['subtotal']} Tax: {o['tax_amount']} Shipping: {o['shipping_amount']} Total: {o['total_amount']}"); c.save(); data=buf.getvalue(); url,key=await storage.put(data,f"invoice-{o['order_number']}.pdf",'application/pdf'); return url
