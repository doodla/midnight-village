"""ONUW app serializers."""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from apps.core.practice import is_practice
from apps.core.wire import public_name, wire_time

from .models import Game, Phase, PlayerRole
from .protocol import in_look_stage, stage_token


def player_identity(pr: PlayerRole) -> dict[str, Any]:
    """A player's public table identity: who they are and where they sit.

    The one place the players lists (``/me/``, ``players/``, results) build it.
    Needs ``pr.user`` loaded. Never includes a role or a vote. A practice player
    (``apps.core.practice``) also has ``practice: true``; nobody else has the key.
    """
    identity: dict[str, Any] = {
        "player_id": pr.user_id,
        "display_name": public_name(pr.user),
        "token": pr.token,
        "seat": pr.seat,
    }
    if is_practice(pr.user):
        identity["practice"] = True
    return identity


class PlayerPublicSerializer(serializers.Serializer):
    """
    Public-only player info. NEVER includes roles, night_action_data,
    or vote targets.
    """

    player_id = serializers.IntegerField()
    display_name = serializers.CharField()


class GameMeSerializer(serializers.Serializer):
    """
    Player-scoped game state serializer.

    Returns only the information a specific player is allowed to see:
    the players list (public identity only), the caller's own role, prompt,
    night results, vote and ready flag, and the stage with its count and clock.
    """

    game_id = serializers.UUIDField(source="id")
    # The table's code, in every phase: the results screen needs it to play again
    # or leave.
    lobby_code = serializers.CharField(source="lobby.code", read_only=True)
    phase = serializers.CharField()
    current_wave = serializers.IntegerField()
    deadline = serializers.SerializerMethodField()
    your_role = serializers.SerializerMethodField()
    is_host = serializers.SerializerMethodField()
    host_id = serializers.SerializerMethodField()
    players = serializers.SerializerMethodField()
    action_prompt = serializers.SerializerMethodField()
    roles_in_game = serializers.SerializerMethodField()
    night_results = serializers.SerializerMethodField()
    night_results_seen = serializers.SerializerMethodField()

    def to_representation(self, instance: Game) -> dict[str, Any]:
        """The body, plus ``player_id`` (the caller's own), ``my_vote``, ``ready``,
        ``progress``, ``stage``, ``stage_started_at`` and ``vote_targets``."""
        data = super().to_representation(instance)
        data["player_id"] = self.context["player_role"].user_id
        data["my_vote"] = self._my_vote(instance)
        data["ready"] = self._ready(instance)
        data["progress"] = self._progress(instance)
        data["stage"] = stage_token(instance)
        data["stage_started_at"] = self._stage_started_at(instance)
        data["vote_targets"] = self._vote_targets(instance)
        return data

    def _stage_started_at(self, game: Game) -> str | None:
        """When the timed stage that is open now (the look, a night window, the
        talk, the vote) opened, in ``deadline``'s format, so a phone that restarts
        can draw how much of the stage has passed. The same for every player.

        None when the stage has no deadline (untimed, or no stage is open), and
        for a stage opened by code from before this field (the open time was not
        recorded then). Stored in ``Game.night_window_opened_at``, which every
        stage sets when it opens (no new column)."""
        opened_at = game.night_window_opened_at
        if game.phase_deadline is None or opened_at is None:
            return None
        if game.phase not in (Phase.NIGHT, Phase.DISCUSSION, Phase.VOTING):
            return None
        return wire_time(opened_at)

    def _vote_targets(self, game: Game) -> list[int] | None:
        """While voting: the player ids the caller may vote for, in seat order
        (every player in the game but the caller: no self-votes,
        ``docs/specs/onuw/voting-and-resolution.md``; the same rule
        ``voting.submit_vote`` checks). None outside the vote."""
        player_role = self.context.get("player_role")
        if game.phase != Phase.VOTING or player_role is None:
            return None
        return [
            pr.user_id
            for pr in self.context.get("all_player_roles", [])
            if pr.user_id != player_role.user_id
        ]

    def get_deadline(self, game: Game) -> str | None:
        """
        Return the ISO 8601 deadline for the current phase, or None if untimed.

        Exposes game.phase_deadline so reconnecting clients know how much time
        remains for the current phase or wave.
        """
        if game.phase_deadline is not None:
            return wire_time(game.phase_deadline)
        return None

    def get_host_id(self, game: Game) -> int:
        """Who holds the host role now (the acting host while the owner is away)."""
        return game.lobby.effective_host_id

    def get_is_host(self, game: Game) -> bool:
        """
        Whether the requesting player is the effective host (the owner, or the
        acting host while the owner's phone is away).

        Controls host-only actions such as ending the discussion phase early.
        Returns False when the request context is unavailable (e.g. tests
        that omit it).
        """
        request = self.context.get("request")
        if request is None:
            return False
        return game.lobby.is_host(request.user.id)

    def get_your_role(self, game: Game) -> dict:
        """
        The requesting player's role data, scoped by game phase.

        In the RESULTS phase, both the original and the current role plus the
        night action data, so the player can see what happened. In every other
        phase only ``original_role``: what the night showed them is in
        ``night_results``, and ``current_role`` stays hidden (a player must not
        know they were swapped unless their own role tells them).
        """
        player_role = self.context.get("player_role")
        if player_role is None:
            return {}
        data: dict[str, Any] = {"original_role": player_role.original_role}
        if game.phase == Phase.RESULTS:
            data["current_role"] = player_role.current_role
            data["night_action_data"] = player_role.night_action_data
        return data

    def get_players(self, game: Game) -> list[dict[str, Any]]:
        """
        List of all players with public info only (who they are, where they sit).

        CRITICAL: Never include roles, votes or who has voted.
        """
        return [player_identity(pr) for pr in self.context.get("all_player_roles", [])]

    def get_action_prompt(self, game: Game) -> dict[str, Any] | None:
        """The caller's prompt in an open night window (``choose_night.prompt_for``):
        every player has one, shaped alike, for as long as the window is open (it
        says whether the caller has chosen in it). None outside a window."""
        player_role = self.context.get("player_role")
        if game.phase != Phase.NIGHT or game.current_wave == 0 or player_role is None:
            return None
        from . import choose_night

        return choose_night.prompt_for(game, player_role)

    def get_night_results(self, game: Game) -> list[dict[str, Any]]:
        """
        The requesting player's own night results for every closed window (and the
        Doppelganger's look as soon as it resolves): ``wave``, ``action_type``,
        ``revealed_info``. Only this player's results, nothing about a window still
        open.
        """
        player_role = self.context.get("player_role")
        if player_role is None:
            return []
        from .night_results import night_results_for_player

        names = {
            pr.user_id: public_name(pr.user)
            for pr in self.context.get("all_player_roles", [])
        }
        return night_results_for_player(
            game, player_role.user_id, names, player_role.night_action_data
        )

    def get_night_results_seen(self, game: Game) -> int:
        """How many of their ``night_results`` the caller has acknowledged.

        The caller's own count only (``POST night-results/seen/`` raises it), so
        a restarted app shows just the results it has not shown yet.
        """
        player_role = self.context.get("player_role")
        return 0 if player_role is None else player_role.night_results_seen

    def _my_vote(self, game: Game) -> dict[str, Any] | None:
        """The caller's own pick while voting: ``{"target_player_id", "locked"}``,
        or None (not voting, or nothing picked yet). Never anyone else's."""
        player_role = self.context.get("player_role")
        if (
            game.phase != Phase.VOTING
            or player_role is None
            or player_role.vote_target_id is None
        ):
            return None
        return {
            "target_player_id": player_role.vote_target_id,
            "locked": bool(player_role.has_acted),
        }

    def _ready(self, game: Game) -> bool | None:
        """The caller's own "ready" flag at the stages that have one (the look and
        the talk); None elsewhere."""
        player_role = self.context.get("player_role")
        if player_role is None:
            return None
        if game.phase != Phase.DISCUSSION and not in_look_stage(game):
            return None
        return bool(player_role.phase_ready)

    def _progress(self, game: Game) -> dict[str, Any] | None:
        """``{"stage", "done", "needed"}`` at the look, talk and vote stages: a
        count of the table's taps, never who tapped. None elsewhere."""
        from .readiness import stage_progress

        return stage_progress(game)

    def get_roles_in_game(self, game: Game) -> list[dict[str, Any]]:
        """
        Return the list of roles in this game with their counts.

        Allows clients to display all roles that are in play during
        the discussion phase (RoleTokenList).
        """
        roles: dict[str, int] = game.settings.get("roles", {})
        return [{"role": role, "count": count} for role, count in roles.items()]


class GameStartResponseSerializer(serializers.Serializer):
    """Response serializer for the game start endpoint."""

    game_id = serializers.UUIDField()
    phase = serializers.CharField()
