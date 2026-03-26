"""
Shared pytest fixtures for the Midnight Village backend.
"""

from collections.abc import Generator
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.contrib.auth.models import AbstractUser

import pytest
from rest_framework.test import APIClient


@pytest.fixture
def api_client() -> APIClient:
    """Return an unauthenticated API client."""
    return APIClient()


@pytest.fixture
def user(db) -> AbstractUser:
    """Create and return a test user."""
    user_model = get_user_model()
    return user_model.objects.create_user(
        username="testuser",
        email="test@example.com",
        password="testpass123",
    )


@pytest.fixture
def authenticated_client(api_client: APIClient, user: AbstractUser) -> APIClient:
    """Return an API client authenticated as the test user."""
    api_client.force_authenticate(user=user)
    return api_client


# ---------------------------------------------------------------------------
# Timer safety fixtures (T032 & T033)
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def _auto_mock_timer_schedule(request: pytest.FixtureRequest) -> Generator[None]:
    """
    Patch ``apps.onuw.timers.schedule`` to be a no-op for ALL tests.

    This prevents real threading.Timer threads from being spawned during the
    test run, avoiding flaky race conditions and leaked threads.

    Tests that specifically exercise timer behaviour should apply the
    ``@pytest.mark.uses_timers`` marker to opt out of this fixture.
    """
    if "uses_timers" in {m.name for m in request.node.iter_markers()}:
        yield
        return

    with patch("apps.onuw.timers.schedule"):
        yield


@pytest.fixture(autouse=True)
def _auto_clean_timer_registry() -> Generator[None]:
    """
    Cancel all pending timers and clear the registry after each test.

    Runs unconditionally (including for ``uses_timers`` tests) to guarantee
    no timer threads leak between tests.
    """
    yield
    # Cleanup runs after every test, regardless of markers.
    from apps.onuw import timers

    with timers._lock:
        for timer in timers._registry.values():
            timer.cancel()
        timers._registry.clear()
