from fastapi import APIRouter,Depends,Query
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission,CurrentAdmin
from ADMINS.products.schemas import Create,Update
from ADMINS.products.service import Service
router=APIRouter(prefix='/products',tags=['Admin Products'])
@router.get('')
async def list_items(page:int=Query(1,ge=1),page_size:int=Query(50,ge=1,le=200),admin=Depends(require_permission('products.read')),db:AsyncSession=Depends(get_db)):
    items,total=await Service(db,admin.admin_id).list(page,page_size); return {'items':items,'total':total,'page':page,'page_size':page_size,'pages':(total+page_size-1)//page_size}
@router.get('/{id}')
async def get_item(id:int,admin=Depends(require_permission('products.read')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).get(id)
@router.post('',status_code=201)
async def create(payload:Create,admin=Depends(require_permission('products.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).create(payload.data)
@router.patch('/{id}')
async def update(id:int,payload:Update,admin=Depends(require_permission('products.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).update(id,payload.data)
@router.delete('/{id}')
async def delete(id:int,admin=Depends(require_permission('products.delete')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).delete(id)

@router.post('/{id}/archive')
async def archive(id:int,admin=Depends(require_permission('products.write')),db:AsyncSession=Depends(get_db)):
    from ADMINS.products.models import Product
    from core.exceptions import NotFoundError
    o=await db.get(Product,id)
    if not o: raise NotFoundError('Product not found')
    o.status='X'; await db.commit(); return o
@router.post('/{id}/restore')
async def restore(id:int,admin=Depends(require_permission('products.write')),db:AsyncSession=Depends(get_db)):
    from ADMINS.products.models import Product
    from core.exceptions import NotFoundError
    o=await db.get(Product,id)
    if not o: raise NotFoundError('Product not found')
    o.status='A'; await db.commit(); return o
@router.post('/{id}/featured')
async def featured(id:int,enabled:bool=True,admin=Depends(require_permission('products.write')),db:AsyncSession=Depends(get_db)):
    from ADMINS.products.models import Product
    from core.exceptions import NotFoundError
    o=await db.get(Product,id)
    if not o: raise NotFoundError('Product not found')
    o.is_featured=enabled; await db.commit(); return o
@router.post('/{id}/trending')
async def trending(id:int,enabled:bool=True,admin=Depends(require_permission('products.write')),db:AsyncSession=Depends(get_db)):
    from ADMINS.products.models import Product
    from core.exceptions import NotFoundError
    o=await db.get(Product,id)
    if not o: raise NotFoundError('Product not found')
    o.is_trending=enabled; await db.commit(); return o
@router.get('/{id}/images')
async def images(id:int,admin=Depends(require_permission('products.read')),db:AsyncSession=Depends(get_db)):
    from sqlalchemy import select
    from ADMINS.products.models import ProductImage
    return list((await db.execute(select(ProductImage).where(ProductImage.product_id==id).order_by(ProductImage.display_order))).scalars())
@router.get('/{id}/variants')
async def variants(id:int,admin=Depends(require_permission('products.read')),db:AsyncSession=Depends(get_db)):
    from sqlalchemy import select
    from ADMINS.products.models import ProductVariant
    return list((await db.execute(select(ProductVariant).where(ProductVariant.product_id==id).order_by(ProductVariant.variant_id))).scalars())

@router.post('/{id}/images',status_code=201)
async def add_image(id:int,image_url:str,alt_text:str|None=None,is_primary:bool=False,display_order:int=0,admin=Depends(require_permission('products.write')),db:AsyncSession=Depends(get_db)):
    from ADMINS.products.models import Product,ProductImage
    from core.exceptions import NotFoundError
    if not await db.get(Product,id): raise NotFoundError('Product not found')
    if is_primary:
        from sqlalchemy import update
        await db.execute(update(ProductImage).where(ProductImage.product_id==id).values(is_primary=False))
    o=ProductImage(product_id=id,image_url=image_url,alt_text=alt_text,is_primary=is_primary,display_order=display_order);db.add(o);await db.commit();return o
@router.delete('/images/{image_id}')
async def delete_image(image_id:int,admin=Depends(require_permission('products.delete')),db:AsyncSession=Depends(get_db)):
    from ADMINS.products.models import ProductImage
    from core.exceptions import NotFoundError
    o=await db.get(ProductImage,image_id)
    if not o: raise NotFoundError('Product image not found')
    await db.delete(o);await db.commit();return {'message':'Image deleted'}
@router.post('/{id}/variants',status_code=201)
async def add_variant(id:int,variant_sku:str,variant_name:str,mrp:float,selling_price:float,cost_price:float,pack_size:int=1,weight:float=0,is_active:bool=True,admin=Depends(require_permission('products.write')),db:AsyncSession=Depends(get_db)):
    from ADMINS.products.models import Product,ProductVariant
    from core.exceptions import NotFoundError
    if not await db.get(Product,id): raise NotFoundError('Product not found')
    o=ProductVariant(product_id=id,variant_sku=variant_sku,variant_name=variant_name,mrp=mrp,selling_price=selling_price,cost_price=cost_price,pack_size=pack_size,weight=weight,is_active=is_active);db.add(o);await db.commit();return o
