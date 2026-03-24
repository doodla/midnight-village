"""Tests for guest authentication endpoint."""

import re
import uuid

from django.urls import reverse

import pytest
from rest_framework import status


@pytest.mark.unit
class TestGuestUserModel:
    """Test guest user model fields."""

    def test_user_has_display_name_field(self, db):
        """User model has display_name field."""
        from apps.core.models import User

        user = User.objects.create_user(
            username="testuser",
            password="testpass",
            display_name="TestName",
        )
        assert user.display_name == "TestName"

    def test_user_has_is_guest_field(self, db):
        """User model has is_guest field."""
        from apps.core.models import User

        user = User.objects.create_user(
            username="testuser",
            password="testpass",
            is_guest=True,
        )
        assert user.is_guest is True

    def test_is_guest_defaults_to_false(self, db):
        """is_guest defaults to False for regular users."""
        from apps.core.models import User

        user = User.objects.create_user(
            username="testuser",
            password="testpass",
        )
        assert user.is_guest is False

    def test_display_name_can_be_blank(self, db):
        """display_name can be blank."""
        from apps.core.models import User

        user = User.objects.create_user(
            username="testuser",
            password="testpass",
            display_name="",
        )
        assert user.display_name == ""


@pytest.mark.unit
class TestDisplayNameGenerator:
    """Test display name generation."""

    def test_generates_adjective_animal_format(self):
        """Generated names follow AdjectiveAnimal format."""
        from apps.core.name_generator import generate_display_name

        name = generate_display_name()
        # Should be two capitalized words joined (e.g., "SwiftOwl")
        assert re.match(r"^[A-Z][a-z]+[A-Z][a-z]+$", name)

    def test_generates_different_names(self):
        """Generator produces variety of names."""
        from apps.core.name_generator import generate_display_name

        names = {generate_display_name() for _ in range(100)}
        # Should generate at least 50 unique names in 100 tries
        assert len(names) >= 50

    def test_generated_name_max_length(self):
        """Generated names fit within 20 char limit."""
        from apps.core.name_generator import generate_display_name

        for _ in range(100):
            name = generate_display_name()
            assert len(name) <= 20


@pytest.mark.unit
class TestGuestCreateSerializer:
    """Test guest creation serializer."""

    def test_valid_display_name(self):
        """Accepts valid display names."""
        from apps.core.serializers import GuestCreateSerializer

        serializer = GuestCreateSerializer(data={"display_name": "Alice"})
        assert serializer.is_valid()
        assert serializer.validated_data["display_name"] == "Alice"  # type: ignore[index]

    def test_empty_display_name_is_valid(self):
        """Empty display name is valid (will be generated)."""
        from apps.core.serializers import GuestCreateSerializer

        serializer = GuestCreateSerializer(data={"display_name": ""})
        assert serializer.is_valid()

    def test_missing_display_name_is_valid(self):
        """Missing display name is valid (will be generated)."""
        from apps.core.serializers import GuestCreateSerializer

        serializer = GuestCreateSerializer(data={})
        assert serializer.is_valid()

    def test_whitespace_only_display_name_is_valid(self):
        """Whitespace-only name is valid (will be generated)."""
        from apps.core.serializers import GuestCreateSerializer

        serializer = GuestCreateSerializer(data={"display_name": "   "})
        assert serializer.is_valid()
        # Whitespace should be trimmed
        assert serializer.validated_data["display_name"] == ""  # type: ignore[index]

    def test_display_name_trimmed(self):
        """Leading/trailing whitespace is stripped."""
        from apps.core.serializers import GuestCreateSerializer

        serializer = GuestCreateSerializer(data={"display_name": "  Alice  "})
        assert serializer.is_valid()
        assert serializer.validated_data["display_name"] == "Alice"  # type: ignore[index]

    def test_display_name_max_length(self):
        """Names over 20 chars are rejected."""
        from apps.core.serializers import GuestCreateSerializer

        serializer = GuestCreateSerializer(data={"display_name": "A" * 21})
        assert not serializer.is_valid()
        assert "display_name" in serializer.errors

    def test_display_name_exactly_20_chars(self):
        """Names of exactly 20 chars are accepted."""
        from apps.core.serializers import GuestCreateSerializer

        serializer = GuestCreateSerializer(data={"display_name": "A" * 20})
        assert serializer.is_valid()

    def test_display_name_unicode_letters_valid(self):
        """Unicode letters are accepted."""
        from apps.core.serializers import GuestCreateSerializer

        serializer = GuestCreateSerializer(data={"display_name": "Émilie"})
        assert serializer.is_valid()

    def test_display_name_with_space_valid(self):
        """Names with single spaces between words are valid."""
        from apps.core.serializers import GuestCreateSerializer

        serializer = GuestCreateSerializer(data={"display_name": "John Doe"})
        assert serializer.is_valid()

    def test_display_name_control_chars_invalid(self):
        """Control characters are rejected."""
        from apps.core.serializers import GuestCreateSerializer

        serializer = GuestCreateSerializer(data={"display_name": "Test\x00Name"})
        assert not serializer.is_valid()
        assert "display_name" in serializer.errors

    def test_display_name_special_symbols_invalid(self):
        """Special symbols are rejected."""
        from apps.core.serializers import GuestCreateSerializer

        for char in ["@", "#", "$", "<", ">", "/"]:
            serializer = GuestCreateSerializer(data={"display_name": f"Test{char}Name"})
            assert not serializer.is_valid(), f"Should reject '{char}'"


