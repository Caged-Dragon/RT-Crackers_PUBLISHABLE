from ADMINS.common import GenericRepository
from ADMINS.audit.models import AdminActivityLog
class Repository(GenericRepository[AdminActivityLog]): model=AdminActivityLog
