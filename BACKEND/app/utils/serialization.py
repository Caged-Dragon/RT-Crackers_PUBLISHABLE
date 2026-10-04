from decimal import Decimal
from datetime import date,datetime
from uuid import UUID
def jsonable(v):
 if isinstance(v,Decimal): return float(v)
 if isinstance(v,(date,datetime)): return v.isoformat()
 if isinstance(v,UUID): return str(v)
 if isinstance(v,dict): return {k:jsonable(x) for k,x in v.items()}
 if isinstance(v,list): return [jsonable(x) for x in v]
 return v
