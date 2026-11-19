"""Thousands of random nights, checked against the rules.

Seeded, so a failure is reproducible. Covers every role, every card the
Doppelganger can copy, and 3 to 10 players.
"""

import random

import pytest

from .night_rules_reference import (
    engine,
    normalise,
    random_game,
    sequential,
    shared_window,
)

pytestmark = pytest.mark.unit

SEED = 20261114
GAMES = 3000


def test_shared_window_night_equals_role_by_role_night() -> None:
    rng = random.Random(SEED)  # noqa: S311 — seeded on purpose so failures reproduce, not cryptographic
    for _ in range(GAMES):
        dealt, center, choices = random_game(rng)
        assert sequential(dealt, center, choices) == shared_window(
            dealt, center, choices
        ), (dealt, center, choices)


def test_engine_night_shows_every_player_what_the_rules_say() -> None:
    rng = random.Random(SEED)  # noqa: S311 — seeded on purpose so failures reproduce, not cryptographic
    for _ in range(GAMES):
        dealt, center, choices = random_game(rng)
        cards, final_center, views, _ = sequential(dealt, center, choices)
        eng_cards, eng_center, eng_views, _ = engine(dealt, center, choices)
        assert (eng_cards, eng_center, eng_views) == (
            cards,
            final_center,
            normalise(views),
        ), (dealt, center, choices)
