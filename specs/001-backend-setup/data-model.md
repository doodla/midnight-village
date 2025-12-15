# Data Model: Backend Project Setup

**Feature Branch**: `001-backend-setup`
**Date**: 2025-12-07

---

## Entity: User

A minimal custom User model to enable future customization without migration complexity.

### Model Definition

```python
# apps/core/models.py
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    """Custom User model for Midnight Village."""

    pass
```

### Settings

```python
# config/settings/base.py
AUTH_USER_MODEL = "core.User"
```

### Admin

```python
# apps/core/admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import User

admin.site.register(User, UserAdmin)
```

### Rationale

Per [Django documentation](https://docs.djangoproject.com/en/5.2/topics/auth/customizing/#using-a-custom-user-model-when-starting-a-project): define a custom User model before the first migration to allow future field additions without complex migrations. The model inherits all fields from AbstractUser (username, email, password, etc.).

### Referencing User

```python
# In models - use settings reference
from django.conf import settings

class SomeModel(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)

# In code - use get_user_model()
from django.contrib.auth import get_user_model
User = get_user_model()
```
