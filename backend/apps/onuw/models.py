"""ONUW game models."""

import uuid

from django.conf import settings
from django.db import models


class Phase(models.TextChoices):
    """Game phases for One Night Ultimate Werewolf."""

    LOBBY = "lobby", "Lobby"
    NIGHT = "night", "Night"
    DISCUSSION = "discussion", "Discussion"
    VOTING = "voting", "Voting"
    RESULTS = "results", "Results"


class Game(models.Model):
    """
    A single ONUW game instance.

    Created when a lobby host starts the game. Tracks the full game lifecycle
    from night phase through to results.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    # A table (lobby) can hold many games over a night: "play again" deals a new
    # Game on the same lobby. The lobby's current game is its newest one.
    lobby = models.ForeignKey(
        "core.Lobby",
        on_delete=models.CASCADE,
        related_name="games",
    )
    phase = models.CharField(
        max_length=20,
        choices=Phase.choices,
        default=Phase.LOBBY,
    )
    phase_deadline = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the current phase timer expires; None for untimed phases",
    )
    current_wave = models.PositiveIntegerField(
        default=0,
        help_text=(
            "0 = not in night phase, 1-2 = active night window "
            "(1 = Doppelganger, 2 = everyone else at once)"
        ),
    )
    night_window_opened_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the current night window opened; enforces the minimum length",
    )
    random_seed = models.BigIntegerField()
    night_actions_log = models.JSONField(default=list, blank=True)
    settings = models.JSONField(
        default=dict,
        blank=True,
        help_text="Copied from lobby settings at game start",
    )
    center_cards = models.JSONField(
        default=list,
        blank=True,
        help_text="3 center cards (role names)",
    )
    results = models.JSONField(
        default=dict,
        blank=True,
        help_text="Filled at results phase with winners, votes, etc.",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self) -> str:
        return f"Game {self.id} ({self.phase})"


class PlayerRole(models.Model):
    """
    A player's role assignment in a specific game.

    Tracks both the original role dealt and the current role (which may change
    due to Robber, Troublemaker, or Drunk swaps during the night phase).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    game = models.ForeignKey(
        Game,
        on_delete=models.CASCADE,
        related_name="player_roles",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="onuw_roles",
    )
    original_role = models.CharField(max_length=50)
    current_role = models.CharField(max_length=50)
    night_action_data = models.JSONField(
        default=dict,
        blank=True,
        help_text="Results of night action (peek results, swap info, etc.)",
    )
    vote_target = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="voted_by",
    )
    has_acted = models.BooleanField(default=False)
    disconnected_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text=(
            "When the player was noticed to have no open socket (last socket "
            "closed, or its heartbeat went stale); None while connected or if "
            "they were never seen disconnected. Whether they are connected NOW "
            "comes from SocketPresence rows."
        ),
    )

    class Meta:
        unique_together = (("game", "user"),)

    def __str__(self) -> str:
        return f"{self.user} as {self.original_role} in {self.game_id}"


class SocketPresence(models.Model):
    """
    One row per open GAME WebSocket.

    Inserted on connect, deleted on a clean disconnect, and ``last_seen`` is
    refreshed by the consumer's heartbeat. A user is *connected* to the game
    while at least one of their rows has a ``last_seen`` inside the staleness
    timeout (``ONUW_PRESENCE_STALE_SECONDS``). A row whose heartbeat stops
    (instance killed, no ``disconnect``) simply goes stale; a durable
    ``presence_check`` timer notices it. Nothing here is ever reset at server
    start. (Lobby sockets are ``apps.core.models.LobbySocket``.)
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="socket_presences",
    )
    game = models.ForeignKey(Game, on_delete=models.CASCADE, related_name="sockets")
    channel_name = models.CharField(max_length=255, unique=True)
    connected_at = models.DateTimeField()
    last_seen = models.DateTimeField()

    class Meta:
        indexes = [models.Index(fields=["game", "user"])]

    def __str__(self) -> str:
        return f"{self.user_id} on game {self.game_id} ({self.channel_name[-8:]})"
