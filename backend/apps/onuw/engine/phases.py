"""
Phase transition validation for ONUW games.

Pure Python — zero Django imports. Defines which phase transitions are valid.
"""

VALID_TRANSITIONS: dict[str, list[str]] = {
    "lobby": ["night"],
    "night": ["discussion"],
    "discussion": ["voting"],
    "voting": ["results"],
    "results": [],  # terminal
}


def validate_phase_transition(current: str, target: str) -> bool:
    """Check if a phase transition is valid."""
    return target in VALID_TRANSITIONS.get(current, [])
