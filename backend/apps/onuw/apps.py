"""ONUW app configuration."""

from django.apps import AppConfig


class OnuwConfig(AppConfig):
    """Configuration for the One Night Ultimate Werewolf application."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.onuw"
    verbose_name = "One Night Ultimate Werewolf"
