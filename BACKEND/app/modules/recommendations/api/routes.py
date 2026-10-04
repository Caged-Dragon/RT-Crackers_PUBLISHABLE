from fastapi import APIRouter,Depends
from sqlalchemy import text
from ....core.database import get_db
from ....core.security import current_user
router=APIRouter(prefix='/recommendations',tags=['Recommendations'])
@router.get('/trending')
async def trending(db=Depends(get_db)):
 r=(await db.execute(text('select p.product_id,p.product_name,p.selling_price from products p order by coalesce(p.sales_count,0) desc, p.created_at desc limit 20'))).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
@router.get('/recently-viewed')
async def recent(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(text('select p.* from recently_viewed_products rv join products p on p.product_id=rv.product_id where rv.user_id=:u order by rv.last_viewed_at desc limit 20'),{'u':user['user_id']})).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
@router.get('/related/{product_id}')
async def related(product_id:int,db=Depends(get_db)):
 r=(await db.execute(text('select p.* from products p where p.category_id=(select category_id from products where product_id=:p) and p.product_id<>:p order by p.sales_count desc limit 20'),{'p':product_id})).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
