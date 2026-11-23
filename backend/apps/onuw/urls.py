"""ONUW app URL configuration."""

from django.urls import path

from apps.core.views import LobbyPlayAgainView

from . import debug_views, views, views_play, views_read

app_name = "onuw"

urlpatterns = [
    path(
        "lobbies/<str:code>/start/",
        views.GameStartView.as_view(),
        name="game-start",
    ),
    # Same view as core's lobbies/<code>/play-again/, under the ONUW prefix next
    # to "start" so a client may use either.
    path(
        "lobbies/<str:code>/play-again/",
        LobbyPlayAgainView.as_view(),
        name="lobby-play-again",
    ),
    # Platform cron: re-publish lost timers (shared-secret protected).
    path(
        "internal/sweep-timers/",
        views.SweepTimersView.as_view(),
        name="sweep-timers",
    ),
    path(
        "me/current-game/",
        views_read.CurrentGameView.as_view(),
        name="current-game",
    ),
    path(
        "me/recent-games/",
        views_read.RecentGamesView.as_view(),
        name="recent-games",
    ),
    path(
        "games/<str:game_id>/me/",
        views.GameMeView.as_view(),
        name="game-me",
    ),
    path(
        "games/<str:game_id>/players/",
        views_read.PlayerListView.as_view(),
        name="player-list",
    ),
    path(
        "games/<str:game_id>/action/",
        views_play.NightActionView.as_view(),
        name="night-action",
    ),
    path(
        "games/<str:game_id>/night-results/seen/",
        views_play.NightResultsSeenView.as_view(),
        name="night-results-seen",
    ),
    path(
        "games/<str:game_id>/advance-wave/",
        views_play.WaveAdvanceView.as_view(),
        name="wave-advance",
    ),
    path(
        "games/<str:game_id>/end-discussion/",
        views_play.EndDiscussionView.as_view(),
        name="end-discussion",
    ),
    path(
        "games/<str:game_id>/ready/",
        views_play.ReadyView.as_view(),
        name="ready",
    ),
    path(
        "games/<str:game_id>/vote/",
        views_play.VoteView.as_view(),
        name="vote",
    ),
    path(
        "games/<str:game_id>/reveal-votes/",
        views_play.ForceRevealView.as_view(),
        name="reveal-votes",
    ),
    path(
        "games/<str:game_id>/results/",
        views_read.ResultsView.as_view(),
        name="results",
    ),
    # DEBUG-gated developer-harness surfaces. Both return 403 when
    # settings.DEBUG is False (see apps.onuw.debug.debug_disabled_response).
    path(
        "games/<str:game_id>/debug-state/",
        debug_views.DebugStateView.as_view(),
        name="debug-state",
    ),
    path(
        "games/<str:game_id>/debug-fire-timer/",
        debug_views.DebugFireTimerView.as_view(),
        name="debug-fire-timer",
    ),
]
