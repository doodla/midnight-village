"""Tests for JWT authentication endpoints."""

from django.urls import reverse

import pytest
from rest_framework import status

pytestmark = pytest.mark.integration


class TestTokenEndpoints:
    """Test JWT token obtain and refresh endpoints."""

    def test_obtain_token_with_valid_credentials(self, api_client, user):
        """Users can obtain JWT tokens with valid credentials."""
        url = reverse("core:token_obtain_pair")
        response = api_client.post(
            url,
            {"username": "testuser", "password": "testpass123"},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert "access" in response.data
        assert "refresh" in response.data

    def test_obtain_token_with_invalid_credentials(self, api_client, db):
        """Invalid credentials return 401."""
        url = reverse("core:token_obtain_pair")
        response = api_client.post(
            url,
            {"username": "wrong", "password": "wrong"},
            format="json",
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_refresh_token(self, api_client, user):
        """Users can refresh their access token."""
        # First obtain tokens
        obtain_url = reverse("core:token_obtain_pair")
        response = api_client.post(
            obtain_url,
            {"username": "testuser", "password": "testpass123"},
            format="json",
        )
        refresh_token = response.data["refresh"]

        # Then refresh
        refresh_url = reverse("core:token_refresh")
        response = api_client.post(
            refresh_url,
            {"refresh": refresh_token},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert "access" in response.data
