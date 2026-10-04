from ADMINS.common import GenericRepository
from ADMINS.customers.models import User
class Repository(GenericRepository[User]):
    model=User
