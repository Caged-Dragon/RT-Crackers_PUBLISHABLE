from ADMINS.common import GenericRepository
from ADMINS.products.models import Product
class Repository(GenericRepository[Product]):
    model=Product
