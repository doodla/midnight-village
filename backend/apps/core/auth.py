"""
Renewing a sign-in (``POST /api/auth/token/refresh/``).

One rule for every way an account can be gone (deleted, made inactive): the
server answers 401, on the refresh as on any authenticated read, so the app can
tell "this account is gone" (start afresh) from "no answer" (ask again).
SimpleJWT's own refresh looks the user up with ``.get()`` and lets
``DoesNotExist`` escape as a 500 for a deleted user; this one answers 401
``user_not_found``, as ``JWTAuthentication`` does on a read.
"""

from __future__ import annotations

from typing import Any

from django.contrib.auth import get_user_model

from rest_framework_simplejwt.exceptions import AuthenticationFailed
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.views import TokenRefreshView


class AccountTokenRefreshSerializer(TokenRefreshSerializer):
    """SimpleJWT's refresh, with a user who is gone answered 401."""

    def validate(self, attrs: dict[str, Any]) -> dict[str, str]:
        refresh = self.token_class(attrs["refresh"])
        claim = str(api_settings.USER_ID_CLAIM)
        field = str(api_settings.USER_ID_FIELD)
        user_id = refresh.payload.get(claim)
        if (
            user_id is not None
            and not get_user_model().objects.filter(**{field: user_id}).exists()
        ):
            raise AuthenticationFailed("User not found", "user_not_found")
        return super().validate(attrs)


class AccountTokenRefreshView(TokenRefreshView):
    serializer_class = AccountTokenRefreshSerializer  # type: ignore[assignment]
