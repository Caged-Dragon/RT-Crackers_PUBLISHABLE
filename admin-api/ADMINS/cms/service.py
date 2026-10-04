from core.exceptions import NotFoundError
from ADMINS.cms.repository import MODELS
class Service:
 def __init__(self,s,aid):self.s=s;self.aid=aid
 async def list(self,kind):
  M=MODELS[kind];return list((await self.s.execute(__import__('sqlalchemy').select(M).order_by(M.__table__.primary_key.columns.values()[0]))).scalars())
 async def create(self,kind,data):
  M=MODELS[kind];o=M(**data);self.s.add(o);await self.s.commit();return o
 async def update(self,kind,id,data):
  M=MODELS[kind];o=await self.s.get(M,id)
  if not o:raise NotFoundError('CMS record not found')
  for k,v in data.items():
   if hasattr(o,k):setattr(o,k,v)
  await self.s.commit();return o
 async def delete(self,kind,id):
  M=MODELS[kind];o=await self.s.get(M,id)
  if not o:raise NotFoundError('CMS record not found')
  await self.s.delete(o);await self.s.commit()
