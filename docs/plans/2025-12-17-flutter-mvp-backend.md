# Flutter MVP Backend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the `POST /api/auth/guest/` endpoint that creates guest accounts with optional display names and returns JWT tokens.

**Architecture:** Add `display_name` and `is_guest` fields to the User model, create a new view and serializer for guest registration, and implement display name generation with hardcoded word lists.

**Tech Stack:** Django 5.x, Django REST Framework, Simple JWT, pytest

---

## Task 1: Add User Model Fields

**Files:**
- Modify: `backend/apps/core/models.py:11-14`
- Create: `backend/apps/core/migrations/XXXX_add_guest_fields.py` (auto-generated)

**Step 1: Write the failing test**

Create `backend/tests/core/test_guest_auth.py`:

```python
"""Tests for guest authentication endpoint."""

import re
import uuid

import pytest
from django.contrib.auth import get_user_model


User = get_user_model()


class TestGuestUserModel:
    """Test guest user model fields."""

    def test_user_has_display_name_field(self, db):
        """User model has display_name field."""
        user = User.objects.create_user(
            username="testuser",
            password="testpass",
            display_name="TestName",
        )
        assert user.display_name == "TestName"

    def test_user_has_is_guest_field(self, db):
        """User model has is_guest field."""
        user = User.objects.create_user(
            username="testuser",
            password="testpass",
            is_guest=True,
        )
        assert user.is_guest is True

    def test_is_guest_defaults_to_false(self, db):
        """is_guest defaults to False for regular users."""
        user = User.objects.create_user(
            username="testuser",
            password="testpass",
        )
        assert user.is_guest is False

    def test_display_name_can_be_blank(self, db):
        """display_name can be blank."""
        user = User.objects.create_user(
            username="testuser",
            password="testpass",
            display_name="",
        )
        assert user.display_name == ""
```

**Step 2: Run test to verify it fails**

Run: `just test backend/tests/core/test_guest_auth.py::TestGuestUserModel -v`
Expected: FAIL with "TypeError: User() got unexpected keyword argument 'display_name'"

**Step 3: Write minimal implementation**

Edit `backend/apps/core/models.py`, replace the User class:

```python
class User(AbstractUser):
    """Custom User model for Midnight Village."""

    display_name = models.CharField(max_length=20, blank=True, default="")
    is_guest = models.BooleanField(default=False)
```

**Step 4: Create and run migration**

Run: `cd backend && just makemigrations`
Expected: Creates migration file

Run: `cd backend && just migrate`
Expected: Applies migration

**Step 5: Run test to verify it passes**

Run: `just test backend/tests/core/test_guest_auth.py::TestGuestUserModel -v`
Expected: PASS (4 tests)

**Step 6: Commit**

```bash
git add backend/apps/core/models.py backend/apps/core/migrations/ backend/tests/core/test_guest_auth.py
git commit -m "$(cat <<'EOF'
feat(auth): add display_name and is_guest fields to User model

Adds fields required for guest authentication:
- display_name: optional name shown to other players (max 20 chars)
- is_guest: boolean flag to distinguish guest accounts
EOF
)"
```

---

## Task 2: Add Display Name Generator

**Files:**
- Create: `backend/apps/core/name_generator.py`
- Test: `backend/tests/core/test_guest_auth.py` (add tests)

**Step 1: Write the failing test**

Add to `backend/tests/core/test_guest_auth.py`:

```python
from apps.core.name_generator import generate_display_name


class TestDisplayNameGenerator:
    """Test display name generation."""

    def test_generates_adjective_animal_format(self):
        """Generated names follow AdjectiveAnimal format."""
        name = generate_display_name()
        # Should be two capitalized words joined (e.g., "SwiftOwl")
        assert re.match(r"^[A-Z][a-z]+[A-Z][a-z]+$", name)

    def test_generates_different_names(self):
        """Generator produces variety of names."""
        names = {generate_display_name() for _ in range(100)}
        # Should generate at least 50 unique names in 100 tries
        assert len(names) >= 50

    def test_generated_name_max_length(self):
        """Generated names fit within 20 char limit."""
        for _ in range(100):
            name = generate_display_name()
            assert len(name) <= 20
```

