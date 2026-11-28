"""The game apps, from the registry they plug into core with (``apps.core.games``):
each registered ``GameHooks`` belongs to one app. No list: a new game is found the day it
registers."""

from __future__ import annotations

from django.apps import AppConfig, apps

from apps.core import games


def game_apps() -> list[AppConfig]:
    found = {
        apps.get_containing_app_config(type(hooks).__module__)
        for hooks in games._registry.values()
    }
    return sorted((a for a in found if a is not None), key=lambda a: a.label)
