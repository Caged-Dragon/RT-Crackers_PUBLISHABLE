import httpx
async def request_json(method,url,**kwargs):
 async with httpx.AsyncClient(timeout=20) as c:
  r=await c.request(method,url,**kwargs); r.raise_for_status(); return r.json()
