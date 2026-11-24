"""
Core app views.
"""

from django.db import transaction

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from rest_framework import status
from rest_framework.generics import CreateAPIView, RetrieveAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from . import asked as ask
from . import practice
from .games import hooks_for, hooks_for_type
from .lobbies import (
    LobbyFullError,
    add_member,
    announce_lobby,
    other_active_table,
    told_body,
    touch,
)
from .models import Lobby, LobbyMember, User
from .serializers import LobbyCreateSerializer, LobbySerializer

# The views that are not about one table live in views_home.py; they are offered
# here too, so urls.py and anything that imports them from here need not know.
from .views_home import (  # noqa: F401
    GuestCreateView,
    LogoutView,
    MyTableView,
    OnlineStatsView,
    health_check,
)


class LobbyCreateView(CreateAPIView):
    """Create a new lobby."""

    serializer_class = LobbyCreateSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        # The host takes the first seat (and token) in the same transaction. A
        # person has practice players at one table at a time: a new table clears
        # theirs from the others (``practice.clear_elsewhere``).
        with transaction.atomic():
            cleared = practice.clear_elsewhere(self.request.user.id)  # type: ignore[arg-type]
            lobby = serializer.save(host=self.request.user)
            add_member(lobby, self.request.user.id)  # type: ignore[misc]
            for other in cleared:
                announce_lobby(other)

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
        # ``practice`` is the practice endpoint's alone (``practice.strip_setting``).
        if "settings" in serializer.validated_data:
            serializer.validated_data["settings"] = practice.strip_setting(
                serializer.validated_data["settings"]
            )
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
                    # one message, a string, as every refusal's is
                    {"detail": errors[0], "code": "bad_request"},
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
        An optional ``asked`` drops keys a newer tap set (``apps.core.asked``).
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
                    {"detail": "Settings must be an object.", "code": "bad_request"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            asked, refusal = ask.read(request.data)
            if refusal is not None:
                return refusal
            # ``practice`` is set and cleared by the practice endpoint alone. A key
            # a newer tap of this user set is dropped; all dropped is 409.
            given = practice.strip_setting(given)
            kept, newest = ask.fresh(lobby.asked, given, request.user.id, asked)
            if newest is not None and not kept:  # every key given was stale
                return ask.stale_response(newest)
            given = kept
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
                    {"detail": errors[0], "code": "bad_request"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            lobby.settings = merged
            lobby.asked = ask.noted(lobby.asked, list(given), request.user.id, asked)
            lobby.save(update_fields=["settings", "asked", "updated_at"])
            data = told_body(lobby)  # one bump: the answer and lobby_update

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

            data = announce_lobby(lobby)  # one bump: the answer and lobby_update

        # Broadcast player joined event (the join has committed)
        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}",
                # `username` stays in this internal message: a server instance of the
                # build before this one reads it. No phone is sent it.
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
            data = play_again(code, request.user.id)
        except PlayAgainError as exc:
            return Response({"detail": exc.detail}, status=exc.status_code)
        return Response(data, status=status.HTTP_200_OK)


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
        asked, refusal = ask.read(body)
        if refusal is not None:
            return refusal
        switching_on = on is True or (on is None and bool(count))
        with transaction.atomic():
            # With the caller's other tables (pk order): switching on clears
            # theirs there (a person has practice players at one table at a time).
            lobby = practice.lock_with_theirs(code, request.user.id)  # type: ignore[arg-type]
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
            newest = ask.newer(
                lobby.asked, practice.SETTING_KEY, request.user.id, asked
            )
            if newest is not None:
                return ask.stale_response(newest)
            cleared = (
                practice.clear_elsewhere(request.user.id, keep=lobby)  # type: ignore[arg-type]
                if switching_on
                else []
            )
            try:
                practice.set_practice(lobby, on=on, count=count)
            except practice.PracticeError as exc:
                transaction.set_rollback(True)
                return Response(
                    {"detail": exc.detail, "code": exc.code}, status=exc.status
                )
            practice.note_asked(lobby, request.user.id, asked)  # type: ignore[arg-type]
            data = announce_lobby(lobby)  # one bump: the answer and lobby_update
            for other in cleared:
                announce_lobby(other)
        return Response(data, status=status.HTTP_200_OK)
