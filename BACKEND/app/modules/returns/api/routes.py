from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import select
from ....core.database import get_db
from ....utils.orm import to_dict
from ....core.security import current_user,require_roles
from ....database.models import ReturnRequest
from ..schemas import ReturnCreate,ReturnUpdate
from ..services.service import create_return
router=APIRouter(prefix='/returns',tags=['Returns'])
@router.post('')
async def create(b:ReturnCreate,user=Depends(current_user),db=Depends(get_db)):
 try:return {'success':True,'data':to_dict(await create_return(db,user,b))}
 except Exception as e: raise HTTPException(400,str(e))
@router.get('')
async def list_returns(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(select(ReturnRequest).where(ReturnRequest.user_id==user['user_id']).order_by(ReturnRequest.created_at.desc()))).scalars().all(); return {'success':True,'data':[to_dict(x) for x in r]}
@router.patch('/{return_id}')
async def update(return_id:int,b:ReturnUpdate,user=Depends(require_roles('A','ADMIN')),db=Depends(get_db)):
 r=await db.get(ReturnRequest,return_id)
 if not r: raise HTTPException(404,'Return not found')
 r.status=b.status; r.tracking_number=b.tracking_number or r.tracking_number; r.notes=b.notes or r.notes; await db.commit(); return {'success':True,'data':to_dict(r)}
