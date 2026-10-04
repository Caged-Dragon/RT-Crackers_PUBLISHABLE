from fastapi import APIRouter,Depends,Query
from fastapi.responses import StreamingResponse
from sqlalchemy import text
from ....core.database import get_db
from ....core.security import require_roles
import csv,io
router=APIRouter(prefix='/reports',tags=['Reports'])
@router.get('/sales.csv')
async def sales_csv(db=Depends(get_db),_=Depends(require_roles('A','ADMIN'))):
 rows=(await db.execute(text('select order_number,created_at,subtotal,discount_amount,tax_amount,shipping_amount,total_amount,payment_status,order_status from orders order by created_at desc'))).mappings().all(); s=io.StringIO(); w=csv.DictWriter(s,fieldnames=list(rows[0].keys()) if rows else ['order_number']); w.writeheader(); w.writerows([dict(x) for x in rows]); return StreamingResponse(iter([s.getvalue()]),media_type='text/csv',headers={'Content-Disposition':'attachment; filename=sales.csv'})
@router.get('/inventory.csv')
async def inventory_csv(db=Depends(get_db),_=Depends(require_roles('A','ADMIN'))):
 rows=(await db.execute(text('select i.inventory_id,i.product_id,i.variant_id,i.quantity_on_hand,i.reserved_quantity from inventory i order by i.quantity_on_hand'))).mappings().all(); s=io.StringIO(); w=csv.DictWriter(s,fieldnames=list(rows[0].keys()) if rows else ['inventory_id']); w.writeheader(); w.writerows([dict(x) for x in rows]); return StreamingResponse(iter([s.getvalue()]),media_type='text/csv')
@router.get('/sales.xlsx')
async def sales_xlsx(db=Depends(get_db),_=Depends(require_roles('A','ADMIN'))):
 from openpyxl import Workbook
 from io import BytesIO
 rows=(await db.execute(text('select order_number,created_at,total_amount,payment_status,order_status from orders order by created_at desc'))).mappings().all(); wb=Workbook(); ws=wb.active; ws.append(list(rows[0].keys()) if rows else ['order_number']); [ws.append(list(dict(r).values())) for r in rows]; b=BytesIO(); wb.save(b); b.seek(0); return StreamingResponse(b,media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',headers={'Content-Disposition':'attachment; filename=sales.xlsx'})
@router.get('/sales.pdf')
async def sales_pdf(db=Depends(get_db),_=Depends(require_roles('A','ADMIN'))):
 from reportlab.pdfgen import canvas
 from reportlab.lib.pagesizes import A4
 from io import BytesIO
 rows=(await db.execute(text('select order_number,created_at,total_amount,payment_status,order_status from orders order by created_at desc limit 200'))).mappings().all(); b=BytesIO(); c=canvas.Canvas(b,pagesize=A4); y=800; c.setFont('Helvetica-Bold',14); c.drawString(40,y,'Sales Report'); y-=25; c.setFont('Helvetica',8)
 for r in rows:
  c.drawString(40,y,f"{r['order_number']} | {r['created_at']} | {r['total_amount']} | {r['payment_status']} | {r['order_status']}"); y-=14
  if y<40:c.showPage(); y=800
 c.save(); b.seek(0); return StreamingResponse(b,media_type='application/pdf',headers={'Content-Disposition':'attachment; filename=sales.pdf'})
