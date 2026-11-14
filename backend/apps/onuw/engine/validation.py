"""
Pure-Python settings validation for ONUW games.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from .roles import ROLE_REGISTRY

# Every timer setting the server reads, in seconds. 0 disables that timer
# (night_doppelganger_window_seconds: see services._fixed_window_seconds).
TIMER_SETTING_KEYS: tuple[str, ...] = (
    "night_wave_seconds",
    "night_min_window_seconds",
    "night_doppelganger_window_seconds",
    "discussion_seconds",
    "voting_seconds",
)
MAX_TIMER_SECONDS = 3600


def is_valid_timer_value(value: object) -> bool:
    """True if value is an integer number of seconds in [0, MAX_TIMER_SECONDS]."""
    return (
        isinstance(value, int)
        and not isinstance(value, bool)
        and 0 <= value <= MAX_TIMER_SECONDS
    )


def validate_timer_settings(settings: dict) -> list[str]:
    """
    Validate the timer keys of a settings dict (absent keys are fine).

    Each must be an integer from 0 to MAX_TIMER_SECONDS, and
    night_min_window_seconds must not exceed night_wave_seconds when the
    latter is set above 0 (the minimum length of a window cannot be longer
    than its maximum). These are host-facing settings, so errors are explicit.
    """
    errors: list[str] = []
    for key in TIMER_SETTING_KEYS:
        if key not in settings:
            continue
        if not is_valid_timer_value(settings[key]):
            errors.append(
                f"{key!r} must be a whole number of seconds from 0 to "
                f"{MAX_TIMER_SECONDS}."
            )

    wave_max = settings.get("night_wave_seconds")
    window_min = settings.get("night_min_window_seconds")
    if (
        is_valid_timer_value(wave_max)
        and is_valid_timer_value(window_min)
        and wave_max > 0  # type: ignore[operator]
        and window_min > wave_max  # type: ignore[operator]
    ):
        errors.append(
            "'night_min_window_seconds' must not be longer than 'night_wave_seconds'."
        )
    return errors


def validate_onuw_settings(settings: dict, player_count: int) -> list[str]:
    """
    Validate ONUW role configuration.

    Args:
        settings: Game settings dict. Must contain a "roles" key mapping
                  role names to counts, e.g. {"Werewolf": 2, "Seer": 1, ...}.
        player_count: Number of players in the lobby.

    Returns:
        List of error messages. Empty list means valid.
    """
    if not isinstance(settings, dict):
        return ["Settings must be an object."]

    errors: list[str] = validate_timer_settings(settings)

    if player_count < 3:
        errors.append(f"At least 3 players required, got {player_count}.")

    if player_count > 10:
        errors.append(f"At most 10 players allowed, got {player_count}.")

    roles = settings.get("roles")
    if roles is None:
        errors.append("Settings must include a 'roles' key.")
        return errors

    if not isinstance(roles, dict):
        errors.append("'roles' must be a mapping of role name to count.")
        return errors

    total_roles = 0
    for role_name, count in roles.items():
        if not isinstance(count, int) or count < 0:
            errors.append(f"Count for {role_name!r} must be a non-negative integer.")
            continue

        if role_name not in ROLE_REGISTRY:
            errors.append(f"Unknown role: {role_name!r}.")
            continue

        role_def = ROLE_REGISTRY[role_name]
        if count < role_def.min_count:
            errors.append(
                f"{role_name!r} requires at least {role_def.min_count}, got {count}."
            )
        if count > role_def.max_count:
            errors.append(
                f"{role_name!r} allows at most {role_def.max_count}, got {count}."
            )

        total_roles += count

    # Masons must be used in pairs (0 or 2, never 1).
    mason_count = roles.get("Mason", 0)
    if mason_count == 1:
        errors.append(
            "Masons must be used in pairs — include 0 or 2 Mason cards, not 1."
        )

    expected = player_count + 3
    if total_roles != expected:
        errors.append(
            f"Total role count must be {expected} (players + 3 center cards), got {total_roles}."
        )

    return errors
