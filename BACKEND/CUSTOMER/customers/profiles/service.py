from __future__ import annotations

import asyncio

from fastapi import BackgroundTasks, Depends, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.exceptions import BadRequestError
from core.security import hash_password, verify_password
from customers.auth.models import User
from customers.auth.repository import AuthRepository
from customers.profiles.repository import ProfileRepository
from customers.profiles.schemas import (
    AvatarResponse, ChangePasswordRequest, NotificationPreferences, NotificationPreferencesUpdate, ProfileOut, ProfileUpdate,
)
from utils.email import safe_send_template_email
from utils.helpers import utcnow
from utils.storage import save_image

_USER_FIELDS = {"first_name", "middle_name", "last_name", "gender", "dob", "preferred_language"}
_PROFILE_FIELDS = {"display_name", "bio", "alternate_phone", "whatsapp_number", "occupation", "timezone"}


class ProfileService:
    def __init__(self, session: AsyncSession, background: BackgroundTasks):
        self.session = session
        self.repo = ProfileRepository(session)
        self.auth_repo = AuthRepository(session)
        self.bg = background

    async def _build(self, user: User) -> ProfileOut:
        profile = await self.repo.get_or_create(user.user_id)
        data = {c: getattr(user, c) for c in ProfileOut.model_fields if hasattr(user, c)}
        data.update({c: getattr(profile, c) for c in _PROFILE_FIELDS | {"age_verified"}})
        data["full_name"] = user.full_name
        return ProfileOut(**data)

    async def get_profile(self, user: User) -> ProfileOut:
        out = await self._build(user)
        await self.session.commit()  # persists a lazily-created profile row
        return out

    async def update_profile(self, user: User, data: ProfileUpdate) -> ProfileOut:
        changes = data.model_dump(exclude_unset=True)
        if "first_name" in changes and not changes["first_name"]:
            raise BadRequestError("first_name cannot be empty")
        profile = await self.repo.get_or_create(user.user_id)
        for key, value in changes.items():
            if key in _USER_FIELDS:
                setattr(user, key, value)
            elif key in _PROFILE_FIELDS:
                setattr(profile, key, value)
        if changes.get("dob") is not None:
            profile.age_verified, profile.age_verified_at = True, utcnow()
        await self.session.commit()
        return await self._build(user)

    async def upload_avatar(self, user: User, file: UploadFile) -> AvatarResponse:
        url = await save_image(file, f"avatars/{user.user_id}", max_side=512)
        user.profile_image = url
        await self.session.commit()
        return AvatarResponse(profile_image=url)

    async def remove_avatar(self, user: User) -> None:
        user.profile_image = None
        await self.session.commit()

    async def change_password(self, user: User, data: ChangePasswordRequest, current_session_id) -> None:
        if not await asyncio.to_thread(verify_password, data.current_password, user.password_hash):
            raise BadRequestError("Current password is incorrect", code="invalid_current_password")
        if data.current_password == data.new_password:
            raise BadRequestError("New password must differ from the current password", code="password_unchanged")
        user.password_hash = await asyncio.to_thread(hash_password, data.new_password)
        user.last_password_change = utcnow()
        # Sign out every other device; keep the one that made the change.
        await self.auth_repo.end_all_sessions(user.user_id)
        from sqlalchemy import update
        from customers.auth.models import UserSession
        await self.session.execute(update(UserSession).where(UserSession.session_id == current_session_id).values(ended_at=None))
        await self.session.commit()
        self.bg.add_task(safe_send_template_email, user.email, "PASSWORD_CHANGED", {"first_name": user.first_name})

    async def get_preferences(self, user: User) -> NotificationPreferences:
        profile = await self.repo.get_or_create(user.user_id)
        await self.session.commit()
        return NotificationPreferences.model_validate(profile)

    async def update_preferences(self, user: User, data: NotificationPreferencesUpdate) -> NotificationPreferences:
        profile = await self.repo.get_or_create(user.user_id)
        for key, value in data.model_dump(exclude_unset=True).items():
            if value is not None:
                setattr(profile, key, value)
        await self.session.commit()
        return NotificationPreferences.model_validate(profile)


def get_profile_service(background: BackgroundTasks, session: AsyncSession = Depends(get_db)) -> ProfileService:
    return ProfileService(session, background)
