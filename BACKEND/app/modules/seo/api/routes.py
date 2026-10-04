from fastapi import APIRouter,Depends
from fastapi.responses import Response
from sqlalchemy import select
from ....core.database import get_db
from ....utils.orm import to_dict
from ....core.security import require_roles
from ....database.models import SEORecord
from ..schemas import SEOIn
router=APIRouter(prefix='/seo',tags=['SEO'])
@router.get('/{entity_type}/{entity_id}')
async def get(entity_type:str,entity_id:str,db=Depends(get_db)):
 r=(await db.execute(select(SEORecord).where(SEORecord.entity_type==entity_type,SEORecord.entity_id==entity_id))).scalar_one_or_none(); return {'success':True,'data':to_dict(r) if r else None}
@router.put('',dependencies=[Depends(require_roles('A','ADMIN'))])
async def put(b:SEOIn,db=Depends(get_db)):
 r=(await db.execute(select(SEORecord).where(SEORecord.entity_type==b.entity_type,SEORecord.entity_id==b.entity_id))).scalar_one_or_none()
 if not r:r=SEORecord(**b.model_dump()); db.add(r)
 else:
  for k,v in b.model_dump().items(): setattr(r,k,v)
 await db.commit(); await db.refresh(r); return {'success':True,'data':to_dict(r)}
@router.get('/sitemap.xml',include_in_schema=False)
async def sitemap(db=Depends(get_db)):
 rows=(await db.execute(__import__('sqlalchemy').text('select slug from categories where is_active=true'))).scalars().all(); urls=''.join(f'<url><loc>https://rtcrackers.com/category/{x}</loc></url>' for x in rows); return Response(f'<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">{urls}</urlset>',media_type='application/xml')
@router.get('/robots.txt',include_in_schema=False)
async def robots(): return Response('User-agent: *\nAllow: /\nDisallow: /api/\nSitemap: https://rtcrackers.com/api/v1/seo/sitemap.xml\n',media_type='text/plain')
