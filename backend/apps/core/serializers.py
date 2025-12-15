"""Core app serializers."""

from rest_framework import serializers

from .models import Lobby, LobbyMember, User


class UserBriefSerializer(serializers.ModelSerializer):
    """Brief user info for embedding in other serializers."""

    class Meta:
        model = User
        fields = ["id", "username"]


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
