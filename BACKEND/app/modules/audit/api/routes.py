from fastapi import APIRouter,Depends,Query
from sqlalchemy import text
from ....core.database import get_db
from ....core.security import require_roles,current_user
router=APIRouter(prefix='/audit',tags=['Audit'])
@router.get('')
async def audit(table_name:str|None=None,limit:int=100,user=Depends(require_roles('A','ADMIN')),db=Depends(get_db)):
 q='select * from audit_logs'; params={}
 if table_name:q+=' where table_name=:t'; params['t']=table_name
 q+=' order by created_at desc limit :l'; params['l']=min(limit,500); r=(await db.execute(text(q),params)).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
@router.get('/admin-activity')
async def admin_activity(user=Depends(require_roles('A','ADMIN')),db=Depends(get_db)):
 r=(await db.execute(text('select * from admin_activity_logs order by created_at desc limit 200'))).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
