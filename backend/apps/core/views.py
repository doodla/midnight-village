"""
Core app views.
"""

import uuid

from django.db import transaction

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import CreateAPIView, RetrieveAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from .lobbies import LobbyFullError, add_member, current_table
from .models import Lobby, LobbyMember, User
from .name_generator import generate_display_name
from .serializers import GuestCreateSerializer, LobbyCreateSerializer, LobbySerializer


@api_view(["GET"])
@permission_classes([AllowAny])
def health_check(request: Request) -> Response:
    """
    Health check endpoint for monitoring and load balancer probes.

    Returns:
        Response: JSON response with status "ok"
    """
    return Response({"status": "ok"}, status=status.HTTP_200_OK)


class GuestCreateView(APIView):
    """Create a guest account with optional display name."""

    permission_classes = [AllowAny]
    throttle_classes = [AnonRateThrottle]

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


class LobbyCreateView(CreateAPIView):
    """Create a new lobby."""

    serializer_class = LobbyCreateSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        # The host takes the first seat (and token) in the same transaction.
        with transaction.atomic():
            lobby = serializer.save(host=self.request.user)
            add_member(lobby, self.request.user.id)  # type: ignore[misc]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)

        # Return full lobby data
        lobby = serializer.instance
        output_serializer = LobbySerializer(lobby)
        return Response(output_serializer.data, status=status.HTTP_201_CREATED)


