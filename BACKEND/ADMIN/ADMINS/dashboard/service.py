from sqlalchemy import select,func
from ADMINS.orders.models import Order
from ADMINS.products.models import Product
from ADMINS.customers.models import User
from ADMINS.coupons.models import Coupon
class Service:
    def __init__(self,s,aid): self.s=s
    async def summary(self):
        rev=(await self.s.execute(select(func.coalesce(func.sum(Order.total_amount),0)).where(Order.order_status.notin_(['X','R'])))).scalar_one()
        orders=(await self.s.execute(select(func.count()).select_from(Order))).scalar_one()
        pending=(await self.s.execute(select(func.count()).select_from(Order).where(Order.order_status.in_(['P','C','K','S','O'])))).scalar_one()
        delivered=(await self.s.execute(select(func.count()).select_from(Order).where(Order.order_status=='D'))).scalar_one()
        customers=(await self.s.execute(select(func.count()).select_from(User).where(User.status!='D'))).scalar_one()
        products=(await self.s.execute(select(func.count()).select_from(Product).where(Product.status!='X'))).scalar_one()
        low=(await self.s.execute(select(func.count()).select_from(Product).where(Product.stock_quantity<=Product.min_stock_level,Product.status=='A'))).scalar_one()
        coupons=(await self.s.execute(select(func.count()).select_from(Coupon).where(Coupon.is_active.is_(True)))).scalar_one()
        return {'total_revenue':rev,'total_orders':orders,'pending_orders':pending,'delivered_orders':delivered,'customers':customers,'products':products,'low_stock_products':low,'active_coupons':coupons}
