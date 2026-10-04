from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import text
from ....core.database import get_db
from ....core.security import current_user
router=APIRouter(prefix='/referrals',tags=['Referrals'])
@router.get('/me')
async def me(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(text('select referral_code from users where user_id=:u'),{'u':user['user_id']})).scalar_one(); return {'success':True,'data':{'referral_code':r}}
@router.get('/rewards')
async def rewards(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(text('select * from referral_rewards where referred_user_id=:u order by created_at desc'),{'u':user['user_id']})).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
@router.get('/summary')
async def summary(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(text("select count(*) referrals,coalesce(sum(reward_amount),0) rewards from referral_rewards where referred_user_id=:u"),{'u':user['user_id']})).mappings().one(); return {'success':True,'data':dict(r)}
