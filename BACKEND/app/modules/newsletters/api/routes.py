from fastapi import APIRouter,Depends
from sqlalchemy import text
from ....core.database import get_db
from ....core.security import current_user
router=APIRouter(prefix='/newsletters',tags=['Newsletters'])
@router.post('/subscribe')
async def subscribe(user=Depends(current_user),db=Depends(get_db)):
 await db.execute(text('update user_profiles set email_opt_in=true where user_id=:u'),{'u':user['user_id']}); await db.commit(); return {'success':True}
@router.post('/unsubscribe')
async def unsubscribe(user=Depends(current_user),db=Depends(get_db)):
 await db.execute(text('update user_profiles set email_opt_in=false where user_id=:u'),{'u':user['user_id']}); await db.commit(); return {'success':True}
