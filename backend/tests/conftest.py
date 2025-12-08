"""
Shared pytest fixtures for the Midnight Village backend.
"""

import pytest
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AbstractUser
from rest_framework.test import APIClient


@pytest.fixture
def api_client() -> APIClient:
    """Return an unauthenticated API client."""
    return APIClient()


@pytest.fixture
def user(db) -> AbstractUser:
    """Create and return a test user."""
    User = get_user_model()
    return User.objects.create_user(
        username="testuser",
        email="test@example.com",
        password="testpass123",
    )


@pytest.fixture
def authenticated_client(api_client: APIClient, user: AbstractUser) -> APIClient:
    """Return an API client authenticated as the test user."""
    api_client.force_authenticate(user=user)
    return api_client
