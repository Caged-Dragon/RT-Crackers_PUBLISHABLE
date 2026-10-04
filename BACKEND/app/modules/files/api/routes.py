from fastapi import APIRouter,UploadFile,File,Depends,HTTPException
from sqlalchemy import select
from ....core.database import get_db
from ....utils.orm import to_dict
from ....core.security import current_user,require_roles
from ....database.models import FileObject
from ....utils.storage import storage
router=APIRouter(prefix='/files',tags=['Files'])
@router.post('/upload')
async def upload(file:UploadFile=File(...),purpose:str='document',user=Depends(current_user),db=Depends(get_db)):
 data=await file.read();
 if len(data)>20*1024*1024: raise HTTPException(413,'File too large')
 url,key=await storage.put(data,file.filename or 'upload',file.content_type); o=FileObject(object_key=key,original_name=file.filename or key,content_type=file.content_type or 'application/octet-stream',size_bytes=len(data),url=url,owner_user_id=user['user_id'],purpose=purpose); db.add(o); await db.commit(); await db.refresh(o); return {'success':True,'data':to_dict(o)}
@router.get('')
async def list_files(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(select(FileObject).where(FileObject.owner_user_id==user['user_id']).order_by(FileObject.created_at.desc()))).scalars().all(); return {'success':True,'data':[to_dict(x) for x in r]}
