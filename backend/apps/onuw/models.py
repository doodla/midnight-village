"""ONUW game models."""

import uuid

from django.conf import settings
from django.db import models
from django.db.models import Value


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
    # Despite its name (kept: renaming it, or changing its help_text, would be a
    # migration), this is "when the stage open now opened": the look stage, each
    # night window, the talk and the vote set it when they open. GET /me/'s
    # ``stage_started_at`` reads it; the night's minimum-length rule reads it only
    # inside a night window.
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
    # pyrefly: ignore [no-matching-overload]  (the stubs lack JSONField db_default)
    dealt_center_cards = models.JSONField(
        default=list,
        db_default=Value([], output_field=models.JSONField()),
        blank=True,
        help_text="The 3 center cards as dealt; never changed (empty: dealt before this)",
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
    # Table identity, copied from the LobbyMember at the deal and never changed,
    # so a game stays stable even if the member later leaves the lobby.
    token = models.CharField(max_length=16, blank=True, default="", db_default="")
    seat = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        help_text="Join order at the deal (0-based); None for games dealt before seats",
    )
    phase_ready = models.BooleanField(
        default=False,
        db_default=False,
        help_text='"Looked at my card" (night, window 0) / "ready to vote" (talk)',
    )
    night_results_seen = models.PositiveSmallIntegerField(
        default=0,
        db_default=0,
        help_text="How many of the player's night results they have acknowledged",
    )
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
        # Players come back in seat order everywhere (legacy rows: by user id).
        ordering = ("seat", "user_id")

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
