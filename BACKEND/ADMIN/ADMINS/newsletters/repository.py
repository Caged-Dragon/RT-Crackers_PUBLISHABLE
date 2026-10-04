from ADMINS.common import GenericRepository
from ADMINS.newsletters.models import Newsletter
class Repository(GenericRepository[Newsletter]):
    model=Newsletter
