"""Core app serializers."""

import re

from rest_framework import serializers

from .models import Lobby, LobbyMember, User
from .tokens import MAX_TABLE_SIZE

DISPLAY_NAME_PATTERN = re.compile(r"^[\w]+( [\w]+)*$", re.UNICODE)


class UserBriefSerializer(serializers.ModelSerializer):
    """Brief user info for embedding in other serializers."""

    class Meta:
        model = User
        fields = ["id", "username", "display_name"]


class LobbyMemberSerializer(serializers.ModelSerializer):
    """Serializer for lobby players."""

    user = UserBriefSerializer(read_only=True)

    class Meta:
        model = LobbyMember
        # ``is_ready`` stays in the table (no migration) but gates nothing and is no
        # longer sent: the deal has no ready check (``docs/dev/status.md``).
        fields = ["user", "token", "joined_at"]


class LobbySerializer(serializers.ModelSerializer):
    """Serializer for Lobby model."""

    players = LobbyMemberSerializer(many=True, read_only=True)
    # `host` is the EFFECTIVE host (the acting host while the owner is away), so
    # clients that only read `host` keep working.
    host = serializers.SerializerMethodField()
    original_host_id = serializers.IntegerField(source="host_id", read_only=True)
    is_acting_host = serializers.SerializerMethodField()

    class Meta:
        model = Lobby
        fields = [
            "code",
            "host",
            "original_host_id",
            "is_acting_host",
            "game_type",
            "status",
            "max_players",
            "settings",
            "players",
            "created_at",
        ]
        read_only_fields = ["code", "status", "created_at"]

    def to_representation(self, instance: Lobby) -> dict:
        """The body. A table whose game opts in (``GameHooks.shows_table_extras``:
        every ONUW table) also gets the game's keys and, per member, ``connected``
        (``lobbies.connected_members``)."""
        from . import practice
        from .games import hooks_for
        from .lobbies import connected_members

        data = super().to_representation(instance)
        hooks = hooks_for(instance)
        if not hooks.shows_table_extras(instance):
            return data
        extras = hooks.lobby_extras(instance)
        connected = connected_members(instance)
        for entry in data["players"]:
            entry["connected"] = entry["user"]["id"] in connected
        data.update(extras)
        # Practice players (``practice.body_extras``): marked, always here, and
        # ``practice`` for a table that uses them; nothing for one that never did.
        data.update(practice.body_extras(instance, data["players"]))
        return data

    def get_host(self, lobby: Lobby) -> dict:
        return UserBriefSerializer(lobby.effective_host).data

    def get_is_acting_host(self, lobby: Lobby) -> bool:
        return lobby.acting_host_id is not None


class LobbyCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating a lobby."""

    class Meta:
        model = Lobby
        fields = ["game_type", "max_players", "settings"]
        extra_kwargs = {
            # A table seats at most one player per token (apps.core.tokens); the
            # game checks its own minimum (and maximum) when it deals.
            "max_players": {
                "required": False,
                "min_value": 1,
                "max_value": MAX_TABLE_SIZE,
            },
            "settings": {"required": False},
        }


class GuestCreateSerializer(serializers.Serializer):
    """Serializer for guest account creation."""

    display_name = serializers.CharField(
        max_length=20,
        required=False,
        allow_blank=True,
        default="",
    )

    def validate_display_name(self, value: str) -> str:
        """Validate and normalize display name."""
        # Trim whitespace
        value = value.strip()

        # Empty is valid (will be generated later)
        if not value:
            return ""

        # Check for control characters (anything below space except allowed)
        if any(ord(c) < 32 for c in value):
            raise serializers.ValidationError(
                "Display name contains invalid characters."
            )

        # Check pattern: alphanumeric with single spaces between words
        if not DISPLAY_NAME_PATTERN.match(value):
            raise serializers.ValidationError(
                "Display name can only contain letters, numbers, and single spaces."
            )

        return value
