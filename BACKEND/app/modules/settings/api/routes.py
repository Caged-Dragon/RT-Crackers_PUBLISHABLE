from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import text
from ....core.database import get_db
from ....core.security import require_roles
from ..schemas import SettingIn
router=APIRouter(prefix='/settings',tags=['Settings'])
@router.get('/public')
async def public(db=Depends(get_db)):
 r=(await db.execute(text('select setting_key,setting_value,value_type,description from settings where is_public=true order by setting_key'))).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
@router.get('/{key}')
async def get(key:str,db=Depends(get_db)):
 r=(await db.execute(text('select * from settings where setting_key=:k'),{'k':key})).mappings().first();
 if not r: raise HTTPException(404,'Setting not found')
 return {'success':True,'data':dict(r)}
@router.put('/{key}',dependencies=[Depends(require_roles('A','ADMIN'))])
async def put(key:str,b:SettingIn,db=Depends(get_db)):
 await db.execute(text('insert into settings(setting_key,setting_value,value_type,description,is_public) values(:k,:v,:t,:d,:p) on conflict(setting_key) do update set setting_value=excluded.setting_value,value_type=excluded.value_type,description=excluded.description,is_public=excluded.is_public'),{'k':key,'v':b.value,'t':b.value_type,'d':b.description,'p':b.is_public}); await db.commit(); return {'success':True}
