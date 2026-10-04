from fastapi import APIRouter,Depends
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission
from ADMINS.reports.service import Service
router=APIRouter(prefix='/reports',tags=['Admin Reports'])
for name in ['sales','inventory','tax','orders','customers']:
 async def handler(name=name,admin=Depends(require_permission('REPORTS.READ')),db:AsyncSession=Depends(get_db)): return await getattr(Service(db,admin.admin_id),name)()
 router.add_api_route('/'+name,handler,methods=['GET'])
