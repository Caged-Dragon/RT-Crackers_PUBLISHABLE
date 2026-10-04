from ADMINS.common import GenericRepository
from ADMINS.categories.models import Category
class Repository(GenericRepository[Category]):
    model=Category
