"""
The automatic decks: one deck per player count and chip.

A lobby that says ``deck: "auto"`` (and a ``deck_chip``) has no card list of its own:
the server builds the deck at the deal for the number of players then at the table.
This table is the ONE place the decks live; ``docs/specs/onuw/recommended-setups.md``
("Automatic decks") shows the same table and a test compares the two, so they cannot
drift apart. Every row is a legal deck of exactly players + 3 cards.

``simple`` is the gentlest deck that works for a table of that size; ``classic`` and
``chaos`` are the recommended setups. Simple cannot avoid the Mason pair at 9 and 10
players: without Minion, Masons, Tanner and the Doppelganger the largest legal deck
holds 11 cards.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

DECK_CHIPS: tuple[str, ...] = ("simple", "classic", "chaos")
DEFAULT_DECK_CHIP = "simple"
MIN_AUTO_PLAYERS = 3
MAX_AUTO_PLAYERS = 10


def _cards(spec: str) -> dict[str, int]:
    """``"Werewolf*2 Seer Robber"`` -> ``{"Werewolf": 2, "Seer": 1, "Robber": 1}``."""
    deck: dict[str, int] = {}
    for token in spec.split():
        role, _, count = token.partition("*")
        deck[role] = deck.get(role, 0) + (int(count) if count else 1)
    return deck


_SIMPLE_3 = "Werewolf*2 Seer Robber Troublemaker Villager"
_SIMPLE_4 = "Werewolf*2 Seer Robber Troublemaker Villager*2"
_SIMPLE_5 = "Werewolf*2 Seer Robber Troublemaker Villager*3"
_SIMPLE_6 = "Werewolf*2 Seer Robber Troublemaker Insomniac Villager*3"
_SIMPLE_7 = "Werewolf*2 Seer Robber Troublemaker Drunk Insomniac Villager*3"
_SIMPLE_9 = "Werewolf*2 Seer Robber Troublemaker Drunk Insomniac Mason*2 Villager*3"
_CLASSIC_7 = "Werewolf*2 Minion Seer Robber Troublemaker Mason*2 Drunk Insomniac"
_CLASSIC_9 = (
    "Werewolf*2 Minion Tanner Hunter Seer Robber Troublemaker Mason*2 Drunk Insomniac"
)
_CHAOS_7 = "Werewolf*2 Minion Tanner Seer Robber Troublemaker Mason*2 Insomniac"
_CHAOS_9 = (
    "Doppelganger Werewolf*2 Minion Seer Robber Troublemaker Mason*2 Drunk Insomniac "
    "Tanner"
)

# players -> (simple, classic, chaos), each a card spec (see ``_cards``).
_SPECS: dict[int, tuple[str, str, str]] = {
    3: (_SIMPLE_3, _SIMPLE_3, "Werewolf*2 Seer Robber Troublemaker Drunk"),
    4: (_SIMPLE_4, _SIMPLE_4, "Werewolf*2 Seer Robber Troublemaker Drunk Tanner"),
    5: (
        _SIMPLE_5,
        "Werewolf*2 Seer Robber Troublemaker Drunk Insomniac Villager",
        "Werewolf*2 Minion Seer Robber Troublemaker Tanner Villager",
    ),
    6: (
        _SIMPLE_6,
        "Werewolf*2 Minion Seer Robber Troublemaker Villager*3",
        "Werewolf*2 Seer Robber Troublemaker Drunk Insomniac Tanner Villager",
    ),
    7: (_SIMPLE_7, _CLASSIC_7, _CHAOS_7),
    8: (f"{_SIMPLE_7} Hunter", f"{_CLASSIC_7} Villager", f"{_CHAOS_7} Villager"),
    9: (_SIMPLE_9, _CLASSIC_9, _CHAOS_9),
    10: (f"{_SIMPLE_9} Hunter", f"{_CLASSIC_9} Villager", f"{_CHAOS_9} Villager"),
}

DECK_TABLE: dict[tuple[int, str], dict[str, int]] = {
    (players, chip): _cards(spec)
    for players, specs in _SPECS.items()
    for chip, spec in zip(DECK_CHIPS, specs, strict=True)
}


def auto_deck(players: int, chip: str | None = None) -> dict[str, int] | None:
    """The deck for ``players`` players and ``chip`` (default: simple), or None if
    there is none (fewer than 3 or more than 10 players, or an unknown chip)."""
    deck = DECK_TABLE.get((players, chip or DEFAULT_DECK_CHIP))
    return None if deck is None else dict(deck)
