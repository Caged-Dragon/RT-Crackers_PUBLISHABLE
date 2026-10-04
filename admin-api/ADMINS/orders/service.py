from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import BackgroundTasks
from ADMINS.orders.repository import Repository
from ADMINS.orders.models import Order, OrderStatusHistory
from ADMINS.audit.service import audit
from core.config import settings

class Service:
    def __init__(self, session: AsyncSession, admin_id: int, background: BackgroundTasks | None = None):
        self.session=session; self.admin_id=admin_id; self.repo=Repository(session); self.background=background

    async def list(self,page:int=1,page_size:int=50):
        items=await self.repo.list((page-1)*page_size,page_size); total=await self.repo.count(); return items,total

    async def get(self,id): return await self.repo.get(id)

    async def create(self,data):
        obj=await self.repo.create(data); await audit(self.session,self.admin_id,'CREATE','orders',obj.__class__.__tablename__,str(getattr(obj,'order_id')),dict(data)); await self.session.commit(); return obj

    async def update(self,id,data):
        obj=await self.repo.update(id,data); await audit(self.session,self.admin_id,'UPDATE','orders',obj.__class__.__tablename__,str(id),data); await self.session.commit(); return obj

    async def delete(self,id):
        obj=await self.repo.delete(id); await audit(self.session,self.admin_id,'DELETE','orders',obj.__class__.__tablename__,str(id),None); await self.session.commit(); return obj


    async def set_status(self, id: int, status: str, remarks: str | None = None):
        from datetime import datetime, date
        from core.exceptions import ConflictError, NotFoundError, UnprocessableError
        from ADMINS.inventory.models import Inventory, InventoryMovement
        allowed = {'P','C','K','S','O','D','X','R'}
        if status not in allowed:
            raise UnprocessableError('Invalid order status')
        order = await self.session.get(Order, id, with_for_update=True)
        if order is None:
            raise NotFoundError('Order not found')
        if order.order_status == status:
            raise ConflictError('Order already has this status')
        old = order.order_status
        if status == 'X':
            if old in {'D','X'}:
                raise ConflictError('This order cannot be cancelled')
            items = list((await self.session.execute(select(__import__('ADMINS.orders.models', fromlist=['OrderItem']).OrderItem).where(__import__('ADMINS.orders.models', fromlist=['OrderItem']).OrderItem.order_id == id))).scalars())
            keys = sorted({(i.product_id, i.variant_id) for i in items}, key=lambda x:(x[0], x[1] or 0))
            inv_rows = (await self.session.execute(select(Inventory).where(*[Inventory.product_id.in_([k[0] for k in keys])]))) if keys else None
            # Lock and index exact inventory rows without relying on ORM relationships that are absent in the admin model.
            locked = {}
            for product_id, variant_id in keys:
                q = select(Inventory).where(Inventory.product_id == product_id, Inventory.variant_id.is_(variant_id) if variant_id is not None else Inventory.variant_id.is_(None)).with_for_update()
                row = (await self.session.execute(q)).scalar_one_or_none()
                if row is None:
                    raise ConflictError(f'Inventory row missing for product {product_id}')
                locked[(product_id, variant_id)] = row
            for item in items:
                row = locked[(item.product_id, item.variant_id)]
                self.session.add(InventoryMovement(inventory_id=row.inventory_id, movement_type='C', quantity_change=item.quantity, reference_type='O', reference_id=id, performed_by=self.admin_id, notes=f'Admin cancellation {order.order_number}'))
            order.cancellation_reason = (remarks or 'Cancelled by admin').strip()
        order.order_status = status
        if status == 'D': order.delivery_date = date.today()
        await audit(self.session, self.admin_id, 'STATUS_CHANGE', 'orders', 'orders', str(id), {'old_status':old,'new_status':status,'remarks':remarks})
        await self.session.commit()
        return order

    async def confirm(self, id: int, remarks: str | None = None):
        """Confirm a newly submitted order and notify the customer by email.

        Confirmation is deliberately separate from the generic status endpoint so the
        business event cannot be accidentally skipped or sent twice.
        """
        from core.exceptions import ConflictError, NotFoundError
        from utils.email import safe_send_template_email

        order = await self.session.get(Order, id, with_for_update=True)
        if order is None:
            raise NotFoundError('Order not found')
        if order.order_status == 'C':
            raise ConflictError('Order is already confirmed')
        if order.order_status != 'P':
            raise ConflictError(f'Only submitted orders can be confirmed (current status: {order.order_status})')

        # User email is intentionally read by SQL so the standalone admin service does
        # not need to import the customer application's ORM package.
        row = (await self.session.execute(text('SELECT email, first_name FROM users WHERE user_id = :user_id'), {'user_id': order.user_id})).first()
        if row is None or not row.email:
            raise ConflictError('Customer email address is unavailable for this order')

        old = order.order_status
        order.order_status = 'C'
        await audit(self.session,self.admin_id,'STATUS_CHANGE','orders','orders',str(id),{'old_status':old,'new_status':'C','remarks':remarks})
        await self.session.commit()

        expected = order.expected_delivery_date.strftime('%d %b %Y') if order.expected_delivery_date else 'soon'
        context = {
            'first_name': row.first_name or 'Customer',
            'order_number': order.order_number,
            'expected_delivery': expected,
        }
        if self.background is not None:
            self.background.add_task(safe_send_template_email, row.email, 'ORDER_CONFIRMED', context)
        return order
