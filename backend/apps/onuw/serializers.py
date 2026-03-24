"""ONUW app serializers."""

from rest_framework import serializers

from .models import Game, PlayerRole


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


class GameMeSerializer(serializers.Serializer):
    """
    Player-scoped game state serializer.

    Returns only the information a specific player is allowed to see.
    """

    game_id = serializers.UUIDField(source="id")
    phase = serializers.CharField()
    your_role = serializers.SerializerMethodField()

    def get_your_role(self, game: Game) -> dict:
        """Get the requesting player's role data."""
        player_role = self.context.get("player_role")
        if player_role is None:
            return {}
        return PlayerRoleMeSerializer(player_role).data


class GameStartResponseSerializer(serializers.Serializer):
    """Response serializer for the game start endpoint."""

    game_id = serializers.UUIDField()
    phase = serializers.CharField()