**Step 2: Run test to verify it fails**

Run: `just test backend/tests/core/test_guest_auth.py::TestDisplayNameGenerator -v`
Expected: FAIL with "ModuleNotFoundError: No module named 'apps.core.name_generator'"

**Step 3: Write minimal implementation**

Create `backend/apps/core/name_generator.py`:

```python
"""Display name generator for guest users."""

import random

# ~100 adjectives, all <= 10 chars to ensure combined name <= 20 chars
ADJECTIVES = [
    "Swift", "Bright", "Clever", "Bold", "Quick", "Calm", "Brave", "Noble",
    "Silent", "Wild", "Fierce", "Gentle", "Mighty", "Sleek", "Keen", "Sly",
    "Proud", "Wise", "Free", "True", "Dark", "Light", "Warm", "Cool", "Sharp",
    "Smooth", "Fast", "Strong", "Smart", "Grand", "Fine", "Pure", "Deep",
    "High", "Great", "Good", "Kind", "Fair", "Rare", "Rich", "Soft", "Loud",
    "Still", "Clear", "Fresh", "Crisp", "Neat", "Tidy", "Cozy", "Snug",
    "Agile", "Alert", "Amber", "Azure", "Blaze", "Coral", "Dusk", "Echo",
    "Ember", "Frost", "Gleam", "Haze", "Ivory", "Jade", "Lucky", "Lunar",
    "Maple", "Misty", "Ocean", "Onyx", "Pearl", "Plum", "Raven", "Royal",
    "Ruby", "Rusty", "Sandy", "Shiny", "Silk", "Solar", "Spice", "Storm",
    "Sunny", "Tawny", "Terra", "Topaz", "Vivid", "Wispy", "Zesty", "Zippy",
    "Aqua", "Aspen", "Berry", "Cedar", "Cloud", "Dusky", "Elfin", "Flora",
]

# ~100 animals, all <= 10 chars
ANIMALS = [
    "Owl", "Fox", "Wolf", "Bear", "Hawk", "Lion", "Tiger", "Eagle", "Raven",
    "Falcon", "Panther", "Otter", "Badger", "Heron", "Crane", "Swan", "Dove",
    "Finch", "Robin", "Wren", "Jay", "Lark", "Thrush", "Sparrow", "Puma",
    "Lynx", "Bobcat", "Cougar", "Jaguar", "Leopard", "Cheetah", "Mink",
    "Seal", "Walrus", "Whale", "Dolphin", "Shark", "Squid", "Crab", "Shrimp",
    "Salmon", "Trout", "Bass", "Pike", "Cod", "Tuna", "Moose", "Elk", "Deer",
    "Stag", "Buck", "Doe", "Fawn", "Hare", "Rabbit", "Ferret", "Stoat",
    "Weasel", "Marten", "Sable", "Viper", "Cobra", "Python", "Gecko", "Newt",
    "Frog", "Toad", "Turtle", "Raven", "Crow", "Magpie", "Oriole", "Parrot",
    "Macaw", "Toucan", "Puffin", "Penguin", "Osprey", "Condor", "Vulture",
    "Kite", "Harrier", "Buzzard", "Kestrel", "Merlin", "Gull", "Tern", "Plover",
    "Snipe", "Curlew", "Ibis", "Stork", "Egret", "Bittern", "Corgi", "Husky",
]


def generate_display_name() -> str:
    """Generate a random display name in AdjectiveAnimal format."""
    adjective = random.choice(ADJECTIVES)
    animal = random.choice(ANIMALS)
    return f"{adjective}{animal}"
```

**Step 4: Run test to verify it passes**

