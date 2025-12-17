"""Tests for guest authentication endpoint."""

import re


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
