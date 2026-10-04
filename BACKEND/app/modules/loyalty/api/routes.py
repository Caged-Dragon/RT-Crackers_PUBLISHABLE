from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import select
from ....core.database import get_db
from ....utils.orm import to_dict
from ....core.security import current_user
from ....database.models import LoyaltyLedger
from ..schemas import RedeemIn,EarnIn
from ..services.service import account,earn,redeem
router=APIRouter(prefix='/loyalty',tags=['Loyalty'])
@router.get('/account')
async def get_account(user=Depends(current_user),db=Depends(get_db)):
 a=await account(db,user['user_id']); await db.commit(); return {'success':True,'data':to_dict(a)}
@router.post('/earn')
async def earn_points(b:EarnIn,user=Depends(current_user),db=Depends(get_db)): return {'success':True,'data':to_dict(await earn(db,user,b))}
@router.post('/redeem')
async def redeem_points(b:RedeemIn,user=Depends(current_user),db=Depends(get_db)):
 try:return {'success':True,'data':to_dict(await redeem(db,user,b.points))}
 except Exception as e: raise HTTPException(400,str(e))
@router.get('/history')
async def history(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(select(LoyaltyLedger).where(LoyaltyLedger.user_id==user['user_id']).order_by(LoyaltyLedger.created_at.desc()))).scalars().all(); return {'success':True,'data':[to_dict(x) for x in r]}
