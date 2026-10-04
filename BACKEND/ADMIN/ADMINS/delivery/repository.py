from ADMINS.common import GenericRepository
from ADMINS.delivery.models import DeliveryZone
class Repository(GenericRepository[DeliveryZone]):
    model=DeliveryZone
