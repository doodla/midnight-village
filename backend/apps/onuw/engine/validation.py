"""
Pure-Python settings validation for ONUW games.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from .roles import ROLE_REGISTRY


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
    errors: list[str] = []

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
