from fastapi import APIRouter,Depends,Query
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission,CurrentAdmin
from ADMINS.settings.schemas import Create,Update
from ADMINS.settings.service import Service
router=APIRouter(prefix='/settings',tags=['Admin Settings'])
@router.get('')
async def list_items(page:int=Query(1,ge=1),page_size:int=Query(50,ge=1,le=200),admin=Depends(require_permission('settings.read')),db:AsyncSession=Depends(get_db)):
    items,total=await Service(db,admin.admin_id).list(page,page_size); return {'items':items,'total':total,'page':page,'page_size':page_size,'pages':(total+page_size-1)//page_size}
@router.get('/{id}')
async def get_item(id:int,admin=Depends(require_permission('settings.read')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).get(id)
@router.post('',status_code=201)
async def create(payload:Create,admin=Depends(require_permission('settings.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).create(payload.data)
@router.patch('/{id}')
async def update(id:int,payload:Update,admin=Depends(require_permission('settings.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).update(id,payload.data)
@router.delete('/{id}')
async def delete(id:int,admin=Depends(require_permission('settings.delete')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).delete(id)

@router.get('/system-configurations')
async def system_configurations(admin=Depends(require_permission('settings.read')),db:AsyncSession=Depends(get_db)):
 from sqlalchemy import select
 from ADMINS.settings.models import SystemConfiguration
 return list((await db.execute(select(SystemConfiguration).order_by(SystemConfiguration.config_group,SystemConfiguration.config_key))).scalars())
@router.put('/system-configurations/{id}')
async def update_system_configuration(id:int,config_value:str,is_encrypted:bool|None=None,description:str|None=None,admin=Depends(require_permission('settings.write')),db:AsyncSession=Depends(get_db)):
 from core.exceptions import NotFoundError
 from ADMINS.settings.models import SystemConfiguration
 o=await db.get(SystemConfiguration,id)
 if not o: raise NotFoundError('System configuration not found')
 o.config_value=config_value
 if is_encrypted is not None:o.is_encrypted=is_encrypted
 if description is not None:o.description=description
 await db.commit();return o
