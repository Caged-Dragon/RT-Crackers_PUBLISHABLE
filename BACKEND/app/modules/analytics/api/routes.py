from fastapi import APIRouter,Depends,Query
from sqlalchemy import text
from ....core.database import get_db
from ....core.security import require_roles
router=APIRouter(prefix='/analytics',tags=['Analytics'])
@router.get('/summary')
async def summary(period:str='monthly',db=Depends(get_db),_=Depends(require_roles('A','ADMIN'))):
 interval={'daily':'1 day','weekly':'7 days','monthly':'30 days','yearly':'365 days'}.get(period,'30 days')
 q=(await db.execute(text("select count(*) orders,coalesce(sum(total_amount),0) revenue,coalesce(sum(tax_amount),0) tax from orders where created_at>=now()-cast(:i as interval)"),{'i':interval})).mappings().one(); return {'success':True,'data':dict(q)}
@router.get('/products')
async def products(db=Depends(get_db),_=Depends(require_roles('A','ADMIN'))):
 r=(await db.execute(text('select product_id,product_name,coalesce(sales_count,0) sales_count from products order by coalesce(sales_count,0) desc limit 100'))).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
@router.get('/coupons')
async def coupons(db=Depends(get_db),_=Depends(require_roles('A','ADMIN'))):
 r=(await db.execute(text('select c.coupon_code,count(u.coupon_usage_id) uses,coalesce(sum(u.discount_applied),0) discount from coupons c left join coupon_usage u on u.coupon_id=c.coupon_id group by c.coupon_id order by uses desc'))).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
