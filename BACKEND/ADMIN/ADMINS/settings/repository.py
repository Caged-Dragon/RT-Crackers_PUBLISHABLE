from ADMINS.common import GenericRepository
from ADMINS.settings.models import Setting
class Repository(GenericRepository[Setting]):
    model=Setting
