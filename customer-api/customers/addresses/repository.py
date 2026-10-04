from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import delete, exists, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from customers.addresses.models import Address, City, Country, DeliveryZone, District, PostalCode, State
from customers.orders.models import Order


@dataclass(slots=True)
class PostalInfo:
    """A postal code resolved through the geography hierarchy."""
    postal_code_id: int
    postal_code: str
    city: str
    district: str
    state: str
    country: str
    zone_id: int
    is_serviceable: bool
    cod_available: bool


_POSTAL_COLUMNS = (
    PostalCode.postal_code_id, PostalCode.postal_code, City.city_name.label("city"), District.district_name.label("district"),
    State.state_name.label("state"), Country.country_code.label("country"), PostalCode.zone_id, PostalCode.is_serviceable,
    PostalCode.cod_available,
)


def _postal_select():
    return (select(*_POSTAL_COLUMNS).select_from(PostalCode)
            .join(City, City.city_id == PostalCode.city_id).join(District, District.district_id == City.district_id)
            .join(State, State.state_id == District.state_id).join(Country, Country.country_id == State.country_id))


def _to_postal(row) -> PostalInfo:
    return PostalInfo(row.postal_code_id, row.postal_code.strip(), row.city, row.district, row.state, row.country.strip(),
                      row.zone_id, row.is_serviceable, row.cod_available)


class AddressRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # ------------------------------------------------------------ geography
    async def get_postal(self, code: str) -> PostalInfo | None:
        row = (await self.session.execute(_postal_select().where(PostalCode.postal_code == code))).first()
        return _to_postal(row) if row else None

    async def get_postal_by_id(self, postal_code_id: int) -> PostalInfo | None:
        row = (await self.session.execute(_postal_select().where(PostalCode.postal_code_id == postal_code_id))).first()
        return _to_postal(row) if row else None

    async def get_zone(self, zone_id: int) -> DeliveryZone | None:
        return await self.session.get(DeliveryZone, zone_id)

    # ------------------------------------------------------------ addresses
    async def list_for_user(self, user_id: int) -> list[tuple[Address, PostalInfo]]:
        stmt = (select(Address, *_POSTAL_COLUMNS).join(PostalCode, PostalCode.postal_code_id == Address.postal_code_id)
                .join(City, City.city_id == PostalCode.city_id).join(District, District.district_id == City.district_id)
                .join(State, State.state_id == District.state_id).join(Country, Country.country_id == State.country_id)
                .where(Address.user_id == user_id, Address.is_archived.is_(False))
                .order_by(Address.is_default.desc(), Address.created_at.desc(), Address.address_id.desc()))
        return [(row[0], _to_postal(row)) for row in (await self.session.execute(stmt)).all()]

    async def get(self, address_id: int, user_id: int, *, lock: bool = False) -> Address | None:
        stmt = select(Address).where(Address.address_id == address_id, Address.user_id == user_id, Address.is_archived.is_(False))
        if lock:
            stmt = stmt.with_for_update()
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def get_with_postal(self, address_id: int, user_id: int) -> tuple[Address, PostalInfo] | None:
        address = await self.get(address_id, user_id)
        if address is None:
            return None
        postal = await self.get_postal_by_id(address.postal_code_id)
        return (address, postal) if postal else None

    async def is_used_by_order(self, address_id: int) -> bool:
        stmt = select(exists().where((Order.billing_address_id == address_id) | (Order.shipping_address_id == address_id)))
        return bool((await self.session.execute(stmt)).scalar())

    async def count_active(self, user_id: int) -> int:
        stmt = select(func.count()).select_from(Address).where(Address.user_id == user_id, Address.is_archived.is_(False))
        return int((await self.session.execute(stmt)).scalar_one())

    async def clear_default(self, user_id: int, except_id: int | None = None) -> None:
        stmt = update(Address).where(Address.user_id == user_id, Address.is_default.is_(True), Address.is_archived.is_(False))
        if except_id is not None:
            stmt = stmt.where(Address.address_id != except_id)
        await self.session.execute(stmt.values(is_default=False))
        await self.session.flush()

    async def latest_active(self, user_id: int, exclude_id: int | None = None) -> Address | None:
        stmt = select(Address).where(Address.user_id == user_id, Address.is_archived.is_(False)).order_by(Address.created_at.desc(), Address.address_id.desc()).limit(1)
        if exclude_id is not None:
            stmt = stmt.where(Address.address_id != exclude_id)
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def add(self, address: Address) -> Address:
        self.session.add(address)
        await self.session.flush()
        return address

    async def hard_delete(self, address_id: int) -> None:
        await self.session.execute(delete(Address).where(Address.address_id == address_id))
