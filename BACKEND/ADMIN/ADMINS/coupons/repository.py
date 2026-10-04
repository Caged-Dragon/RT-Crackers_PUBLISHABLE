from ADMINS.common import GenericRepository
from ADMINS.coupons.models import Coupon
class Repository(GenericRepository[Coupon]):
    model=Coupon
