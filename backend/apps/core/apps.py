"""Core app configuration."""

from django.apps import AppConfig


class CoreConfig(AppConfig):
    """Configuration for the core application."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.core"
    verbose_name = "Core"

    def ready(self) -> None:
        from django.db.backends.signals import connection_created

        from . import frames

        # every connection, as it opens, refuses a write from a received frame
        connection_created.connect(frames.install, dispatch_uid="core.frames")
