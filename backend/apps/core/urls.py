"""
Core app URL configuration.
"""

from django.urls import path

from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from . import views

app_name = "core"

urlpatterns = [
    path("health/", views.health_check, name="health-check"),
    path("auth/token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("auth/guest/", views.GuestCreateView.as_view(), name="guest-create"),
    path("lobbies/", views.LobbyCreateView.as_view(), name="lobby-list"),
    path("lobbies/<str:code>/", views.LobbyDetailView.as_view(), name="lobby-detail"),
    path("lobbies/<str:code>/join/", views.LobbyJoinView.as_view(), name="lobby-join"),
    path(
        "lobbies/<str:code>/leave/", views.LobbyLeaveView.as_view(), name="lobby-leave"
    ),
    path(
        "lobbies/<str:code>/ready/", views.LobbyReadyView.as_view(), name="lobby-ready"
    ),
    path("auth/logout/", views.LogoutView.as_view(), name="logout"),
]
