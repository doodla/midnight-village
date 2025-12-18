"""Core app serializers."""

import regex
from rest_framework import serializers

from .models import Lobby, LobbyMember, User


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
        fields = ["user", "is_ready", "joined_at"]


class LobbySerializer(serializers.ModelSerializer):
    """Serializer for Lobby model."""

    players = LobbyMemberSerializer(many=True, read_only=True)
    host = UserBriefSerializer(read_only=True)

    class Meta:
        model = Lobby
        fields = [
            "code",
            "host",
            "game_type",
            "status",
            "max_players",
            "settings",
            "players",
            "created_at",
        ]
        read_only_fields = ["code", "host", "status", "created_at"]


class LobbyCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating a lobby."""

    class Meta:
        model = Lobby
        fields = ["game_type", "max_players", "settings"]
        extra_kwargs = {
            "max_players": {"required": False},
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

        # Check pattern: Unicode letters/numbers with single spaces between words
        # Use regex library for proper Unicode support
        pattern = regex.compile(r"^[\p{L}\p{N}]+( [\p{L}\p{N}]+)*$")
        if not pattern.match(value):
            raise serializers.ValidationError(
                "Display name can only contain letters, numbers, and single spaces."
            )

        return value