Run: `just test backend/tests/core/test_guest_auth.py::TestDisplayNameGenerator -v`
Expected: PASS (3 tests)

**Step 5: Commit**

```bash
git add backend/apps/core/name_generator.py backend/tests/core/test_guest_auth.py
git commit -m "$(cat <<'EOF'
feat(auth): add display name generator for guest users

Generates names in AdjectiveAnimal format (e.g., SwiftOwl, BlueFox).
~100 adjectives × ~100 animals = ~10K unique combinations.
EOF
)"
```

---

## Task 3: Add Guest Registration Serializer

**Files:**
- Modify: `backend/apps/core/serializers.py`
- Test: `backend/tests/core/test_guest_auth.py` (add tests)

**Step 1: Write the failing test**

Add to `backend/tests/core/test_guest_auth.py`:

```python
from apps.core.serializers import GuestCreateSerializer


class TestGuestCreateSerializer:
    """Test guest creation serializer."""

    def test_valid_display_name(self):
        """Accepts valid display names."""
        serializer = GuestCreateSerializer(data={"display_name": "Alice"})
        assert serializer.is_valid()
        assert serializer.validated_data["display_name"] == "Alice"

    def test_empty_display_name_is_valid(self):
        """Empty display name is valid (will be generated)."""
        serializer = GuestCreateSerializer(data={"display_name": ""})
        assert serializer.is_valid()

    def test_missing_display_name_is_valid(self):
        """Missing display name is valid (will be generated)."""
        serializer = GuestCreateSerializer(data={})
        assert serializer.is_valid()

    def test_whitespace_only_display_name_is_valid(self):
        """Whitespace-only name is valid (will be generated)."""
        serializer = GuestCreateSerializer(data={"display_name": "   "})
        assert serializer.is_valid()
        # Whitespace should be trimmed
        assert serializer.validated_data["display_name"] == ""

    def test_display_name_trimmed(self):
        """Leading/trailing whitespace is stripped."""
        serializer = GuestCreateSerializer(data={"display_name": "  Alice  "})
        assert serializer.is_valid()
        assert serializer.validated_data["display_name"] == "Alice"

    def test_display_name_max_length(self):
        """Names over 20 chars are rejected."""
        serializer = GuestCreateSerializer(data={"display_name": "A" * 21})
        assert not serializer.is_valid()
        assert "display_name" in serializer.errors

    def test_display_name_exactly_20_chars(self):
        """Names of exactly 20 chars are accepted."""
        serializer = GuestCreateSerializer(data={"display_name": "A" * 20})
        assert serializer.is_valid()

    def test_display_name_unicode_letters_valid(self):
        """Unicode letters are accepted."""
        serializer = GuestCreateSerializer(data={"display_name": "Émilie"})
        assert serializer.is_valid()

    def test_display_name_with_space_valid(self):
        """Names with single spaces between words are valid."""
        serializer = GuestCreateSerializer(data={"display_name": "John Doe"})
        assert serializer.is_valid()

    def test_display_name_control_chars_invalid(self):
        """Control characters are rejected."""
        serializer = GuestCreateSerializer(data={"display_name": "Test\x00Name"})
        assert not serializer.is_valid()
        assert "display_name" in serializer.errors

    def test_display_name_special_symbols_invalid(self):
        """Special symbols are rejected."""
        for char in ["@", "#", "$", "<", ">", "/"]:
            serializer = GuestCreateSerializer(data={"display_name": f"Test{char}Name"})
            assert not serializer.is_valid(), f"Should reject '{char}'"
```

**Step 2: Run test to verify it fails**

Run: `just test backend/tests/core/test_guest_auth.py::TestGuestCreateSerializer -v`
Expected: FAIL with "ImportError: cannot import name 'GuestCreateSerializer'"

**Step 3: Write minimal implementation**

Add to `backend/apps/core/serializers.py`:

