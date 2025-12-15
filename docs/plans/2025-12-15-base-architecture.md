# Base Architecture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Set up the foundational infrastructure for Midnight Village: JWT authentication, generic lobby system, and WebSocket support.

**Architecture:** `apps.core` provides shared infrastructure (auth, lobbies, WebSockets) that game-specific apps will build on. Lobbies are generic containers; game apps extend them with their own configuration.

**Tech Stack:** Django Channels (WebSockets), Redis (channel layer), djangorestframework-simplejwt (JWT auth)

---

## Task 1: Add Dependencies

**Files:**
- Modify: `backend/pyproject.toml`

**Step 1: Add channels, redis, and JWT dependencies**

Add to the `dependencies` list in `pyproject.toml`:

```toml
dependencies = [
    "django>=5.2",
    "djangorestframework>=3.15.2",
    "psycopg[binary]>=3.1.8",
    "psycopg-pool>=3.2.0",
    "python-dotenv>=1.0.0",
    "gunicorn>=23.0.0",
    "channels>=4.0.0",
    "channels-redis>=4.2.0",
    "djangorestframework-simplejwt>=5.3.0",
]
```

Add to the `dev` dependency group:

```toml
dev = [
    "pytest>=8.0.0",
    "pytest-django>=4.8.0",
    "pytest-cov>=4.1.0",
    "model-bakery>=1.18.0",
    "pyrefly>=0.44.0",
    "pytest-asyncio>=0.23.0",
]
```

**Step 2: Install dependencies**

Run: `cd backend && uv sync`
Expected: Dependencies install successfully

**Step 3: Commit**

```bash
git add backend/pyproject.toml backend/uv.lock
git commit -m "deps: add channels, redis, and JWT dependencies"
```

---

## Task 2: Configure Django Channels

**Files:**
- Modify: `backend/config/settings/base.py`
- Modify: `backend/config/asgi.py`
- Create: `backend/apps/core/routing.py`

**Step 1: Add channels to INSTALLED_APPS**

In `backend/config/settings/base.py`, update INSTALLED_APPS:

```python
INSTALLED_APPS = [
    "daphne",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third-party
    "channels",
    "rest_framework",
    "rest_framework_simplejwt",
    # Local
    "apps.core",
]
```

Add at the end of `base.py`:

```python
# Channels configuration
ASGI_APPLICATION = "config.asgi.application"

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    },
}
```

**Step 2: Create routing file**

Create `backend/apps/core/routing.py`:

```python
"""WebSocket URL routing for core app."""

from django.urls import path

websocket_urlpatterns: list = []
```

**Step 3: Update ASGI configuration**

Replace `backend/config/asgi.py` with:

```python
"""
ASGI config for Midnight Village.

Configures both HTTP and WebSocket protocol routing.
"""

import os

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")

# Initialize Django ASGI application early to ensure the AppRegistry
# is populated before importing code that may import ORM models.
django_asgi_app = get_asgi_application()

from apps.core.routing import websocket_urlpatterns

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": AllowedHostsOriginValidator(
            URLRouter(websocket_urlpatterns)
        ),
    }
)
```

**Step 4: Verify Django starts**

Run: `cd backend && uv run python manage.py check`
Expected: System check identified no issues

**Step 5: Commit**

```bash
git add backend/config/settings/base.py backend/config/asgi.py backend/apps/core/routing.py
git commit -m "feat(core): configure Django Channels with ASGI routing"
```

---

## Task 3: Configure JWT Authentication

**Files:**
- Modify: `backend/config/settings/base.py`
- Modify: `backend/apps/core/urls.py`
- Create: `backend/tests/core/test_auth.py`

**Step 1: Write failing test for token endpoint**

Create `backend/tests/core/test_auth.py`:

```python
"""Tests for JWT authentication endpoints."""

import pytest
from django.urls import reverse
from rest_framework import status


@pytest.mark.integration
class TestTokenEndpoints:
    """Test JWT token obtain and refresh endpoints."""

    def test_obtain_token_with_valid_credentials(self, api_client, user):
        """Users can obtain JWT tokens with valid credentials."""
        url = reverse("token_obtain_pair")
        response = api_client.post(
            url,
            {"username": "testuser", "password": "testpass123"},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert "access" in response.data
        assert "refresh" in response.data

    def test_obtain_token_with_invalid_credentials(self, api_client):
        """Invalid credentials return 401."""
        url = reverse("token_obtain_pair")
        response = api_client.post(
            url,
            {"username": "wrong", "password": "wrong"},
            format="json",
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_refresh_token(self, api_client, user):
        """Users can refresh their access token."""
        # First obtain tokens
        obtain_url = reverse("token_obtain_pair")
        response = api_client.post(
            obtain_url,
            {"username": "testuser", "password": "testpass123"},
            format="json",
        )
        refresh_token = response.data["refresh"]

        # Then refresh
        refresh_url = reverse("token_refresh")
        response = api_client.post(
            refresh_url,
            {"refresh": refresh_token},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert "access" in response.data
```

**Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/core/test_auth.py -v`
Expected: FAIL with "NoReverseMatch" (URL not configured)

**Step 3: Configure JWT settings**

Add to `backend/config/settings/base.py` after REST_FRAMEWORK:

```python
# JWT Configuration
from datetime import timedelta

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=60),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": False,
    "AUTH_HEADER_TYPES": ("Bearer",),
}
```

Update REST_FRAMEWORK authentication:

```python
REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
    ],
    "EXCEPTION_HANDLER": "apps.core.exceptions.custom_exception_handler",
}
```

**Step 4: Add JWT URLs**

Update `backend/apps/core/urls.py`:

```python
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
]
```

**Step 5: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/core/test_auth.py -v`
Expected: All 3 tests PASS

**Step 6: Commit**

```bash
git add backend/config/settings/base.py backend/apps/core/urls.py backend/tests/core/test_auth.py
git commit -m "feat(core): add JWT authentication endpoints"
```

---

## Task 4: Create Lobby Model

**Files:**
- Modify: `backend/apps/core/models.py`
- Create: `backend/tests/core/test_lobby_model.py`

**Step 1: Write failing test for Lobby model**

Create `backend/tests/core/test_lobby_model.py`:

```python
"""Unit tests for Lobby model."""

import pytest


@pytest.mark.unit
class TestLobbyModel:
    """Test Lobby model behavior."""

    def test_lobby_generates_unique_code_on_create(self, db):
        """Lobby generates a 6-character code when created."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        assert lobby.code is not None
        assert len(lobby.code) == 6
        assert lobby.code.isalnum()

    def test_lobby_code_is_unique(self, db):
        """Each lobby gets a unique code."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        lobby1 = Lobby.objects.create(host=host, game_type="onuw")
        lobby2 = Lobby.objects.create(host=host, game_type="onuw")

        assert lobby1.code != lobby2.code

    def test_lobby_default_status_is_waiting(self, db):
        """New lobbies have 'waiting' status."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        assert lobby.status == "waiting"

    def test_lobby_str_representation(self, db):
        """Lobby string representation includes code and game type."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        assert lobby.code in str(lobby)
        assert "onuw" in str(lobby)
```

**Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/core/test_lobby_model.py -v`
Expected: FAIL with "ImportError" or "AttributeError" (Lobby doesn't exist)

**Step 3: Implement Lobby model**

Update `backend/apps/core/models.py`:

```python
"""Core models for Midnight Village."""

import secrets
import string

from django.conf import settings
from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    """Custom User model for Midnight Village."""

    pass


def generate_lobby_code() -> str:
    """Generate a unique 6-character alphanumeric lobby code."""
    alphabet = string.ascii_uppercase + string.digits
    # Remove ambiguous characters (0, O, I, 1, L)
    alphabet = alphabet.replace("0", "").replace("O", "").replace("I", "").replace("1", "").replace("L", "")
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

    def __str__(self) -> str:
        return f"Lobby {self.code} ({self.game_type})"
```

**Step 4: Create and run migration**

Run: `cd backend && uv run python manage.py makemigrations core`
Expected: Migration created for Lobby model

Run: `cd backend && uv run python manage.py migrate`
Expected: Migration applied successfully

**Step 5: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/core/test_lobby_model.py -v`
Expected: All 4 tests PASS

**Step 6: Commit**

```bash
git add backend/apps/core/models.py backend/apps/core/migrations/ backend/tests/core/test_lobby_model.py
git commit -m "feat(core): add Lobby model with auto-generated room codes"
```

---

## Task 5: Create LobbyPlayer Model

**Files:**
- Modify: `backend/apps/core/models.py`
- Create: `backend/tests/core/test_lobby_player_model.py`

**Step 1: Write failing test for LobbyPlayer model**

Create `backend/tests/core/test_lobby_player_model.py`:

