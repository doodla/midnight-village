"""ONUW app serializers."""

from __future__ import annotations

from typing import Any

from rest_framework import serializers

from .models import Game, Phase, PlayerRole


class PlayerRoleMeSerializer(serializers.ModelSerializer):
    """
    Player-scoped serializer for a player's own role.

    CRITICAL: This serializer only exposes the requesting player's own role
    information. It must NEVER include other players' roles, night_action_data,
    or center cards.
    """

    class Meta:
        model = PlayerRole
        fields = [
            "original_role",
            "current_role",
            "has_acted",
            "night_action_data",
        ]


class PlayerPublicSerializer(serializers.Serializer):
    """
    Public-only player info. NEVER includes roles, night_action_data,
    or vote targets.
    """

    player_id = serializers.IntegerField()
    display_name = serializers.CharField()


class PlayerPublicWithVoteStatusSerializer(PlayerPublicSerializer):
    """Player public info plus has_voted flag (used during voting phase)."""

    has_voted = serializers.BooleanField()


class GameMeSerializer(serializers.Serializer):
    """
    Player-scoped game state serializer.

    Returns only the information a specific player is allowed to see.
    Includes a players list and, during night phase, an action_prompt
    if the player needs to act in the current wave.
    """

    game_id = serializers.UUIDField(source="id")
    phase = serializers.CharField()
    current_wave = serializers.IntegerField()
    your_role = serializers.SerializerMethodField()
    has_voted = serializers.SerializerMethodField()
    players = serializers.SerializerMethodField()
    action_prompt = serializers.SerializerMethodField()

    def get_your_role(self, game: Game) -> dict:
        """Get the requesting player's role data."""
        player_role = self.context.get("player_role")
        if player_role is None:
            return {}
        return PlayerRoleMeSerializer(player_role).data

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
        from .engine.night import _build_prompt
        from .engine.roles import get_role
        from .services import build_game_state

        role_def = get_role(acting_role)
        state = build_game_state(game)
        prompt = _build_prompt(
            state, player_role.user_id, acting_role, role_def.action_types
        )
        return {
            "role_acting_as": prompt["role_acting_as"],
            "action_types": prompt["action_types"],
            "valid_targets": prompt["valid_targets"],
        }


class PlayerListSerializer(serializers.Serializer):
    """Serializer for the player list endpoint response."""

    players = serializers.ListField()


class CurrentGameSerializer(serializers.Serializer):
    """Serializer for the current game lookup response."""

    game_id = serializers.UUIDField()
    phase = serializers.CharField()
    lobby_code = serializers.CharField()


class GameStartResponseSerializer(serializers.Serializer):
    """Response serializer for the game start endpoint."""

    game_id = serializers.UUIDField()
    phase = serializers.CharField()
