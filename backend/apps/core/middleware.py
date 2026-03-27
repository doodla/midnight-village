"""WebSocket authentication middleware for Django Channels."""

from urllib.parse import parse_qs

from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser

from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from rest_framework_simplejwt.tokens import AccessToken

User = get_user_model()


@database_sync_to_async
def get_user_from_token(token_str: str):
    """Validate a JWT access token and return the associated user."""
    try:
        token = AccessToken(token_str)  # pyrefly: ignore[bad-argument-type]
        return User.objects.get(id=token["user_id"])
    except Exception:
        return AnonymousUser()


class JWTAuthMiddleware(BaseMiddleware):
    """
    Channels middleware that authenticates WebSocket connections via JWT.

    Expects the token in the query string: ws://host/path/?token=<jwt>
    """

    async def __call__(self, scope, receive, send):
        # Skip if user is already authenticated (e.g., set by test harness)
        existing_user = scope.get("user")
        if existing_user is not None and not existing_user.is_anonymous:
            return await super().__call__(scope, receive, send)

        query_string = scope.get("query_string", b"").decode("utf-8")
        query_params = parse_qs(query_string)
        token_list = query_params.get("token", [])

        if token_list:
            scope["user"] = await get_user_from_token(token_list[0])
        else:
            scope["user"] = AnonymousUser()

        return await super().__call__(scope, receive, send)
