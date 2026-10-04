from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import text
from ....core.database import get_db
from ....core.security import require_roles
from ..schemas import PageIn,FAQIn
router=APIRouter(prefix='/cms',tags=['CMS'])
@router.get('/pages/{slug}')
async def page(slug:str,db=Depends(get_db)):
 r=(await db.execute(text('select * from cms_pages where slug=:s and status=\'P\''),{'s':slug})).mappings().first()
 if not r: raise HTTPException(404,'Page not found')
 return {'success':True,'data':dict(r)}
@router.get('/home')
async def home(db=Depends(get_db)):
 r=(await db.execute(text('select * from cms_home_sections where is_active=true order by display_order'))).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
@router.get('/faqs')
async def faqs(db=Depends(get_db)):
 r=(await db.execute(text('select * from cms_faqs where is_active=true order by display_order'))).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
@router.get('/menus/{menu_key}')
async def menu(menu_key:str,db=Depends(get_db)):
 r=(await db.execute(text('select i.* from cms_menu_items i join cms_menus m on m.menu_id=i.menu_id where m.menu_key=:k and i.is_active=true order by i.display_order'),{'k':menu_key})).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
@router.get('/policies/{key}')
async def policy(key:str,db=Depends(get_db)):
 r=(await db.execute(text('select * from cms_policies where policy_key=:k and is_active=true'),{'k':key})).mappings().first();
 if not r: raise HTTPException(404,'Policy not found')
 return {'success':True,'data':dict(r)}
@router.post('/pages',dependencies=[Depends(require_roles('A','ADMIN'))])
async def create_page(b:PageIn,db=Depends(get_db)):
 r=(await db.execute(text('insert into cms_pages(slug,title,content_html,status,meta_title,meta_description) values(:s,:t,:c,:st,:mt,:md) returning page_id'),b.model_dump())).scalar_one(); await db.commit(); return {'success':True,'data':{'page_id':r}}
