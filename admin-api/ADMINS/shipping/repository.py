from ADMINS.common import GenericRepository
from ADMINS.shipping.models import ShippingMethod
class Repository(GenericRepository[ShippingMethod]):
    model=ShippingMethod