@pytest.mark.integration
class TestGuestRegistrationEndpoint:
    """Test POST /api/auth/guest/ endpoint."""

    def test_create_guest_with_display_name(self, api_client, db):
        """Create guest with provided display name."""
        url = reverse("core:guest-create")
        response = api_client.post(url, {"display_name": "Alice"}, format="json")

        assert response.status_code == status.HTTP_201_CREATED
        assert "access" in response.data
        assert "refresh" in response.data
        assert response.data["user"]["display_name"] == "Alice"

    def test_create_guest_without_display_name(self, api_client, db):
        """Create guest without display name generates one."""
        url = reverse("core:guest-create")
        response = api_client.post(url, {}, format="json")

        assert response.status_code == status.HTTP_201_CREATED
        # Generated name should be AdjectiveAnimal format
        display_name = response.data["user"]["display_name"]
        assert re.match(r"^[A-Z][a-z]+[A-Z][a-z]+$", display_name)

    def test_create_guest_empty_display_name(self, api_client, db):
        """Empty string triggers name generation."""
        url = reverse("core:guest-create")
        response = api_client.post(url, {"display_name": ""}, format="json")

        assert response.status_code == status.HTTP_201_CREATED
        display_name = response.data["user"]["display_name"]
        assert re.match(r"^[A-Z][a-z]+[A-Z][a-z]+$", display_name)

    def test_create_guest_whitespace_only(self, api_client, db):
        """Whitespace-only triggers name generation."""
        url = reverse("core:guest-create")
        response = api_client.post(url, {"display_name": "   "}, format="json")

        assert response.status_code == status.HTTP_201_CREATED
        display_name = response.data["user"]["display_name"]
        assert re.match(r"^[A-Z][a-z]+[A-Z][a-z]+$", display_name)

    def test_create_guest_display_name_trimmed(self, api_client, db):
        """Leading/trailing whitespace is stripped."""
        url = reverse("core:guest-create")
        response = api_client.post(url, {"display_name": "  Alice  "}, format="json")

        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["user"]["display_name"] == "Alice"

    def test_create_guest_display_name_max_length(self, api_client, db):
        """Names > 20 chars are rejected."""
        url = reverse("core:guest-create")
        response = api_client.post(url, {"display_name": "A" * 21}, format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_create_guest_display_name_invalid_chars(self, api_client, db):
        """Control chars / special symbols rejected."""
        url = reverse("core:guest-create")
        response = api_client.post(url, {"display_name": "Test@Name"}, format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_guest_user_fields_set_correctly(self, api_client, db):
        """Guest user has is_guest=True and UUID username."""
        from apps.core.models import User

        url = reverse("core:guest-create")
        response = api_client.post(url, {"display_name": "Alice"}, format="json")

        assert response.status_code == status.HTTP_201_CREATED

        # Verify user in database
        user_id = response.data["user"]["id"]
        user = User.objects.get(id=user_id)
        assert user.is_guest is True
        # Username should be a valid UUID
        try:
            uuid.UUID(user.username)
        except ValueError:
            pytest.fail("Username should be a valid UUID")


@pytest.mark.unit
class TestUserBriefSerializerWithDisplayName:
    """Test UserBriefSerializer includes display_name."""

    def test_includes_display_name(self, user):
        """UserBriefSerializer includes display_name field."""
        from apps.core.serializers import UserBriefSerializer

        user.display_name = "TestDisplay"
        user.save()

        serializer = UserBriefSerializer(user)
        assert "display_name" in serializer.data
        assert serializer.data["display_name"] == "TestDisplay"
