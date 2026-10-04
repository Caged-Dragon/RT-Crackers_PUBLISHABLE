from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from customers.profiles.models import UserProfile


class ProfileRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_or_create(self, user_id: int) -> UserProfile:
        profile = await self.session.get(UserProfile, user_id)
        if profile is None:
            profile = UserProfile(user_id=user_id)
            self.session.add(profile)
            await self.session.flush()
        return profile
