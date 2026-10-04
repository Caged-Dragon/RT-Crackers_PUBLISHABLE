from datetime import datetime
import smtplib
from email.message import EmailMessage
from ....core.config import settings
from ....database.models import NotificationDelivery
from ....utils.http import request_json
TEMPLATES={'registration':'Welcome to RT Crackers','login_alert':'New login detected','order_confirmation':'Your order has been confirmed','payment_success':'Payment received successfully','shipping_update':'Your order has shipped','refund_update':'Your refund has been updated','coupon_alert':'A new coupon is available'}
async def send(db,b):
 if b.template not in TEMPLATES: raise ValueError('Unknown template')
 subject=TEMPLATES[b.template]; text=subject+'\n\n'+str(b.data)
 d=NotificationDelivery(user_id=b.user_id,channel=b.channel,destination=b.destination,template=b.template,payload=b.data,status='queued'); db.add(d); await db.flush()
 try:
  if b.channel=='email':
   if settings.EMAIL_BACKEND=='smtp':
    m=EmailMessage(); m['From']=settings.EMAIL_FROM; m['To']=b.destination; m['Subject']=subject; m.set_content(text)
    with smtplib.SMTP(settings.SMTP_HOST,settings.SMTP_PORT,timeout=20) as s:
     if settings.SMTP_USE_TLS:s.starttls()
     if settings.SMTP_USERNAME:s.login(settings.SMTP_USERNAME,settings.SMTP_PASSWORD)
     s.send_message(m)
  elif b.channel=='sms' and settings.SMS_BACKEND=='twilio':
   await request_json('POST',f'https://api.twilio.com/2010-04-01/Accounts/{settings.TWILIO_ACCOUNT_SID}/Messages.json',auth=(settings.TWILIO_ACCOUNT_SID,settings.TWILIO_AUTH_TOKEN),data={'From':settings.TWILIO_FROM_NUMBER,'To':b.destination,'Body':text})
  elif b.channel=='whatsapp' and settings.WHATSAPP_BACKEND=='twilio':
   await request_json('POST',f'https://api.twilio.com/2010-04-01/Accounts/{settings.TWILIO_ACCOUNT_SID}/Messages.json',auth=(settings.TWILIO_ACCOUNT_SID,settings.TWILIO_AUTH_TOKEN),data={'From':settings.WHATSAPP_FROM,'To':f'whatsapp:{b.destination}','Body':text})
  d.status='sent'; d.sent_at=datetime.utcnow()
 except Exception as e: d.status='failed'; d.error=str(e); await db.commit(); raise
 await db.commit(); await db.refresh(d); return d
