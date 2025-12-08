# API Patterns

This document describes the API patterns and conventions for the Midnight Village backend.

## Response Format

All API responses follow a consistent JSON structure.

### Success Response

```json
{
    "status": "healthy",
    "version": "0.1.0"
}
```

### Error Response

```json
{
    "error": {
        "status_code": 400,
        "detail": "Invalid input data"
    }
}
```

For validation errors with field-level details:

```json
{
    "error": {
        "status_code": 400,
        "detail": {
            "field_name": ["Error message"]
        }
    }
}
```

## HTTP Status Codes

| Status | Use Case |
|--------|----------|
| 200 | Successful GET, PUT, PATCH |
| 201 | Successful POST (resource created) |
| 204 | Successful DELETE (no content) |
| 400 | Validation error, bad request |
| 401 | Authentication required |
| 403 | Permission denied |
| 404 | Resource not found |
| 500 | Server error |

## Exception Handling

Use the custom exception handler in `apps.core.exceptions`:

```python
from apps.core.exceptions import APIException

# Raise with custom code
raise APIException(
    detail="Resource not found",
    code="not_found"
)
```

The exception handler formats errors consistently:

```python
# apps/core/exceptions.py
def custom_exception_handler(exc, context):
    response = drf_exception_handler(exc, context)
    if response is not None:
        detail = response.data
        if isinstance(response.data, dict):
            detail = response.data.get("detail", response.data)
        response.data = {
            "error": {
                "status_code": response.status_code,
                "detail": detail,
            }
        }
    return response
```

## URL Patterns

### Naming Convention

- Use lowercase with hyphens for URLs
- Use plural nouns for collections
- Nest related resources logically

```python
# Good
/api/games/
/api/games/{id}/
/api/games/{id}/players/

# Avoid
/api/getGame/
/api/game_list/
```

### URL Structure

```
/api/                       # API root
/api/health/                # Health check (no auth required)
/api/v1/                    # Versioned API (future)
/api/v1/games/              # Game resources
/api/v1/games/{id}/         # Single game
```

## Authentication

The API uses session authentication for the Django admin and will add token authentication for the game client.

### DRF Settings

```python
REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.SessionAuthentication",
    ],
}
```

### Unauthenticated Endpoints

For public endpoints like health check, use:

```python
from rest_framework.permissions import AllowAny

class HealthCheckView(APIView):
    permission_classes = [AllowAny]
```

## Adding a New Endpoint

1. **Create the view** in `apps/{appname}/views.py`:

   ```python
   from rest_framework.views import APIView
   from rest_framework.response import Response

   class MyView(APIView):
       def get(self, request):
           return Response({"message": "Hello"})
   ```

2. **Add URL pattern** in `apps/{appname}/urls.py`:

   ```python
   from django.urls import path
   from .views import MyView

   urlpatterns = [
       path("my-endpoint/", MyView.as_view(), name="my-endpoint"),
   ]
   ```

3. **Wire into root URLconf** in `config/urls.py`:

   ```python
   urlpatterns = [
       path("api/", include("apps.myapp.urls")),
   ]
   ```

4. **Write tests** in `tests/integration/{appname}/`:

   ```python
   import pytest
   from django.urls import reverse

   @pytest.mark.django_db
   class TestMyEndpoint:
       def test_returns_message(self, client):
           response = client.get(reverse("my-endpoint"))
           assert response.status_code == 200
           assert response.json()["message"] == "Hello"
   ```

## Serializers

Use DRF serializers for input validation and output formatting:

```python
from rest_framework import serializers

class GameSerializer(serializers.Serializer):
    id = serializers.IntegerField(read_only=True)
    name = serializers.CharField(max_length=100)
    created_at = serializers.DateTimeField(read_only=True)
```

For model serializers:

```python
from rest_framework import serializers
from apps.game.models import Game

class GameSerializer(serializers.ModelSerializer):
    class Meta:
        model = Game
        fields = ["id", "name", "created_at"]
        read_only_fields = ["id", "created_at"]
```
