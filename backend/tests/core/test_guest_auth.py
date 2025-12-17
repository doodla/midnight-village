"""Tests for guest authentication endpoint."""


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
