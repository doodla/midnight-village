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
]
