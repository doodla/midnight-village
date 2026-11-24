"""ONUW app configuration."""

from django.apps import AppConfig


class OnuwConfig(AppConfig):
    """Configuration for the One Night Ultimate Werewolf application."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.onuw"
    verbose_name = "One Night Ultimate Werewolf"

    def ready(self) -> None:
        # Plug into the shared lobby (apps.core must not import this app).
        from apps.core import games, online, timers

        from . import basics, practice, presence
        from .hooks import OnuwHooks

        games.register("onuw", OnuwHooks())
        # The practice players act through the whole service: it is plugged into
        # the bottom layer here, where nothing imports upwards.
        # (looked up when called, so a test that replaces ``practice.drive`` reaches it)
        basics.practice_driver = lambda game_id: practice.drive(game_id)
        online.register_online_source(presence.online_sockets)
        # The module that defines this game's timer jobs and registers its
        # presence scope: the timers import it before any job runs.
        timers.register_job_module("apps.onuw.services")
