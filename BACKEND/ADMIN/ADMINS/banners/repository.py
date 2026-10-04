from ADMINS.common import GenericRepository
from ADMINS.banners.models import Banner
class Repository(GenericRepository[Banner]):
    model=Banner
