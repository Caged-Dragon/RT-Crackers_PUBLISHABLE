from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.exceptions import NotFoundError, UnprocessableError
from customers.addresses.models import Address
from customers.addresses.repository import AddressRepository, PostalInfo
from customers.addresses.schemas import AddressCreate, AddressOut, AddressUpdate, PincodeCheck

# Fields frozen by the DB trigger (fn_protect_used_address) once an order references the address.
_IMMUTABLE_WHEN_USED = ("recipient_name", "recipient_phone", "house_no", "street", "area", "landmark", "postal_code_id")
_NULLABLE_FIELDS = ("landmark", "latitude", "longitude", "delivery_instructions", "contact_person", "contact_phone")
_COPIED_FIELDS = ("recipient_name", "recipient_phone", "house_no", "street", "area", "landmark", "postal_code_id", "latitude",
                  "longitude", "address_label", "delivery_instructions", "contact_person", "contact_phone")
_LABEL_TO_TYPE = {"HOME": ("H", "home"), "OFFICE": ("W", "work")}


def to_address_out(address: Address, postal: PostalInfo) -> AddressOut:
    type_code, type_label = _LABEL_TO_TYPE.get(address.address_label, ("O", "other"))
    return AddressOut(
        address_id=address.address_id, recipient_name=address.recipient_name, recipient_phone=address.recipient_phone,
        house_no=address.house_no, street=address.street, area=address.area, landmark=address.landmark, city=postal.city,
        district=postal.district, state=postal.state, country=postal.country, postal_code=postal.postal_code,
        latitude=address.latitude, longitude=address.longitude, address_label=address.address_label, address_type=type_code,
        address_type_label=type_label, delivery_instructions=address.delivery_instructions, contact_person=address.contact_person,
        contact_phone=address.contact_phone, is_verified=address.is_verified, is_default=address.is_default,
        is_serviceable=postal.is_serviceable, cod_available=postal.cod_available, created_at=address.created_at,
        updated_at=address.updated_at)


class AddressService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = AddressRepository(session)

    async def _require_postal(self, code: str) -> PostalInfo:
        postal = await self.repo.get_postal(code)
        if postal is None:
            raise UnprocessableError(f"We do not recognise pincode {code}", code="unknown_pincode")
        return postal

    async def list(self, user_id: int) -> list[AddressOut]:
        return [to_address_out(a, p) for a, p in await self.repo.list_for_user(user_id)]

    async def get(self, user_id: int, address_id: int) -> AddressOut:
        row = await self.repo.get_with_postal(address_id, user_id)
        if row is None:
            raise NotFoundError("Address not found", code="address_not_found")
        return to_address_out(*row)

    async def create(self, user_id: int, data: AddressCreate) -> AddressOut:
        postal = await self._require_postal(data.postal_code)
        make_default = data.is_default or await self.repo.count_active(user_id) == 0
        payload = data.model_dump(exclude={"is_default", "postal_code", "city", "address_type"})
        if make_default:
            await self.repo.clear_default(user_id)
        address = await self.repo.add(Address(user_id=user_id, is_default=make_default, postal_code_id=postal.postal_code_id, **payload))
        await self.session.commit()
        return to_address_out(address, postal)

    async def update(self, user_id: int, address_id: int, data: AddressUpdate) -> AddressOut:
        address = await self.repo.get(address_id, user_id, lock=True)
        if address is None:
            raise NotFoundError("Address not found", code="address_not_found")
        changes = data.model_dump(exclude_unset=True, exclude={"city", "address_type"})
        if data.address_label:
            changes["address_label"] = data.address_label
        want_default = changes.pop("is_default", None)
        changes = {k: v for k, v in changes.items() if v is not None or k in _NULLABLE_FIELDS}
        if "postal_code" in changes:
            postal = await self._require_postal(changes.pop("postal_code"))
            changes["postal_code_id"] = postal.postal_code_id
        for key in ("contact_phone", "contact_person"):
            if key in changes and not changes[key]:
                changes[key] = None
        if ("latitude" in changes) != ("longitude" in changes):
            raise UnprocessableError("latitude and longitude must be supplied together", code="invalid_coordinates")

        core_changed = any(k in changes and changes[k] != getattr(address, k) for k in _IMMUTABLE_WHEN_USED)
        if core_changed and await self.repo.is_used_by_order(address.address_id):
            # Order history must stay intact: archive the old row and save the edit as a new address.
            fields = {c: getattr(address, c) for c in _COPIED_FIELDS}
            fields.update(changes)
            was_default = address.is_default
            address.is_archived, address.is_default = True, False
            await self.session.flush()
            if was_default or want_default:
                await self.repo.clear_default(user_id)
            address = await self.repo.add(Address(user_id=user_id, is_default=bool(was_default or want_default), **fields))
        else:
            for key, value in changes.items():
                setattr(address, key, value)
            if want_default:
                await self.repo.clear_default(user_id, except_id=address.address_id)
                address.is_default = True
            elif want_default is False and address.is_default:
                address.is_default = False
        await self.session.commit()
        return await self.get(user_id, address.address_id)

    async def delete(self, user_id: int, address_id: int) -> None:
        address = await self.repo.get(address_id, user_id, lock=True)
        if address is None:
            raise NotFoundError("Address not found", code="address_not_found")
        was_default = address.is_default
        if await self.repo.is_used_by_order(address.address_id):
            address.is_archived, address.is_default = True, False
            await self.session.flush()
        else:
            await self.repo.hard_delete(address.address_id)
            await self.session.flush()
        if was_default:
            fallback = await self.repo.latest_active(user_id, exclude_id=address_id)
            if fallback:
                fallback.is_default = True
        await self.session.commit()

    async def set_default(self, user_id: int, address_id: int) -> AddressOut:
        address = await self.repo.get(address_id, user_id, lock=True)
        if address is None:
            raise NotFoundError("Address not found", code="address_not_found")
        await self.repo.clear_default(user_id, except_id=address_id)
        address.is_default = True
        await self.session.commit()
        return await self.get(user_id, address_id)

    async def check_pincode(self, code: str) -> PincodeCheck:
        postal = await self.repo.get_postal(code)
        if postal is None:
            raise NotFoundError("We do not deliver to this pincode yet", code="unknown_pincode")
        zone = await self.repo.get_zone(postal.zone_id)
        return PincodeCheck(pincode=postal.postal_code, city=postal.city, district=postal.district, state=postal.state,
                            country=postal.country, is_serviceable=postal.is_serviceable and bool(zone and zone.is_active),
                            cod_available=postal.cod_available, zone_code=zone.zone_code if zone else None)


def get_address_service(session: AsyncSession = Depends(get_db)) -> AddressService:
    return AddressService(session)