```python
import re


class GuestCreateSerializer(serializers.Serializer):
    """Serializer for guest account creation."""

    display_name = serializers.CharField(
        max_length=20,
        required=False,
        allow_blank=True,
        default="",
    )

    # Unicode letters, numbers, and single spaces between words
    DISPLAY_NAME_PATTERN = re.compile(r"^[\p{L}\p{N}]+( [\p{L}\p{N}]+)*$", re.UNICODE)

    def validate_display_name(self, value: str) -> str:
        """Validate and normalize display name."""
        # Trim whitespace
        value = value.strip()

        # Empty is valid (will be generated later)
        if not value:
            return ""

        # Check for control characters (anything below space except allowed)
        if any(ord(c) < 32 for c in value):
            raise serializers.ValidationError(
                "Display name contains invalid characters."
            )

        # Check pattern: Unicode letters/numbers with single spaces between words
        # Use regex library for proper Unicode support
        import regex

        pattern = regex.compile(r"^[\p{L}\p{N}]+( [\p{L}\p{N}]+)*$")
        if not pattern.match(value):
            raise serializers.ValidationError(
                "Display name can only contain letters, numbers, and single spaces."
            )

        return value
```

**Step 4: Run test to verify it passes**

Run: `just test backend/tests/core/test_guest_auth.py::TestGuestCreateSerializer -v`
Expected: PASS (11 tests)

**Step 5: Add regex dependency**

Edit `backend/pyproject.toml`, add to dependencies:

```toml
"regex>=2024.0.0",
```

Run: `cd backend && uv sync`

**Step 6: Commit**

```bash
git add backend/apps/core/serializers.py backend/tests/core/test_guest_auth.py backend/pyproject.toml backend/uv.lock
git commit -m "$(cat <<'EOF'
feat(auth): add GuestCreateSerializer with display name validation

Validates display names:
- Max 20 characters
- Unicode letters, numbers, and single spaces only
- Trims whitespace
- Empty/whitespace-only values accepted (triggers generation)
EOF
)"
```

---

## Task 4: Add Guest Registration View

**Files:**
- Modify: `backend/apps/core/views.py`
- Modify: `backend/apps/core/urls.py`
- Test: `backend/tests/core/test_guest_auth.py` (add tests)

**Step 1: Write the failing test**

Add to `backend/tests/core/test_guest_auth.py`:

```python
from django.urls import reverse
from rest_framework import status


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
```

**Step 2: Run test to verify it fails**

Run: `just test backend/tests/core/test_guest_auth.py::TestGuestRegistrationEndpoint -v`
Expected: FAIL with "django.urls.exceptions.NoReverseMatch: Reverse for 'guest-create' not found"

**Step 3: Write minimal implementation**

Add to `backend/apps/core/views.py`:

```python
import uuid

from rest_framework_simplejwt.tokens import RefreshToken

from .name_generator import generate_display_name
from .serializers import GuestCreateSerializer


class GuestCreateView(APIView):
    """Create a guest account with optional display name."""

    permission_classes = [AllowAny]

    def post(self, request):
        serializer = GuestCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        display_name = serializer.validated_data.get("display_name", "")

        # Generate display name if not provided or empty
        if not display_name:
            display_name = generate_display_name()

        # Create guest user with UUID username
        from .models import User

        user = User.objects.create_user(
            username=str(uuid.uuid4()),
            password=None,  # Guest accounts have no password
            display_name=display_name,
            is_guest=True,
        )

        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)

        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": {
                    "id": user.id,
                    "display_name": user.display_name,
                },
            },
            status=status.HTTP_201_CREATED,
        )
```

**Step 4: Add URL route**

Add to `backend/apps/core/urls.py` after the existing auth routes:

```python
    path("auth/guest/", views.GuestCreateView.as_view(), name="guest-create"),
```

**Step 5: Run test to verify it passes**

Run: `just test backend/tests/core/test_guest_auth.py::TestGuestRegistrationEndpoint -v`
Expected: PASS (8 tests)

