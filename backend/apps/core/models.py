"""Core models for Midnight Village."""

import secrets
import string

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


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
    # The original host (the owner). Never changed by a handover.
    # While the owner's phone is away, `acting_host` holds the role (see
    # apps.core.host); every host-only check goes through is_host().
    acting_host = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="acting_hosted_lobbies",
    )
    game_type = models.CharField(max_length=50)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.WAITING,
    )
    max_players = models.PositiveIntegerField(default=10)
    settings = models.JSONField(default=dict, blank=True)
    # The newest ``asked`` applied per settings key (and ``practice``):
    # key -> [user_id, asked] (``apps.core.asked``). Never in a response.
    # pyrefly: ignore [no-matching-overload]  (the stubs lack JSONField db_default)
    asked = models.JSONField(
        default=dict,
        db_default=models.Value({}, output_field=models.JSONField()),
        blank=True,
    )
    # The lobby body's number: starts at 0 and only rises, by one each time a
    # change is told (``lobbies.told_body``, ``lobbies.bump_rev``). A phone shows a
    # body whose ``rev`` is equal to or higher than the newest it has shown.
    rev = models.IntegerField(default=0, db_default=0)
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

    @property
    def effective_host_id(self) -> int:
        """Who holds the host role now: the acting host if one is set, else the owner."""
        return self.acting_host_id or self.host_id  # type: ignore[attr-defined]

    @property
    def effective_host(self):
        """The User who holds the host role now."""
        return self.acting_host if self.acting_host_id else self.host  # type: ignore[attr-defined]

    def is_host(self, user_id: int | None) -> bool:
        """The ONE host-permission check: is this user the effective host?"""
        return user_id is not None and user_id == self.effective_host_id


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
    # The member's table token (apps.core.tokens), assigned under the Lobby row
    # lock when they join; "" for a row made by code that predates tokens (the
    # database default keeps that code's INSERTs working during a rollout) and
    # given one at the deal.
    token = models.CharField(max_length=16, blank=True, default="", db_default="")
    # When this member was noticed to have no open lobby socket (see
    # apps.core.presence); used only to decide host handover.
    disconnected_at = models.DateTimeField(null=True, blank=True)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["lobby", "user"], name="unique_lobby_member"
            ),
            models.UniqueConstraint(
                fields=["lobby", "token"],
                condition=~models.Q(token=""),
                name="unique_lobby_token",
            ),
        ]
        # Join order (seat order); the id breaks a tie in the timestamp.
        ordering = ("joined_at", "id")

    def __str__(self) -> str:
        return f"{self.user.username} in {self.lobby.code}"


class LobbySocket(models.Model):
    """
    One row per open LOBBY WebSocket (see ``apps.core.presence``).

    Inserted on connect, deleted on a clean disconnect, ``last_seen`` refreshed by
    the consumer's heartbeat; a member is *connected* to the lobby while a row
    was seen within the staleness timeout. Used only for host handover.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="lobby_sockets",
    )
    lobby = models.ForeignKey(Lobby, on_delete=models.CASCADE, related_name="sockets")
    channel_name = models.CharField(max_length=255, unique=True)
    connected_at = models.DateTimeField()
    last_seen = models.DateTimeField()

    class Meta:
        indexes = [
            models.Index(fields=["lobby", "user"], name="core_lobbysock_lobby_user_idx")
        ]

    def __str__(self) -> str:
        return f"{self.user_id} on lobby {self.lobby_id} ({self.channel_name[-8:]})"


class ScheduledTimer(models.Model):
    """
    A durable named timer (see ``apps.core.timers``).

    One row per key. ``schedule`` upserts the row with a fresh ``token``; a
    firing (from a thread timer or a queue message, which both carry only
    ``key`` and ``token``) runs the job only if the row still exists with the
    same token and is due, and deletes the row in the same transaction that
    claims it, so stale, cancelled and duplicate deliveries do nothing and two
    instances cannot both run it.
    """

    key = models.CharField(max_length=200, unique=True)
    token = models.CharField(max_length=64)
    job = models.CharField(max_length=64)
    params = models.JSONField(default=dict, blank=True)
    # All three are written with the DATABASE clock (Now()), never an instance
    # clock, so instances with skewed clocks agree on what is due.
    due_at = models.DateTimeField(db_index=True)
    scheduled_at = models.DateTimeField(default=timezone.now)
    published_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text=(
            "When the firing was handed to the backend (queue message sent / "
            "thread armed). None = the row exists but nothing is known to fire "
            "it: the sweep or the lazy repair publishes it again."
        ),
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return f"{self.key} -> {self.job} at {self.due_at:%H:%M:%S}"
