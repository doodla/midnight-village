"""ONUW admin configuration."""

from django.contrib import admin

from .models import (  # type: ignore[import]  — models pending implementation
    Game,
    PlayerRole,
)


@admin.register(Game)
class GameAdmin(admin.ModelAdmin):
    """Admin for Game model."""

    list_display = ("id", "lobby", "phase", "current_wave", "created_at")
    list_filter = ("phase",)
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(PlayerRole)
class PlayerRoleAdmin(admin.ModelAdmin):
    """Admin for PlayerRole model."""

    list_display = ("id", "game", "user", "original_role", "current_role", "has_acted")
    list_filter = ("original_role", "has_acted")
    readonly_fields = ("id",)
