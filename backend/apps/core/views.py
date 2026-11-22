"""
Core app views.
"""

import uuid

from django.db import transaction
from django.utils.cache import patch_cache_control

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

from . import practice
from .games import hooks_for, hooks_for_type
from .lobbies import (
    LobbyFullError,
    add_member,
    announce_lobby,
    current_table,
    other_active_table,
    touch,
)
from .models import Lobby, LobbyMember, User
from .name_generator import generate_display_name
from .online import online_counts
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

        # ``defaults`` (optional) names a set of settings the game offers for a new
        # table; the settings given in the body win over it. Nothing is written
        # unless the body asks.
        if "defaults" in request.data:
            name = request.data["defaults"]
            offered = (
                hooks_for_type(serializer.validated_data["game_type"]).default_settings(
                    name
                )
                if isinstance(name, str)
                else None
            )
            if offered is None:
                return Response(
                    {"detail": "Unknown defaults.", "code": "bad_request"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            given = serializer.validated_data.get("settings") or {}
            if not isinstance(given, dict):
                return Response(
                    {"detail": "Settings must be an object.", "code": "bad_request"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            serializer.validated_data["settings"] = {**offered, **given}

        # What the table starts with is checked now, not at the deal: a combination
        # the game refuses is refused here. Who will sit at the table is not known
        # yet, so the card list is not checked against a player count.
        merged = serializer.validated_data.get("settings") or {}
        if merged:
            errors = hooks_for_type(
                serializer.validated_data["game_type"]
            ).validate_settings(
                merged,
                0,
                changed=set(merged) - {"roles", "deck"}
                if isinstance(merged, dict)
                else None,
            )
            if errors:
                return Response(
                    {"detail": errors, "code": "bad_request"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
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
        """Merge settings into the lobby's (host only), validate, broadcast lobby_update.

        The keys given are merged over the stored settings, so a screen that sends
        only its own keys cannot drop another screen's. The Lobby row is locked from
        the checks to the save (two host taps cannot interleave), the merged result
        is what the game's validator checks, and nothing is stored if it refuses.
        """
        with transaction.atomic():
            try:
                lobby = Lobby.objects.select_for_update().get(code=code)
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

            if lobby.status == Lobby.Status.IN_GAME:
                return Response(
                    {
                        "detail": "Settings cannot change while a game is in progress.",
                        "code": "lobby_in_game",
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            given = (
                request.data.get("settings") if isinstance(request.data, dict) else None
            )
            if given is None:
                return Response(
                    {"detail": "settings field is required."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if not isinstance(given, dict):
                return Response(
                    {"detail": ["Settings must be an object."]},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            merged = {**lobby.settings, **given}
            from apps.core import games

            errors = games.hooks_for(lobby).validate_settings(
                merged,
                lobby.players.count(),  # type: ignore[attr-defined]
                changed=set(given),
                max_players=lobby.max_players,
            )
            if errors:
                return Response(
                    {"detail": errors},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            lobby.settings = merged
            lobby.save(update_fields=["settings", "updated_at"])
            data = LobbySerializer(lobby).data

        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}",
                {"type": "lobby.update", "data": data},
            )

        return Response(data, status=status.HTTP_200_OK)


class LobbyJoinView(APIView):
    """Join an existing lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        # The joining user's row is locked first, so two joins by one user to
        # two tables cannot both pass the one-table check; then the Lobby row,
        # from the checks to the insert, so two joins cannot both take the last
        # seat or the same token. (Lock order: User, then Lobby.)
        with transaction.atomic():
            User.objects.select_for_update().filter(pk=request.user.pk).first()
            try:
                lobby = Lobby.objects.select_for_update().get(code=code)
            except Lobby.DoesNotExist:
                return Response(
                    {"detail": "Lobby not found.", "code": "lobby_not_found"},
                    status=status.HTTP_404_NOT_FOUND,
                )

            if LobbyMember.objects.filter(lobby=lobby, user=request.user).exists():
                return Response(
                    {
                        "detail": "You are already in this lobby.",
                        "code": "already_in_lobby",
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if lobby.status != Lobby.Status.WAITING:
                return Response(
                    {
                        "detail": "Lobby is not accepting players.",
                        "code": "lobby_closed",
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # One table at a time (tables that opt in): a member of another table
            # still waiting is pointed at it instead of getting a second seat.
            other = (
                other_active_table(request.user.id, lobby.pk)  # type: ignore[misc]
                if hooks_for(lobby).shows_table_extras(lobby)
                else None
            )
            if other is not None:
                return Response(
                    {
                        "detail": "You are already at another table.",
                        "code": "already_at_table",
                        "lobby_code": other.code,
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            try:
                try:
                    add_member(lobby, request.user.id)  # type: ignore[misc]
                except LobbyFullError:
                    # A person takes a practice player's seat at a full table.
                    if not practice.make_room(lobby):
                        raise
                    add_member(lobby, request.user.id)  # type: ignore[misc]
            except LobbyFullError:
                return Response(
                    {"detail": "Lobby is full.", "code": "lobby_full"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            data = LobbySerializer(lobby).data
            announce_lobby(lobby)

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
                {"detail": "You are not in this lobby.", "code": "not_in_lobby"},
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
                    # Nobody else, or only practice players: the table closes.
                    practice.close_table(locked)
                    return Response(
                        {"detail": "Lobby deleted."}, status=status.HTTP_200_OK
                    )
                announce_lobby(locked)
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
            touch(locked.pk)
            if locked.acting_host_id == request.user.id:  # type: ignore[misc]
                from apps.core.host import member_leaving

                member_leaving(locked, request.user.id)  # type: ignore[misc]
            announce_lobby(locked)

        # Broadcast player left event (only for non-host)
        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}", {"type": "player.left", "username": username}
            )

        return Response({"detail": "Left lobby."}, status=status.HTTP_200_OK)


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


class LobbyPracticeView(APIView):
    """Practice players (host, waiting table): ``{"on": bool}`` switches them on or
    off for the table (off takes every one away), ``{"count": n}`` sets how many
    sit at it (a target, so a request sent twice leaves the table as once; above
    0 switches them on). Either or both. Answers the lobby body, like a PATCH,
    and the table hears ``lobby_update``. 400 ``bad_request`` (malformed),
    ``lobby_full`` (more than the free seats); 403 not the host; 404 unknown table
    or a game with no practice players; 409 ``lobby_closed`` once dealt
    (``apps.core.practice``).
    """

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, code: str) -> Response:
        body = request.data if isinstance(request.data, dict) else None
        on = None if body is None else body.get("on")
        count = None if body is None else body.get("count")
        if (
            body is None
            or (on is None and count is None)
            or (on is not None and type(on) is not bool)
            or (count is not None and (type(count) is not int or count < 0))
        ):
            return Response(
                {"detail": "Send on (true or false) or count.", "code": "bad_request"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        with transaction.atomic():
            lobby = Lobby.objects.select_for_update().filter(code=code).first()
            if lobby is None or not hooks_for(lobby).practice_seats(lobby):
                return Response(
                    {"detail": "Lobby not found.", "code": "lobby_not_found"},
                    status=status.HTTP_404_NOT_FOUND,
                )
            if not lobby.is_host(request.user.id):  # type: ignore[misc]
                return Response(
                    {"detail": "Only the host can seat practice players."},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if lobby.status != Lobby.Status.WAITING:
                return Response(
                    {
                        "detail": "Lobby is not accepting players.",
                        "code": "lobby_closed",
                    },
                    status=status.HTTP_409_CONFLICT,
                )
            try:
                practice.set_practice(lobby, on=on, count=count)
            except practice.PracticeError as exc:
                transaction.set_rollback(True)
                return Response(
                    {"detail": exc.detail, "code": exc.code}, status=exc.status
                )
            data = LobbySerializer(lobby).data
            announce_lobby(lobby)
        return Response(data, status=status.HTTP_200_OK)


class MyTableView(APIView):
    """Where am I: the table the caller is seated at, so the app can resume it.

    ``{"table": {"lobby_code", "game_type", "status", "is_host", "token",
    "game": {"game_id", "phase"} | null}}`` or ``{"table": null}``.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        return Response({"table": current_table(request.user.id)})  # type: ignore[misc]


class OnlineStatsThrottle(AnonRateThrottle):
    """Its own budget: the home screen polls this, guest sign-up must not pay for it."""

    scope = "online_stats"


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
