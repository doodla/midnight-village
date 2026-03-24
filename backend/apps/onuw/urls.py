"""ONUW app URL configuration."""

from django.urls import path

from . import views

app_name = "onuw"

urlpatterns = [
    path(
        "lobbies/<str:code>/start/",
        views.GameStartView.as_view(),
        name="game-start",
    ),
    path(
        "games/<str:game_id>/me/",
        views.GameMeView.as_view(),
        name="game-me",
    ),
    path(
        "games/<str:game_id>/action/",
        views.NightActionView.as_view(),
        name="night-action",
    ),
    path(
        "games/<str:game_id>/advance-wave/",
        views.WaveAdvanceView.as_view(),
        name="wave-advance",
    ),
    path(
        "games/<str:game_id>/end-discussion/",
        views.EndDiscussionView.as_view(),
        name="end-discussion",
    ),
    path(
        "games/<str:game_id>/vote/",
        views.VoteView.as_view(),
        name="vote",
    ),
    path(
        "games/<str:game_id>/reveal-votes/",
        views.ForceRevealView.as_view(),
        name="reveal-votes",
    ),
]
