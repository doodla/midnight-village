"""
Core app views that are not about one table: the health check, the guest
account, where this player is, who is online, and logging out. The lobby's
views are in ``views.py``, which also offers these names.
"""

import os
import uuid

from django.utils.cache import patch_cache_control

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from .lobbies import (
    current_table,
)
from .models import User
from .name_generator import generate_display_name
from .online import online_counts
from .serializers import GuestCreateSerializer
from .throttles import OnlineStatsThrottle, SignUpThrottle


@api_view(["GET"])
@permission_classes([AllowAny])
def health_check(request: Request) -> Response:
    """
    Health check endpoint for monitoring and load balancer probes.

    Returns:
        Response: JSON response with status "ok" and the commit this build was made
        from (Vercel's ``VERCEL_GIT_COMMIT_SHA``; "" anywhere else). The commit is public
        (the repository is) and lets the check after each merge wait for the new build
        (``tool/deployed_check.py``). The server is built from the ``live-server``
        branch, which moves only when what the server ships changed.
    """
    return Response(
        {"status": "ok", "commit": os.environ.get("VERCEL_GIT_COMMIT_SHA", "")},
        status=status.HTTP_200_OK,
    )


class GuestCreateView(APIView):
    """Create a guest account with optional display name."""

    permission_classes = [AllowAny]
    throttle_classes = [SignUpThrottle]

    def post(self, request):
        serializer = GuestCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        display_name = serializer.validated_data.get("display_name", "")  # type: ignore[misc]

        # Generate display name if not provided or empty
        if not display_name:
            display_name = generate_display_name()

        # Create guest user with UUID username
        user = User.objects.create_user(
            username=str(uuid.uuid4()),
            password=None,  # Guest accounts have no password
            display_name=display_name,
            is_guest=True,
        )

        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)

        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": {
                    "id": user.id,  # type: ignore[misc]
                    "display_name": user.display_name,
                },
            },
            status=status.HTTP_201_CREATED,
        )


class MyTableView(APIView):
    """Where am I: the table the caller is seated at, so the app can resume it.

    ``{"table": {"lobby_code", "game_type", "status", "is_host", "token",
    "game": {"game_id", "phase"} | null}}`` or ``{"table": null}``.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        return Response({"table": current_table(request.user.id)})  # type: ignore[misc]


class OnlineStatsView(APIView):
    """How many players are at how many tables right now (public, cacheable).

    ``{"players": 23, "tables": 5}`` from fresh socket rows; no user data, no login
    (``authentication_classes = []`` so a stale token on the home screen cannot
    turn it into a 401). The response says ``Cache-Control: public, max-age=15,
    s-maxage=15``: it MAY be reused for 15 s by browsers and shared caches. Whether
    a given CDN does is the platform's business; nothing here depends on it.
    """

    authentication_classes: list = []
    permission_classes = [AllowAny]
    throttle_classes = [OnlineStatsThrottle]

    def get(self, request: Request) -> Response:
        response = Response(online_counts())
        patch_cache_control(response, public=True, max_age=15, s_maxage=15)
        return response


class LogoutView(APIView):
    """Blacklist a refresh token to log out."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get("refresh")
        if not refresh_token:
            return Response(
                {"detail": "Refresh token is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except TokenError:
            return Response(
                {"detail": "Invalid or expired token."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response(
            {"detail": "Successfully logged out."}, status=status.HTTP_200_OK
        )
