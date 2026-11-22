"""Tests for JWT authentication endpoints."""

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

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


def _tokens(user) -> tuple[str, str]:
    """A fresh (refresh, access) pair for ``user``, as sign-up hands out."""
    refresh = RefreshToken.for_user(user)
    return str(refresh), str(refresh.access_token)


def _refresh(client, token: str):
    return client.post(reverse("core:token_refresh"), {"refresh": token}, format="json")


def _read_as(access: str):
    """An authenticated read (where am I) with ``access`` as the bearer."""
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    return client.get(reverse("core:my-table"))


class TestRenewalNeverCostsTheSeat:
    """A renewal whose answer was lost is sent again with the same token: it must
    still work (rotation without blacklisting)."""

    def test_the_same_refresh_token_used_twice_answers_200_both_times(
        self, api_client, user
    ):
        token, _ = _tokens(user)

        first = _refresh(api_client, token)
        second = _refresh(api_client, token)

        assert first.status_code == status.HTTP_200_OK
        assert second.status_code == status.HTTP_200_OK
        # Rotation still slides the week: each answer carries a new refresh token.
        assert first.data["refresh"] != token
        assert second.data["refresh"] != token
        # And the rotated one works too.
        assert _refresh(api_client, first.data["refresh"]).status_code == 200

    def test_an_explicit_logout_still_ends_the_token(self, api_client, user):
        token, access = _tokens(user)
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        out = api_client.post(reverse("core:logout"), {"refresh": token}, format="json")
        api_client.credentials()

        assert out.status_code < 300
        assert _refresh(api_client, token).status_code == status.HTTP_401_UNAUTHORIZED


class TestAnAccountThatIsGoneAnswers401:
    """The whole class of "this account is gone" (deleted, made inactive) answers
    401 on the refresh and on authenticated reads, never a 500 or anything else
    the app would take for "no answer" and ask again for ever."""

    @pytest.fixture(params=["deleted", "inactive"])
    def gone(self, request, user):
        token, access = _tokens(user)
        if request.param == "deleted":
            user.delete()
        else:
            user.is_active = False
            user.save(update_fields=["is_active"])
        return token, access

    def test_the_refresh_answers_401(self, api_client, gone):
        token, _ = gone

        response = _refresh(api_client, token)

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_an_authenticated_read_answers_401(self, gone):
        _, access = gone

        assert _read_as(access).status_code == status.HTTP_401_UNAUTHORIZED

    def test_a_deleted_account_is_said_alike_on_the_refresh_and_a_read(
        self, api_client, user
    ):
        token, access = _tokens(user)
        user.delete()

        refreshed = _refresh(api_client, token)
        read = _read_as(access)

        assert refreshed.status_code == read.status_code == 401
        assert refreshed.json() == read.json()
