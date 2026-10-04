from sqlalchemy.ext.asyncio import AsyncSession
from ADMINS.inventory.repository import Repository
from ADMINS.audit.service import audit
class Service:
    def __init__(self,session:AsyncSession,admin_id:int): self.session=session; self.admin_id=admin_id; self.repo=Repository(session)
    async def list(self,page:int=1,page_size:int=50):
        items=await self.repo.list((page-1)*page_size,page_size); total=await self.repo.count(); return items,total
    async def get(self,id): return await self.repo.get(id)
    async def create(self,data):
        obj=await self.repo.create(data); await audit(self.session,self.admin_id,'CREATE','inventory',obj.__class__.__tablename__,str(getattr(obj,'inventory_id')),dict(data)); await self.session.commit(); return obj
    async def update(self,id,data):
        obj=await self.repo.update(id,data); await audit(self.session,self.admin_id,'UPDATE','inventory',obj.__class__.__tablename__,str(id),data); await self.session.commit(); return obj
    async def delete(self,id):
        obj=await self.repo.delete(id); await audit(self.session,self.admin_id,'DELETE','inventory',obj.__class__.__tablename__,str(id),None); await self.session.commit(); return obj
