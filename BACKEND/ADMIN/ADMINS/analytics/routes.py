from fastapi import APIRouter,Depends
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission
from ADMINS.analytics.service import Service
router=APIRouter(prefix='/analytics',tags=['Admin Analytics'])
@router.get('/revenue')
async def revenue(admin=Depends(require_permission('ANALYTICS.READ')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).revenue()
@router.get('/orders')
async def orders(admin=Depends(require_permission('ANALYTICS.READ')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).orders()
@router.get('/products')
async def products(admin=Depends(require_permission('ANALYTICS.READ')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).products()
@router.get('/customers')
async def customers(admin=Depends(require_permission('ANALYTICS.READ')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).customers()
