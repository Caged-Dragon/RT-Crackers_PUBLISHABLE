from ADMINS.common import GenericRepository
from ADMINS.inventory.models import Inventory
class Repository(GenericRepository[Inventory]):
    model=Inventory
