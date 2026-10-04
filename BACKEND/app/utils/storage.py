from pathlib import Path
from uuid import uuid4
import mimetypes,boto3
from ..core.config import settings
class Storage:
 def __init__(self): self.local=Path(settings.LOCAL_STORAGE_DIR); self.local.mkdir(parents=True,exist_ok=True)
 async def put(self,data:bytes,filename:str,content_type:str|None=None):
  key=f'{uuid4().hex}-{Path(filename).name}'
  if settings.STORAGE_BACKEND=='local':
   p=self.local/key; p.write_bytes(data); return f'{settings.STORAGE_PUBLIC_BASE_URL}/{key}',key
  s3=boto3.client('s3',endpoint_url=settings.AWS_S3_ENDPOINT_URL or None,aws_access_key_id=settings.AWS_ACCESS_KEY_ID,aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,region_name=settings.AWS_REGION); s3.put_object(Bucket=settings.AWS_S3_BUCKET,Key=key,Body=data,ContentType=content_type or mimetypes.guess_type(filename)[0] or 'application/octet-stream'); return f'{settings.STORAGE_PUBLIC_BASE_URL}/{key}',key
storage=Storage()
