from ADMINS.common import GenericRepository
from ADMINS.orders.models import Order
class Repository(GenericRepository[Order]):
    model=Order
