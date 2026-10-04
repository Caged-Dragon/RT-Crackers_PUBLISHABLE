import asyncio
from datetime import datetime
from .celery_app import celery_app
from ...core.database import SessionLocal
from ...notifications.schemas import NotificationSend
from ...notifications.services.service import send as send_notification
from sqlalchemy import text

def run(coro): return asyncio.run(coro)
@celery_app.task(name='BACKGROUND_JOBS.tasks.send_email')
def send_email(payload):
 async def job():
  async with SessionLocal() as db: await send_notification(db,NotificationSend(channel='email',**payload))
 run(job()); return {'ok':True}
@celery_app.task(name='BACKGROUND_JOBS.tasks.send_sms')
def send_sms(payload):
 async def job():
  async with SessionLocal() as db: await send_notification(db,NotificationSend(channel='sms',**payload))
 run(job()); return {'ok':True}
@celery_app.task(name='BACKGROUND_JOBS.tasks.send_whatsapp')
def send_whatsapp(payload):
 async def job():
  async with SessionLocal() as db: await send_notification(db,NotificationSend(channel='whatsapp',**payload))
 run(job()); return {'ok':True}
@celery_app.task(name='BACKGROUND_JOBS.tasks.send_newsletter')
def send_newsletter(payload):
 async def job():
  async with SessionLocal() as db:
   users=(await db.execute(text("select u.user_id,u.email from users u join user_profiles p on p.user_id=u.user_id where p.email_opt_in=true and u.status='A'"))).mappings().all()
   for u in users: await send_notification(db,NotificationSend(user_id=u['user_id'],channel='email',destination=u['email'],template=payload['template'],data=payload.get('data',{})))
 run(job()); return {'ok':True}
@celery_app.task(name='BACKGROUND_JOBS.tasks.generate_invoice')
def generate_invoice(order_id):
 from ...invoices.service import generate
 async def job():
  async with SessionLocal() as db: return await generate(db,order_id)
 return run(job())
@celery_app.task(name='BACKGROUND_JOBS.tasks.refresh_analytics')
def refresh_analytics():
 async def job():
  async with SessionLocal() as db:
   return (await db.execute(text("select count(*) orders,coalesce(sum(total_amount),0) revenue from orders where created_at>=current_date"))).mappings().one()
 return dict(run(job()))
@celery_app.task(name='BACKGROUND_JOBS.tasks.process_coupon_expiry')
def process_coupon_expiry():
 async def job():
  async with SessionLocal() as db:
   await db.execute(text("update coupons set is_active=false where valid_until<now() and is_active=true")); await db.commit()
 return run(job())
@celery_app.task(name='BACKGROUND_JOBS.tasks.inventory_alerts')
def inventory_alerts():
 async def job():
  async with SessionLocal() as db:
   return (await db.execute(text('select product_id,stock_quantity,min_stock_level from products where status=\'A\' and stock_quantity<=min_stock_level'))).mappings().all()
 return [dict(x) for x in run(job())]