**Step 6: Commit**

```bash
git add backend/apps/core/views.py backend/apps/core/urls.py backend/tests/core/test_guest_auth.py
git commit -m "$(cat <<'EOF'
feat(auth): add POST /api/auth/guest/ endpoint for guest registration

Creates guest account with optional display name:
- POST /api/auth/guest/ (AllowAny)
- Returns JWT access/refresh tokens + user info
- Generates AdjectiveAnimal name if not provided
- Guest users have UUID username and is_guest=True
EOF
)"
```

---

## Task 5: Update UserBriefSerializer

**Files:**
- Modify: `backend/apps/core/serializers.py`
- Test: `backend/tests/core/test_guest_auth.py` (add test)

**Step 1: Write the failing test**

Add to `backend/tests/core/test_guest_auth.py`:

```python
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
```

**Step 2: Run test to verify it fails**

Run: `just test backend/tests/core/test_guest_auth.py::TestUserBriefSerializerWithDisplayName -v`
Expected: FAIL with "AssertionError: assert 'display_name' in {'id': 1, 'username': 'testuser'}"

**Step 3: Write minimal implementation**

Edit `backend/apps/core/serializers.py`, update `UserBriefSerializer`:

```python
class UserBriefSerializer(serializers.ModelSerializer):
    """Brief user info for embedding in other serializers."""

    class Meta:
        model = User
        fields = ["id", "username", "display_name"]
```

**Step 4: Run test to verify it passes**

Run: `just test backend/tests/core/test_guest_auth.py::TestUserBriefSerializerWithDisplayName -v`
Expected: PASS (1 test)

**Step 5: Commit**

```bash
git add backend/apps/core/serializers.py backend/tests/core/test_guest_auth.py
git commit -m "$(cat <<'EOF'
feat(auth): add display_name to UserBriefSerializer

Includes display_name in user serialization for lobby player lists.
EOF
)"
```

---

## Task 6: Run All Tests and Verify

**Files:**
- None (verification only)

**Step 1: Run the full test suite**

Run: `just test`
Expected: All tests PASS

**Step 2: Run quality checks**

Run: `just check`
Expected: All checks PASS (lint, format, typecheck)

**Step 3: Fix any issues**

If lint or format issues:
Run: `just fix`

If type errors, fix them manually.

**Step 4: Final commit (if fixes were needed)**

```bash
git add -A
git commit -m "chore: fix lint/format issues"
```

---

## Task 7: Manual Integration Test

**Files:**
- None (manual verification)

**Step 1: Start the dev server**

Run: `just dev`

**Step 2: Test the endpoint with curl**

Test with display name:
```bash
curl -X POST http://localhost:8000/api/auth/guest/ \
  -H "Content-Type: application/json" \
  -d '{"display_name": "TestPlayer"}'
```

Expected response:
```json
{
  "access": "eyJ...",
  "refresh": "eyJ...",
  "user": {
    "id": 1,
    "display_name": "TestPlayer"
  }
}
```

Test without display name:
```bash
curl -X POST http://localhost:8000/api/auth/guest/ \
  -H "Content-Type: application/json" \
  -d '{}'
```

Expected: Generated name like "SwiftOwl"

**Step 3: Test token validity**

Use the access token from step 2:
```bash
curl http://localhost:8000/api/health/ \
  -H "Authorization: Bearer <access_token>"
```

Expected: `{"status": "ok"}`

---

## Summary

After completing all tasks, you will have:

1. **User model** with `display_name` (max 20 chars) and `is_guest` (boolean) fields
2. **Name generator** producing ~10K unique AdjectiveAnimal combinations
3. **GuestCreateSerializer** with validation for display names
4. **POST /api/auth/guest/** endpoint returning JWT tokens
5. **Updated UserBriefSerializer** exposing display_name

Test coverage: 8 endpoint tests + 4 model tests + 3 generator tests + 11 serializer tests + 1 integration test = 27 tests
