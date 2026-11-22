"""
Core app URL configuration.
"""

from django.urls import path

from rest_framework_simplejwt.views import TokenObtainPairView

from . import views
from .auth import AccountTokenRefreshView

app_name = "core"

urlpatterns = [
    path("health/", views.health_check, name="health-check"),
    path("auth/token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path(
        "auth/token/refresh/", AccountTokenRefreshView.as_view(), name="token_refresh"
    ),
    path("auth/guest/", views.GuestCreateView.as_view(), name="guest-create"),
    path("lobbies/", views.LobbyCreateView.as_view(), name="lobby-list"),
    path("lobbies/<str:code>/", views.LobbyDetailView.as_view(), name="lobby-detail"),
    path("lobbies/<str:code>/join/", views.LobbyJoinView.as_view(), name="lobby-join"),
    path(
        "lobbies/<str:code>/leave/", views.LobbyLeaveView.as_view(), name="lobby-leave"
    ),
    path(
        "lobbies/<str:code>/play-again/",
        views.LobbyPlayAgainView.as_view(),
        name="lobby-play-again",
    ),
    path(
        "lobbies/<str:code>/practice/",
        views.LobbyPracticeView.as_view(),
        name="lobby-practice",
    ),
    path("stats/online/", views.OnlineStatsView.as_view(), name="online-stats"),
    path("me/table/", views.MyTableView.as_view(), name="my-table"),
    path("auth/logout/", views.LogoutView.as_view(), name="logout"),
]
