import json,logging,sys
from .config import settings
class JsonFormatter(logging.Formatter):
 def format(self,record):
  return json.dumps({'timestamp':self.formatTime(record,'%Y-%m-%dT%H:%M:%S%z'),'level':record.levelname,'logger':record.name,'message':record.getMessage(),'module':record.module})
def configure_logging():
 h=logging.StreamHandler(sys.stdout); h.setFormatter(JsonFormatter() if settings.LOG_JSON else logging.Formatter('%(asctime)s %(levelname)s %(name)s %(message)s')); root=logging.getLogger(); root.handlers.clear(); root.addHandler(h); root.setLevel(settings.LOG_LEVEL)
