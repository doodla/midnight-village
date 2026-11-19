"""ONUW app serializers."""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from .models import Game, Phase


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

    Returns only the information a specific player is allowed to see.
    Includes a players list and, during night phase, an action_prompt
    if the player needs to act in the current wave.
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
    has_voted = serializers.SerializerMethodField()
    players = serializers.SerializerMethodField()
    action_prompt = serializers.SerializerMethodField()
    roles_in_game = serializers.SerializerMethodField()
    night_results = serializers.SerializerMethodField()

    def get_deadline(self, game: Game) -> str | None:
        """
        Return the ISO 8601 deadline for the current phase, or None if untimed.

        Exposes game.phase_deadline so reconnecting clients know how much time
        remains for the current phase or wave.
        """
        if game.phase_deadline is not None:
            return game.phase_deadline.isoformat()
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
        Get the requesting player's role data, scoped by game phase.

        During RESULTS phase, reveal both original and current role plus
        night action data so the player can see what happened.

        During all other phases, only reveal original_role and has_acted.
        Players learn night action outcomes through WebSocket action_result
        events, NOT through this endpoint. current_role is hidden because
        a player should not know if they were swapped by Troublemaker/Robber
        unless their own role tells them.
        """
        player_role = self.context.get("player_role")
        if player_role is None:
            return {}
        data: dict[str, Any] = {
            "original_role": player_role.original_role,
            "has_acted": player_role.has_acted,
        }
        if game.phase == Phase.RESULTS:
            data["current_role"] = player_role.current_role
            data["night_action_data"] = player_role.night_action_data
        return data

    def get_has_voted(self, game: Game) -> bool:
        """
        Whether the player has submitted their vote.

        Only meaningful during the VOTING phase. During other phases,
        returns False.

        CRITICAL: Do NOT reveal the vote target here. Only reveal
        whether or not the player has voted.
        """
        if game.phase != "voting":
            return False
        player_role = self.context.get("player_role")
        if player_role is None:
            return False
        return bool(player_role.has_acted)

    def get_players(self, game: Game) -> list[dict[str, Any]]:
        """
        List of all players with public info only.

        During voting phase, includes has_voted status for each player.
        CRITICAL: Never include roles or vote targets.
        """
        all_player_roles = self.context.get("all_player_roles", [])
        result: list[dict[str, Any]] = []
        for pr in all_player_roles:
            entry: dict[str, Any] = {
                "player_id": pr.user_id,
                "display_name": pr.user.display_name or pr.user.username,
            }
            if game.phase == Phase.VOTING:
                entry["has_voted"] = bool(pr.has_acted)
            result.append(entry)
        return result

    def get_action_prompt(self, game: Game) -> dict[str, Any] | None:
        """
        During night phase, return the action prompt if the player
        needs to act in the current wave. None otherwise.

        This allows reconnecting clients to rebuild their night UI
        from a single GET call.
        """
        if game.phase != Phase.NIGHT or game.current_wave == 0:
            return None

        player_role = self.context.get("player_role")
        if player_role is None:
            return None

        # If the player has already acted this wave, no prompt needed
        if player_role.has_acted:
            return None

        # Use the service layer to determine if/what role they act as
        from .services import get_player_acting_role_for_wave

        acting_role = get_player_acting_role_for_wave(player_role, game.current_wave)
        if acting_role is None:
            return None

        # Build the prompt with valid targets
        from .engine.night import build_role_prompt
        from .services import build_game_state

        state = build_game_state(game)
        prompt = build_role_prompt(state, player_role.user_id, acting_role)
        return {
            "role_acting_as": prompt["role_acting_as"],
            "action_types": prompt["action_types"],
            "valid_targets": prompt["valid_targets"],
            "wave": game.current_wave,
        }

    def get_night_results(self, game: Game) -> list[dict[str, Any]]:
        """
        The requesting player's own night results for every closed window.

        Lets a phone that was offline when a window closed catch up: each entry
        has the same shape as the ``action_result`` socket event (``wave``,
        ``action_type``, ``revealed_info``) and is built by the same transform.
        Only this player's results, and nothing about a window still open.
        """
        player_role = self.context.get("player_role")
        if player_role is None:
            return []
        from .services import night_results_for_player

        names = {
            pr.user_id: pr.user.display_name or pr.user.username
            for pr in self.context.get("all_player_roles", [])
        }
        return night_results_for_player(game, player_role.user_id, names)

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
