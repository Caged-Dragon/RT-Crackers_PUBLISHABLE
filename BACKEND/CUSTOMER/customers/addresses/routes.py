from __future__ import annotations

from fastapi import APIRouter, Depends, Path, status

from customers.addresses.schemas import AddressCreate, AddressOut, AddressUpdate, PincodeCheck
from customers.addresses.service import AddressService, get_address_service
from customers.auth.dependencies import CurrentUser
from core.schemas import MessageResponse
from utils.validators import validate_pincode

router = APIRouter(prefix="/addresses", tags=["Addresses"])


@router.get("", response_model=list[AddressOut], summary="List my addresses (default first)")
async def list_addresses(user: CurrentUser, service: AddressService = Depends(get_address_service)):
    return await service.list(user.user_id)


@router.post("", response_model=AddressOut, status_code=status.HTTP_201_CREATED, summary="Add an address")
async def add_address(body: AddressCreate, user: CurrentUser, service: AddressService = Depends(get_address_service)):
    return await service.create(user.user_id, body)


@router.get("/pincode/{pincode}", response_model=PincodeCheck, summary="Check delivery / COD availability for a pincode")
async def check_pincode(pincode: str = Path(pattern=r"^[1-9][0-9]{5}$"), service: AddressService = Depends(get_address_service)):
    return await service.check_pincode(validate_pincode(pincode))


@router.get("/{address_id}", response_model=AddressOut, summary="Get one address")
async def get_address(address_id: int, user: CurrentUser, service: AddressService = Depends(get_address_service)):
    return await service.get(user.user_id, address_id)


@router.put("/{address_id}", response_model=AddressOut, summary="Update an address")
@router.patch("/{address_id}", response_model=AddressOut, include_in_schema=False)
async def update_address(address_id: int, body: AddressUpdate, user: CurrentUser, service: AddressService = Depends(get_address_service)):
    return await service.update(user.user_id, address_id, body)


@router.delete("/{address_id}", response_model=MessageResponse, summary="Delete an address (archived if an order used it)")
async def delete_address(address_id: int, user: CurrentUser, service: AddressService = Depends(get_address_service)):
    await service.delete(user.user_id, address_id)
    return MessageResponse(message="Address deleted")


@router.post("/{address_id}/default", response_model=AddressOut, summary="Make this the default address")
async def set_default(address_id: int, user: CurrentUser, service: AddressService = Depends(get_address_service)):
    return await service.set_default(user.user_id, address_id)
