from fastapi import APIRouter,Depends,Query
from sqlalchemy import text
from ....core.database import get_db
from ....core.security import current_user
router=APIRouter(prefix='/search-engine',tags=['Search'])
@router.get('')
async def search(q:str=Query(min_length=2,max_length=255),db=Depends(get_db)):
 rows=(await db.execute(text("select product_id,product_name,selling_price from products where is_active=true and (product_name ilike :q or sku ilike :q or description ilike :q) order by case when product_name ilike :exact then 0 else 1 end, product_name limit 50"),{'q':f'%{q}%','exact':f'{q}%'})).mappings().all(); return {'success':True,'data':[dict(x) for x in rows]}
@router.get('/suggestions')
async def suggestions(q:str,db=Depends(get_db)):
 rows=(await db.execute(text('select product_name from products where product_name ilike :q limit 10'),{'q':f'%{q}%'})).scalars().all(); return {'success':True,'data':rows}
@router.post('/log')
async def log(q:str,user=Depends(current_user),db=Depends(get_db)):
 await db.execute(text('insert into search_logs(user_id,search_query,results_count) values(:u,:q,0)'),{'u':user['user_id'],'q':q}); await db.commit(); return {'success':True}
