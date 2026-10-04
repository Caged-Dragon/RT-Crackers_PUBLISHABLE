from sqlalchemy import select,func
from ADMINS.orders.models import Order
from ADMINS.products.models import Product
from ADMINS.customers.models import User
class Service:
 def __init__(self,s,aid):self.s=s
 async def revenue(self):return list((await self.s.execute(select(func.date(Order.created_at).label('date'),func.sum(Order.total_amount).label('revenue'),func.count(Order.order_id).label('orders')).group_by(func.date(Order.created_at)).order_by(func.date(Order.created_at)))).mappings())
 async def orders(self):return list((await self.s.execute(select(Order.order_status,func.count(Order.order_id).label('count')).group_by(Order.order_status))).mappings())
 async def products(self):return list((await self.s.execute(select(Product.product_id,Product.product_name,Product.sales_count,Product.view_count).order_by(Product.sales_count.desc()).limit(100))).mappings())
 async def customers(self):return list((await self.s.execute(select(User.status,func.count(User.user_id).label('count')).group_by(User.status))).mappings())
