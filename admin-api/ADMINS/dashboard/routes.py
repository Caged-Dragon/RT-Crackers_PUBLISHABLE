from fastapi import APIRouter,Depends
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission
from ADMINS.dashboard.service import Service
router=APIRouter(prefix='/dashboard',tags=['Admin Dashboard'])
@router.get('')
async def dashboard(admin=Depends(require_permission('DASHBOARD.READ')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).summary()
