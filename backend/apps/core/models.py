"""Core models for Midnight Village."""

import secrets
import string

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """Custom User model for Midnight Village."""

    display_name = models.CharField(max_length=20, blank=True, default="")
    is_guest = models.BooleanField(default=False)


def generate_lobby_code() -> str:
    """Generate a unique 6-character alphanumeric lobby code."""
    alphabet = string.ascii_uppercase + string.digits
    # Remove ambiguous characters (0, O, I, 1, L)
    alphabet = (
        alphabet.replace("0", "")
        .replace("O", "")
        .replace("I", "")
        .replace("1", "")
        .replace("L", "")
    )
    return "".join(secrets.choice(alphabet) for _ in range(6))


class Lobby(models.Model):
    """
    Generic lobby for any game type.

    Game-specific apps extend this with their own configuration via the
    settings JSONField.
    """

    class Status(models.TextChoices):
        WAITING = "waiting", "Waiting for players"
        IN_GAME = "in_game", "Game in progress"
        FINISHED = "finished", "Game finished"

    code = models.CharField(max_length=6, unique=True, editable=False)
    host = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="hosted_lobbies",
    )
    game_type = models.CharField(max_length=50)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.WAITING,
    )
    max_players = models.PositiveIntegerField(default=10)
    settings = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name_plural = "lobbies"

    def __str__(self) -> str:
        return f"Lobby {self.code} ({self.game_type})"

    def save(self, *args, **kwargs):
        if not self.code:
            # Generate unique code
            for _ in range(10):  # Max attempts
                code = generate_lobby_code()
                if not Lobby.objects.filter(code=code).exists():
                    self.code = code
                    break
            else:
                raise ValueError("Could not generate unique lobby code")
        super().save(*args, **kwargs)


class LobbyMember(models.Model):
    """A player in a lobby."""

    lobby = models.ForeignKey(
        Lobby,
        on_delete=models.CASCADE,
        related_name="players",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="lobby_memberships",
    )
    is_ready = models.BooleanField(default=False)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["lobby", "user"], name="unique_lobby_member"
            )
        ]
        ordering = ("joined_at",)

    def __str__(self) -> str:
        return f"{self.user.username} in {self.lobby.code}"