```python
"""Unit tests for LobbyPlayer model."""

import pytest


@pytest.mark.unit
class TestLobbyPlayerModel:
    """Test LobbyPlayer model behavior."""

    def test_player_can_join_lobby(self, db):
        """A user can join a lobby as a player."""
        from apps.core.models import Lobby, LobbyPlayer, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        lobby_player = LobbyPlayer.objects.create(lobby=lobby, user=player)

        assert lobby_player.lobby == lobby
        assert lobby_player.user == player
        assert lobby_player.is_ready is False

    def test_player_cannot_join_same_lobby_twice(self, db):
        """A user cannot join the same lobby twice."""
        from django.db import IntegrityError

        from apps.core.models import Lobby, LobbyPlayer, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        LobbyPlayer.objects.create(lobby=lobby, user=player)

        with pytest.raises(IntegrityError):
            LobbyPlayer.objects.create(lobby=lobby, user=player)

    def test_players_ordered_by_join_time(self, db):
        """Players are ordered by when they joined."""
        from apps.core.models import Lobby, LobbyPlayer, User

        host = User.objects.create_user(username="host", password="pass")
        player1 = User.objects.create_user(username="player1", password="pass")
        player2 = User.objects.create_user(username="player2", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        lp1 = LobbyPlayer.objects.create(lobby=lobby, user=player1)
        lp2 = LobbyPlayer.objects.create(lobby=lobby, user=player2)

        players = list(lobby.players.all())
        assert players[0] == lp1
        assert players[1] == lp2
```

**Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/core/test_lobby_player_model.py -v`
Expected: FAIL with "ImportError" (LobbyPlayer doesn't exist)

**Step 3: Implement LobbyPlayer model**

Add to `backend/apps/core/models.py` after the Lobby class:

```python
class LobbyPlayer(models.Model):
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
        unique_together = [("lobby", "user")]
        ordering = ["joined_at"]

    def __str__(self) -> str:
        return f"{self.user.username} in {self.lobby.code}"
```

**Note:** The host is added as a player at the view layer when creating a lobby, not in `Lobby.save()`. This keeps the model simple and avoids side effects in save methods.

**Step 4: Create and run migration**

Run: `cd backend && uv run python manage.py makemigrations core`
Expected: Migration created for LobbyPlayer model

Run: `cd backend && uv run python manage.py migrate`
Expected: Migration applied successfully

**Step 5: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/core/test_lobby_player_model.py -v`
Expected: All 3 tests PASS

**Step 6: Commit**

```bash
git add backend/apps/core/models.py backend/apps/core/migrations/ backend/tests/core/test_lobby_player_model.py
git commit -m "feat(core): add LobbyPlayer model for lobby membership"
```

---

## Task 6: Lobby REST API - Create and Get

**Files:**
- Modify: `backend/apps/core/serializers.py`
- Modify: `backend/apps/core/views.py`
- Modify: `backend/apps/core/urls.py`
- Create: `backend/tests/core/test_lobby_api.py`

**Step 1: Write failing tests for create and get lobby**

Create `backend/tests/core/test_lobby_api.py`:

```python
"""Integration tests for Lobby API endpoints."""

import pytest
from django.urls import reverse
from rest_framework import status


@pytest.mark.integration
class TestCreateLobby:
    """Test lobby creation endpoint."""

    def test_authenticated_user_can_create_lobby(self, authenticated_client):
        """Authenticated users can create a new lobby."""
        url = reverse("core:lobby-list")
        response = authenticated_client.post(
            url,
            {"game_type": "onuw", "max_players": 8},
            format="json",
        )

        assert response.status_code == status.HTTP_201_CREATED
        assert "code" in response.data
        assert len(response.data["code"]) == 6
        assert response.data["game_type"] == "onuw"
        assert response.data["status"] == "waiting"

    def test_unauthenticated_user_cannot_create_lobby(self, api_client):
        """Unauthenticated users cannot create lobbies."""
        url = reverse("core:lobby-list")
        response = api_client.post(
            url,
            {"game_type": "onuw"},
            format="json",
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.integration
class TestGetLobby:
    """Test lobby retrieval endpoints."""

    def test_get_lobby_by_code(self, authenticated_client, user):
        """Users can retrieve a lobby by its code."""
        from apps.core.models import Lobby

        lobby = Lobby.objects.create(host=user, game_type="onuw")

        url = reverse("core:lobby-detail", kwargs={"code": lobby.code})
        response = authenticated_client.get(url)

        assert response.status_code == status.HTTP_200_OK
        assert response.data["code"] == lobby.code
        assert response.data["game_type"] == "onuw"
        assert "players" in response.data
        assert len(response.data["players"]) == 1  # Host auto-joined

    def test_get_nonexistent_lobby_returns_404(self, authenticated_client):
        """Requesting a nonexistent lobby returns 404."""
        url = reverse("core:lobby-detail", kwargs={"code": "XXXXXX"})
        response = authenticated_client.get(url)

        assert response.status_code == status.HTTP_404_NOT_FOUND
```

**Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/core/test_lobby_api.py -v`
Expected: FAIL with "NoReverseMatch" (URLs not configured)

**Step 3: Create serializers**

Update `backend/apps/core/serializers.py`:

```python
"""Core app serializers."""

from rest_framework import serializers

from .models import Lobby, LobbyPlayer, User


class UserBriefSerializer(serializers.ModelSerializer):
    """Brief user info for embedding in other serializers."""

    class Meta:
        model = User
        fields = ["id", "username"]


class LobbyPlayerSerializer(serializers.ModelSerializer):
    """Serializer for lobby players."""

    user = UserBriefSerializer(read_only=True)

    class Meta:
        model = LobbyPlayer
        fields = ["user", "is_ready", "joined_at"]


class LobbySerializer(serializers.ModelSerializer):
    """Serializer for Lobby model."""

    players = LobbyPlayerSerializer(many=True, read_only=True)
    host = UserBriefSerializer(read_only=True)

    class Meta:
        model = Lobby
        fields = [
            "code",
            "host",
            "game_type",
            "status",
            "max_players",
            "settings",
            "players",
            "created_at",
        ]
        read_only_fields = ["code", "host", "status", "created_at"]


class LobbyCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating a lobby."""

    class Meta:
        model = Lobby
        fields = ["game_type", "max_players", "settings"]
        extra_kwargs = {
            "max_players": {"required": False},
            "settings": {"required": False},
        }
```

**Step 4: Create views**

Update `backend/apps/core/views.py`:

```python
"""
Core app views.
"""

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import CreateAPIView, RetrieveAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from .models import Lobby, LobbyPlayer
from .serializers import LobbyCreateSerializer, LobbySerializer


@api_view(["GET"])
@permission_classes([AllowAny])
def health_check(request: Request) -> Response:
    """
    Health check endpoint for monitoring and load balancer probes.

    Returns:
        Response: JSON response with status "ok"
    """
    return Response({"status": "ok"}, status=status.HTTP_200_OK)


class LobbyCreateView(CreateAPIView):
    """Create a new lobby."""

    serializer_class = LobbyCreateSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        lobby = serializer.save(host=self.request.user)
        # Add host as first player
        LobbyPlayer.objects.create(lobby=lobby, user=self.request.user)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)

        # Return full lobby data
        lobby = serializer.instance
        output_serializer = LobbySerializer(lobby)
        return Response(output_serializer.data, status=status.HTTP_201_CREATED)


class LobbyDetailView(RetrieveAPIView):
    """Retrieve a lobby by code."""

    serializer_class = LobbySerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "code"
    queryset = Lobby.objects.all()
```

**Step 5: Add URLs**

Update `backend/apps/core/urls.py`:

```python
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
    path("lobbies/", views.LobbyCreateView.as_view(), name="lobby-list"),
    path("lobbies/<str:code>/", views.LobbyDetailView.as_view(), name="lobby-detail"),
]
```

**Step 6: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/core/test_lobby_api.py -v`
Expected: All 4 tests PASS

**Step 7: Commit**

```bash
git add backend/apps/core/serializers.py backend/apps/core/views.py backend/apps/core/urls.py backend/tests/core/test_lobby_api.py
git commit -m "feat(core): add lobby create and retrieve API endpoints"
```

---

## Task 7: Lobby REST API - Join and Leave

**Files:**
- Modify: `backend/apps/core/views.py`
- Modify: `backend/apps/core/urls.py`
- Modify: `backend/tests/core/test_lobby_api.py`

**Step 1: Write failing tests for join and leave**

Add to `backend/tests/core/test_lobby_api.py`:

```python
@pytest.mark.integration
class TestJoinLobby:
    """Test lobby join endpoint."""

    def test_user_can_join_lobby_by_code(self, api_client, db):
        """Users can join an existing lobby."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        api_client.force_authenticate(user=player)
        url = reverse("core:lobby-join", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_200_OK
        assert len(response.data["players"]) == 2

    def test_user_cannot_join_full_lobby(self, api_client, db):
        """Users cannot join a lobby that is full."""
        from apps.core.models import Lobby, LobbyPlayer, User

        host = User.objects.create_user(username="host", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw", max_players=2)

        # Add another player to fill the lobby
        player1 = User.objects.create_user(username="player1", password="pass")
        LobbyPlayer.objects.create(lobby=lobby, user=player1)

        # Try to join as third player
        player2 = User.objects.create_user(username="player2", password="pass")
        api_client.force_authenticate(user=player2)
        url = reverse("core:lobby-join", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_user_cannot_join_lobby_twice(self, authenticated_client, user):
        """Users cannot join a lobby they're already in."""
        from apps.core.models import Lobby

        lobby = Lobby.objects.create(host=user, game_type="onuw")

        url = reverse("core:lobby-join", kwargs={"code": lobby.code})
        response = authenticated_client.post(url)

        assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.integration
class TestLeaveLobby:
    """Test lobby leave endpoint."""

    def test_player_can_leave_lobby(self, api_client, db):
        """Players can leave a lobby."""
        from apps.core.models import Lobby, LobbyPlayer, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")
        LobbyPlayer.objects.create(lobby=lobby, user=player)

        api_client.force_authenticate(user=player)
        url = reverse("core:lobby-leave", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_200_OK
        assert not LobbyPlayer.objects.filter(lobby=lobby, user=player).exists()

    def test_host_leaving_deletes_lobby(self, authenticated_client, user):
        """When the host leaves, the lobby is deleted."""
        from apps.core.models import Lobby

        lobby = Lobby.objects.create(host=user, game_type="onuw")
        lobby_code = lobby.code

        url = reverse("core:lobby-leave", kwargs={"code": lobby.code})
        response = authenticated_client.post(url)

        assert response.status_code == status.HTTP_200_OK
        assert not Lobby.objects.filter(code=lobby_code).exists()
```

**Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/core/test_lobby_api.py::TestJoinLobby -v`
Expected: FAIL with "NoReverseMatch"

**Step 3: Implement join and leave views**

Add to `backend/apps/core/views.py`:

```python
from rest_framework.views import APIView
from .models import Lobby, LobbyPlayer


class LobbyJoinView(APIView):
    """Join an existing lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        try:
            lobby = Lobby.objects.get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Check if already in lobby
        if LobbyPlayer.objects.filter(lobby=lobby, user=request.user).exists():
            return Response(
                {"detail": "You are already in this lobby."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Check if lobby is full
        if lobby.players.count() >= lobby.max_players:
            return Response(
                {"detail": "Lobby is full."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Check if lobby is still accepting players
        if lobby.status != Lobby.Status.WAITING:
            return Response(
                {"detail": "Lobby is not accepting players."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        LobbyPlayer.objects.create(lobby=lobby, user=request.user)

        serializer = LobbySerializer(lobby)
        return Response(serializer.data, status=status.HTTP_200_OK)


class LobbyLeaveView(APIView):
    """Leave a lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        try:
            lobby = Lobby.objects.get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Check if user is in lobby
        try:
            lobby_player = LobbyPlayer.objects.get(lobby=lobby, user=request.user)
        except LobbyPlayer.DoesNotExist:
            return Response(
                {"detail": "You are not in this lobby."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # If host leaves, delete the lobby
        if lobby.host == request.user:
            lobby.delete()
            return Response({"detail": "Lobby deleted."}, status=status.HTTP_200_OK)

        # Otherwise just remove the player
        lobby_player.delete()
        return Response({"detail": "Left lobby."}, status=status.HTTP_200_OK)
```

**Step 4: Add URLs**

Update `backend/apps/core/urls.py`:

```python
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
    path("lobbies/", views.LobbyCreateView.as_view(), name="lobby-list"),
    path("lobbies/<str:code>/", views.LobbyDetailView.as_view(), name="lobby-detail"),
    path("lobbies/<str:code>/join/", views.LobbyJoinView.as_view(), name="lobby-join"),
    path("lobbies/<str:code>/leave/", views.LobbyLeaveView.as_view(), name="lobby-leave"),
]
```

**Step 5: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/core/test_lobby_api.py -v`
Expected: All 9 tests PASS

**Step 6: Commit**

```bash
git add backend/apps/core/views.py backend/apps/core/urls.py backend/tests/core/test_lobby_api.py
git commit -m "feat(core): add lobby join and leave API endpoints"
```

---

## Task 8: Lobby Ready State

**Files:**
- Modify: `backend/apps/core/views.py`
- Modify: `backend/apps/core/urls.py`
- Modify: `backend/tests/core/test_lobby_api.py`

**Step 1: Write failing tests for ready toggle**

Add to `backend/tests/core/test_lobby_api.py`:

```python
@pytest.mark.integration
class TestLobbyReady:
    """Test lobby ready state endpoint."""

    def test_player_can_toggle_ready(self, api_client, db):
        """Players can toggle their ready state."""
        from apps.core.models import Lobby, LobbyPlayer, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")
        LobbyPlayer.objects.create(lobby=lobby, user=player)

        api_client.force_authenticate(user=player)
        url = reverse("core:lobby-ready", kwargs={"code": lobby.code})

        # Toggle to ready
        response = api_client.post(url, {"is_ready": True}, format="json")
        assert response.status_code == status.HTTP_200_OK

        player_in_lobby = LobbyPlayer.objects.get(lobby=lobby, user=player)
        assert player_in_lobby.is_ready is True

        # Toggle to not ready
        response = api_client.post(url, {"is_ready": False}, format="json")
        assert response.status_code == status.HTTP_200_OK

        player_in_lobby.refresh_from_db()
        assert player_in_lobby.is_ready is False

    def test_non_member_cannot_ready(self, api_client, db):
        """Users not in lobby cannot set ready state."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        outsider = User.objects.create_user(username="outsider", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        api_client.force_authenticate(user=outsider)
        url = reverse("core:lobby-ready", kwargs={"code": lobby.code})
        response = api_client.post(url, {"is_ready": True}, format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
```

**Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/core/test_lobby_api.py::TestLobbyReady -v`
Expected: FAIL with "NoReverseMatch"

**Step 3: Implement ready view**

Add to `backend/apps/core/views.py`:

```python
class LobbyReadyView(APIView):
    """Toggle ready state for a player in a lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        try:
            lobby = Lobby.objects.get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            lobby_player = LobbyPlayer.objects.get(lobby=lobby, user=request.user)
        except LobbyPlayer.DoesNotExist:
            return Response(
                {"detail": "You are not in this lobby."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        is_ready = request.data.get("is_ready", not lobby_player.is_ready)
        lobby_player.is_ready = is_ready
        lobby_player.save()

        serializer = LobbySerializer(lobby)
        return Response(serializer.data, status=status.HTTP_200_OK)
```

**Step 4: Add URL**

Add to `backend/apps/core/urls.py` urlpatterns:

```python
path("lobbies/<str:code>/ready/", views.LobbyReadyView.as_view(), name="lobby-ready"),
```

**Step 5: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/core/test_lobby_api.py::TestLobbyReady -v`
Expected: All 2 tests PASS

**Step 6: Commit**

```bash
git add backend/apps/core/views.py backend/apps/core/urls.py backend/tests/core/test_lobby_api.py
git commit -m "feat(core): add lobby ready state toggle endpoint"
```

---

## Task 9: WebSocket Lobby Consumer

**Files:**
- Create: `backend/apps/core/consumers.py`
- Modify: `backend/apps/core/routing.py`
- Create: `backend/tests/core/test_lobby_websocket.py`

**Step 1: Write failing test for WebSocket connection**

Create `backend/tests/core/test_lobby_websocket.py`:

```python
"""Integration tests for Lobby WebSocket consumer."""

import pytest
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator

from config.asgi import application


@database_sync_to_async
def create_lobby_with_user():
    """Create a lobby and return the code and user."""
    from apps.core.models import Lobby, User

    user = User.objects.create_user(username="wsuser", password="pass")
    lobby = Lobby.objects.create(host=user, game_type="onuw")
    return lobby.code, user


@pytest.mark.asyncio
@pytest.mark.integration
class TestLobbyWebSocket:
    """Test Lobby WebSocket consumer."""

    async def test_connect_to_lobby(self, db):
        """Users can connect to a lobby WebSocket."""
        code, user = await create_lobby_with_user()

        communicator = WebsocketCommunicator(
            application,
            f"/ws/lobby/{code}/",
        )
        connected, _ = await communicator.connect()

        assert connected

        await communicator.disconnect()

    async def test_connect_to_nonexistent_lobby_fails(self, db):
        """Connecting to nonexistent lobby closes connection."""
        communicator = WebsocketCommunicator(
            application,
            "/ws/lobby/XXXXXX/",
        )
        connected, close_code = await communicator.connect()

        assert not connected or close_code == 4004

        await communicator.disconnect()

    async def test_receive_player_joined_event(self, db):
        """Connected clients receive player_joined events."""
        from apps.core.models import LobbyPlayer, User

        code, host = await create_lobby_with_user()

        # Connect as host
        communicator = WebsocketCommunicator(
            application,
            f"/ws/lobby/{code}/",
        )
        await communicator.connect()

        # Another player joins
        @database_sync_to_async
        def add_player():
            from apps.core.models import Lobby

            player = User.objects.create_user(username="player2", password="pass")
            lobby = Lobby.objects.get(code=code)
            LobbyPlayer.objects.create(lobby=lobby, user=player)
            return player.username

        # Send event through channel layer
        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        await channel_layer.group_send(
            f"lobby_{code}",
            {
                "type": "player.joined",
                "username": "player2",
            },
        )

        # Receive the message
        response = await communicator.receive_json_from()

        assert response["type"] == "player_joined"
        assert response["username"] == "player2"

        await communicator.disconnect()
```

**Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/core/test_lobby_websocket.py -v`
Expected: FAIL (WebSocket route not found or consumer doesn't exist)

**Step 3: Create WebSocket consumer**

Create `backend/apps/core/consumers.py`:

```python
"""WebSocket consumers for core app."""

import json

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer


class LobbyConsumer(AsyncJsonWebsocketConsumer):
    """WebSocket consumer for lobby real-time updates."""

    async def connect(self):
        self.lobby_code = self.scope["url_route"]["kwargs"]["code"]
        self.lobby_group_name = f"lobby_{self.lobby_code}"

        # Check if lobby exists
        lobby_exists = await self.lobby_exists(self.lobby_code)
        if not lobby_exists:
            await self.close(code=4004)
            return

        # Join lobby group
        await self.channel_layer.group_add(
            self.lobby_group_name,
            self.channel_name,
        )

        await self.accept()

    async def disconnect(self, close_code):
        # Leave lobby group
        await self.channel_layer.group_discard(
            self.lobby_group_name,
            self.channel_name,
        )

    async def receive_json(self, content):
        """Handle incoming WebSocket messages."""
        message_type = content.get("type")

        # For now, just echo back - game-specific handling comes later
        await self.send_json({"type": "echo", "data": content})

    # Event handlers for channel layer messages

    async def player_joined(self, event):
        """Handle player joined event."""
        await self.send_json({
            "type": "player_joined",
            "username": event["username"],
        })

    async def player_left(self, event):
        """Handle player left event."""
        await self.send_json({
            "type": "player_left",
            "username": event["username"],
        })

    async def player_ready(self, event):
        """Handle player ready state change."""
        await self.send_json({
            "type": "player_ready",
            "username": event["username"],
            "is_ready": event["is_ready"],
        })

    async def lobby_update(self, event):
        """Handle generic lobby update."""
        await self.send_json({
            "type": "lobby_update",
            "data": event["data"],
        })

    @database_sync_to_async
    def lobby_exists(self, code):
        from apps.core.models import Lobby

        return Lobby.objects.filter(code=code).exists()
```

**Step 4: Add WebSocket routing**

Update `backend/apps/core/routing.py`:

```python
"""WebSocket URL routing for core app."""

from django.urls import path

from . import consumers

websocket_urlpatterns = [
    path("ws/lobby/<str:code>/", consumers.LobbyConsumer.as_asgi()),
]
```

**Step 5: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/core/test_lobby_websocket.py -v`
Expected: All 3 tests PASS

**Step 6: Commit**

```bash
git add backend/apps/core/consumers.py backend/apps/core/routing.py backend/tests/core/test_lobby_websocket.py
git commit -m "feat(core): add WebSocket consumer for lobby real-time updates"
```

---

## Task 10: Broadcast Events from REST API

**Files:**
- Modify: `backend/apps/core/views.py`
- Modify: `backend/tests/core/test_lobby_api.py`

**Step 1: Write test for broadcast on join**

Add to `backend/tests/core/test_lobby_api.py`:

```python
@pytest.mark.integration
class TestLobbyBroadcast:
    """Test that API actions broadcast WebSocket events."""

    def test_join_broadcasts_event(self, api_client, db, settings):
        """Joining a lobby broadcasts player_joined event."""
        from unittest.mock import AsyncMock, patch

        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        api_client.force_authenticate(user=player)
        url = reverse("core:lobby-join", kwargs={"code": lobby.code})

        with patch("apps.core.views.get_channel_layer") as mock_get_layer:
            mock_layer = AsyncMock()
            mock_get_layer.return_value = mock_layer

            response = api_client.post(url)

            assert response.status_code == status.HTTP_200_OK
            mock_layer.group_send.assert_called_once()
            call_args = mock_layer.group_send.call_args
            assert call_args[0][0] == f"lobby_{lobby.code}"
            assert call_args[0][1]["type"] == "player.joined"
```

**Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/core/test_lobby_api.py::TestLobbyBroadcast -v`
Expected: FAIL (broadcast not implemented)

**Step 3: Add broadcast helper and update views**

Add to `backend/apps/core/views.py` at the top:

```python
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
```

Create a helper function:

```python
def broadcast_to_lobby(lobby_code: str, event_type: str, data: dict):
    """Broadcast an event to all WebSocket clients in a lobby."""
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        f"lobby_{lobby_code}",
        {"type": event_type, **data},
    )
```

Update `LobbyJoinView.post()` to broadcast after creating the player:

```python
class LobbyJoinView(APIView):
    """Join an existing lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request, code):
        try:
            lobby = Lobby.objects.get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if LobbyPlayer.objects.filter(lobby=lobby, user=request.user).exists():
            return Response(
                {"detail": "You are already in this lobby."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if lobby.players.count() >= lobby.max_players:
            return Response(
                {"detail": "Lobby is full."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if lobby.status != Lobby.Status.WAITING:
            return Response(
                {"detail": "Lobby is not accepting players."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        LobbyPlayer.objects.create(lobby=lobby, user=request.user)

        # Broadcast to lobby
        broadcast_to_lobby(code, "player.joined", {"username": request.user.username})

        serializer = LobbySerializer(lobby)
        return Response(serializer.data, status=status.HTTP_200_OK)
```

Similarly update `LobbyLeaveView` and `LobbyReadyView` to broadcast their events.

**Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/core/test_lobby_api.py::TestLobbyBroadcast -v`
Expected: Test PASS

**Step 5: Run all tests**

Run: `cd backend && uv run pytest`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add backend/apps/core/views.py backend/tests/core/test_lobby_api.py
git commit -m "feat(core): broadcast WebSocket events from REST API actions"
```

---

## Task 11: Redis Channel Layer Configuration

**Files:**
- Modify: `backend/config/settings/development.py`
- Modify: `backend/config/settings/production.py`

**Step 1: Configure Redis for development**

Update `backend/config/settings/development.py` to add Redis channel layer (optional for dev):

```python
# Channels - use Redis if available, fallback to in-memory
import os

if os.environ.get("REDIS_URL"):
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {
                "hosts": [os.environ.get("REDIS_URL", "redis://localhost:6379")],
            },
        },
    }
# Otherwise use InMemoryChannelLayer from base.py
```

**Step 2: Configure Redis for production**

Update `backend/config/settings/production.py`:

```python
# Channels - Redis required in production
import os

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [os.environ.get("REDIS_URL", "redis://localhost:6379")],
        },
    },
}
```

**Step 3: Verify Django check passes**

Run: `cd backend && uv run python manage.py check`
Expected: System check identified no issues

**Step 4: Commit**

```bash
git add backend/config/settings/development.py backend/config/settings/production.py
git commit -m "config: add Redis channel layer configuration for production"
```

---

## Task 12: Run Full Test Suite and Verify

**Step 1: Run all tests**

Run: `cd backend && uv run pytest`
Expected: All tests PASS with good coverage

**Step 2: Run linting and type checks**

Run: `cd backend && just check`
Expected: All checks pass

**Step 3: Final commit if any fixes needed**

If any fixes were made:
```bash
git add -A
git commit -m "fix: resolve test and lint issues"
```

---

## Summary

After completing all tasks, `apps.core` provides:

1. **JWT Authentication** - Token obtain/refresh endpoints for Flutter app
2. **Lobby Model** - Generic lobby with auto-generated 6-char room codes
3. **LobbyPlayer Model** - Tracks players in lobbies with ready state
4. **REST API** - Create, get, join, leave, ready endpoints
5. **WebSocket Support** - Real-time updates for lobby events
6. **Broadcast Integration** - REST actions trigger WebSocket broadcasts

Game-specific apps (like `apps.onuw`) can now build on this foundation.
