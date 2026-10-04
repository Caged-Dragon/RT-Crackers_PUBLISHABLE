from decimal import Decimal
from ADMINS.base import Schema
class Dashboard(Schema): total_revenue:Decimal; total_orders:int; pending_orders:int; delivered_orders:int; customers:int; products:int; low_stock_products:int; active_coupons:int
