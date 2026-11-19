"""ONUW app configuration."""

from django.apps import AppConfig


class OnuwConfig(AppConfig):
    """Configuration for the One Night Ultimate Werewolf application."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.onuw"
    verbose_name = "One Night Ultimate Werewolf"

    def ready(self) -> None:
        # Plug into the shared lobby (apps.core must not import this app).
        from apps.core import games, timers

        from .hooks import OnuwHooks

        games.register("onuw", OnuwHooks())
        # Modules that define this game's timer jobs / presence scope.
        timers.register_job_module("apps.onuw.services")
        timers.register_job_module("apps.onuw.presence")