class LobbyDetailView(RetrieveAPIView):
    """Retrieve or update (host-only) a lobby by code."""

    serializer_class = LobbySerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "code"
    queryset = Lobby.objects.all()

    def patch(self, request: Request, code: str) -> Response:
        """Update lobby settings (host only). Validates and broadcasts lobby_update."""
        try:
            lobby = Lobby.objects.get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not lobby.is_host(request.user.id):  # type: ignore[misc]
            return Response(
                {"detail": "Only the host can update lobby settings."},
                status=status.HTTP_403_FORBIDDEN,
            )

        new_settings = request.data.get("settings")
        if new_settings is None:
            return Response(
                {"detail": "settings field is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validate role settings if provided.
        from apps.core import games

        player_count = lobby.players.count()
        errors = games.hooks_for(lobby).validate_settings(new_settings, player_count)
        if errors:
            return Response(
                {"detail": errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        lobby.settings = new_settings
        lobby.save(update_fields=["settings", "updated_at"])

        channel_layer = get_channel_layer()
        if channel_layer is not None:
            serializer = LobbySerializer(lobby)
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}",
                {"type": "lobby.update", "data": serializer.data},
            )

        serializer = LobbySerializer(lobby)
        return Response(serializer.data, status=status.HTTP_200_OK)


class LobbyJoinView(APIView):
    """Join an existing lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        # The Lobby row is locked from the checks to the insert, so two joins
        # cannot both take the last seat or the same token.
        with transaction.atomic():
            try:
                lobby = Lobby.objects.select_for_update().get(code=code)
            except Lobby.DoesNotExist:
                return Response(
                    {"detail": "Lobby not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )

            if LobbyMember.objects.filter(lobby=lobby, user=request.user).exists():
                return Response(
                    {"detail": "You are already in this lobby."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if lobby.status != Lobby.Status.WAITING:
                return Response(
                    {"detail": "Lobby is not accepting players."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            try:
                add_member(lobby, request.user.id)  # type: ignore[misc]
            except LobbyFullError:
                return Response(
                    {"detail": "Lobby is full.", "code": "lobby_full"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            data = LobbySerializer(lobby).data

        # Broadcast player joined event (the join has committed)
        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}",
                {"type": "player.joined", "username": request.user.username},
            )

        return Response(data, status=status.HTTP_200_OK)


class LobbyLeaveView(APIView):
    """Leave a lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        try:
            lobby = Lobby.objects.get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Check if user is in lobby
        try:
            membership = LobbyMember.objects.get(lobby=lobby, user=request.user)
        except LobbyMember.DoesNotExist:
            return Response(
                {"detail": "You are not in this lobby."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # The owner leaving: never while a game is in progress. Otherwise the
        # table survives if anyone else is still in it (ownership moves for good
        # to the next member), and is deleted only when the owner was the last.
        if lobby.host == request.user:
            from apps.core.host import transfer_ownership

            # Lock the lobby row first, like every other writer (Lobby, then its
            # members and sockets): a presence check or handover running at the
            # same moment waits for this, then finds the lobby gone (or the new
            # owner) instead of locking children in the opposite order.
            with transaction.atomic():
                locked = Lobby.objects.select_for_update().filter(pk=lobby.pk).first()
                if locked is None:
                    return Response(
                        {"detail": "Lobby deleted."}, status=status.HTTP_200_OK
                    )
                if locked.status == Lobby.Status.IN_GAME:
                    return Response(
                        {"detail": "Cannot leave while a game is in progress."},
                        status=status.HTTP_409_CONFLICT,
                    )
                username = request.user.username
                if transfer_ownership(locked, request.user.id) is None:  # type: ignore[misc]
                    locked.delete()
                    return Response(
                        {"detail": "Lobby deleted."}, status=status.HTTP_200_OK
                    )
            channel_layer = get_channel_layer()
            if channel_layer is not None:
                async_to_sync(channel_layer.group_send)(
                    f"lobby_{lobby.code}",
                    {"type": "player.left", "username": username},
                )
            return Response({"detail": "Left lobby."}, status=status.HTTP_200_OK)

        # Otherwise just remove the player. If they hold the acting-host role
        # it passes to the next connected member (or back to the owner). Lock
        # order: Lobby, then the member (see apps.core.host).
        username = request.user.username
        with transaction.atomic():
            locked = Lobby.objects.select_for_update().get(pk=lobby.pk)
            membership.delete()
            if locked.acting_host_id == request.user.id:  # type: ignore[misc]
                from apps.core.host import member_leaving

                member_leaving(locked, request.user.id)  # type: ignore[misc]

        # Broadcast player left event (only for non-host)
        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}", {"type": "player.left", "username": username}
            )

        return Response({"detail": "Left lobby."}, status=status.HTTP_200_OK)


class LobbyReadyView(APIView):
    """Toggle ready state for a player in a lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        try:
            lobby = Lobby.objects.get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            membership = LobbyMember.objects.get(lobby=lobby, user=request.user)
        except LobbyMember.DoesNotExist:
            return Response(
                {"detail": "You are not in this lobby."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        is_ready = request.data.get("is_ready", not membership.is_ready)
        if not isinstance(is_ready, bool):
            return Response(
                {"detail": "is_ready must be true or false.", "code": "bad_request"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        membership.is_ready = is_ready
        membership.save(update_fields=["is_ready"])

        # Broadcast player ready state change
        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}",
                {
                    "type": "player.ready",
                    "username": request.user.username,
                    "user_id": request.user.id,
                    "is_ready": membership.is_ready,
                },
            )

        serializer = LobbySerializer(lobby)
        return Response(serializer.data, status=status.HTTP_200_OK)


class LobbyPlayAgainView(APIView):
    """Reopen a lobby after its game has finished so the host can deal again.

    Host only (403). The lobby's newest game must be in the results phase
    (409 otherwise, including while a game is running). Members and settings
    (the deck) are kept; the lobby goes back to ``waiting`` with everyone
    ready. Returns the lobby, same body as the lobby detail. The finished game
    and its results stay readable.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        from apps.core.lobbies import PlayAgainError, play_again

        try:
            lobby = play_again(code, request.user.id)
        except PlayAgainError as exc:
            return Response({"detail": exc.detail}, status=exc.status_code)
        return Response(LobbySerializer(lobby).data, status=status.HTTP_200_OK)


class MyTableView(APIView):
    """Where am I: the table the caller is seated at, so the app can resume it.

    ``{"table": {"lobby_code", "game_type", "status", "is_host", "token",
    "game": {"game_id", "phase"} | null}}`` or ``{"table": null}``.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        return Response({"table": current_table(request.user.id)})  # type: ignore[misc]


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
