from sqlalchemy import select,func
from ADMINS.orders.models import Order,OrderItem
from ADMINS.products.models import Product
from ADMINS.inventory.models import Inventory
from ADMINS.customers.models import User
class Service:
 def __init__(self,s,aid):self.s=s
 async def sales(self):return list((await self.s.execute(select(func.date(Order.created_at).label('date'),func.count(Order.order_id).label('orders'),func.sum(Order.total_amount).label('sales')).group_by(func.date(Order.created_at)).order_by(func.date(Order.created_at)))).mappings())
 async def inventory(self):return list((await self.s.execute(select(Inventory.product_id,func.sum(Inventory.quantity_on_hand).label('quantity'),func.sum(Inventory.reserved_quantity).label('reserved')).group_by(Inventory.product_id))).mappings())
 async def tax(self):return list((await self.s.execute(select(func.date(Order.created_at).label('date'),func.sum(Order.tax_amount).label('tax')).group_by(func.date(Order.created_at)).order_by(func.date(Order.created_at)))).mappings())
 async def orders(self):return list((await self.s.execute(select(Order.order_status,func.count(Order.order_id).label('count'),func.sum(Order.total_amount).label('amount')).group_by(Order.order_status))).mappings())
 async def customers(self):return list((await self.s.execute(select(User.status,func.count(User.user_id).label('count')).group_by(User.status))).mappings())
