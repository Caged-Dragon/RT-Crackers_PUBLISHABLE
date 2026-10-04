from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import text
from ....core.database import get_db
from ....utils.orm import to_dict
from ....core.security import current_user
from ....database.models import NotificationDelivery
from ..schemas import NotificationSend
from ..services.service import send
router=APIRouter(prefix='/notifications',tags=['Notifications'])
@router.post('/send')
async def send_notification(b:NotificationSend,user=Depends(current_user),db=Depends(get_db)):
 try:return {'success':True,'data':to_dict(await send(db,b))}
 except Exception as e: raise HTTPException(400,str(e))
@router.get('/templates')
async def templates():
 from ..services.service import TEMPLATES; return {'success':True,'data':TEMPLATES}
@router.get('/in-app')
async def in_app(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(text('select un.user_notification_id,n.title,n.message,un.is_read,un.created_at from user_notifications un join notifications n on n.notification_id=un.notification_id where un.user_id=:u order by un.created_at desc limit 100'),{'u':user['user_id']})).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
