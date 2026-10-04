from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Header

from core.constants import CART_TOKEN_HEADER
from customers.auth.dependencies import OptionalUser
from customers.cart.service import CartContext


async def get_cart_context(
    user: OptionalUser,
    x_cart_token: Annotated[str | None, Header(alias=CART_TOKEN_HEADER, description="Guest cart token returned by earlier cart calls")] = None,
) -> CartContext:
    return CartContext(user=user, token=x_cart_token)


CartCtx = Annotated[CartContext, Depends(get_cart_context)]
