# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""Two games that differ only in what one seat must not know tell that seat the same bytes.

Principle 2, tested as the property (non-interference), not as words to look for: the
same seeded game is played twice, seat for seat, and the second game changes one hidden
thing. What can be hidden from a seat is every other seat's card, every centre card and
every other seat's vote before the reveal, so the second game:

- swaps two other seats' cards (a werewolf's seat moves);
- swaps the cards of the seat whose pick lands on the viewer, so a Robber or a
  Troublemaker takes or moves the viewer's card in one game only;
- exchanges a seat's card with a centre card (the count at the table changes);
- reorders the centre;
- moves another seat's first vote onto the viewer, or off it.

Everything the viewer is told until the vote's last lock must be byte-identical (what it
is told, and what it may rightly learn: two_deals.py). Each case also checks, from the
database, that its two games really differed in exactly what it claims to change: a case
whose games are the same proves nothing and fails. The cases come from the engine's role
table (each role a viewer, each role a changed card); the routes from the urlconf.
"""

from __future__ import annotations

from typing import Any

import pytest

from apps.onuw.engine.roles import ROLE_REGISTRY, ActionType
from tests.privacy.two_deals import CENTRE, Plan, deck_pool, first_difference, told

pytestmark = [pytest.mark.django_db, pytest.mark.uses_timers]

VIEWER = 1  # never the host (seat 0), never the last to lock its vote
PAIRED = ("Mason",)  # cards a deck holds two of or none (engine/validation.py)
MOVES = {ActionType.SWAP_WITH_PLAYER, ActionType.SWAP_OTHERS}
OWN_MOVES = {ActionType.SWAP_WITH_PLAYER, ActionType.SWAP_WITH_CENTER}


def _deal(role: str, seats: int, turn: int) -> tuple[tuple[str, ...], tuple[str, ...]]:
    """The viewer holds ``role``; the rest of the pool, turned by ``turn`` so each case
    leaves different cards out, goes round the other seats and into the centre."""
    pool = deck_pool()
    pool.remove(role)
    turn %= len(pool)
    pool = pool[turn:] + pool[:turn]
    others, centre = pool[: seats - 1], pool[seats - 1 : seats - 1 + CENTRE]
    if "Werewolf" not in others:  # a werewolf among the others, so its seat can leak
        wolf = pool.index("Werewolf")
        others[-1], pool[wolf] = pool[wolf], others[-1]
        centre = pool[seats - 1 : seats - 1 + CENTRE]
    dealt = [*others[:VIEWER], role, *others[VIEWER:]]
    used = dealt + list(centre)
    spare = [c for c in pool if c not in PAIRED and c not in used]
    for paired in PAIRED:
        if (dealt + list(centre)).count(paired) == 1:
            if role == paired:
                seat = max(
                    s for s, c in enumerate(dealt) if c != "Werewolf" and s != VIEWER
                )
                dealt[seat] = paired
            else:
                where = dealt if paired in dealt else centre
                where[where.index(paired)] = spare.pop(0)
    return tuple(dealt), tuple(centre)


def _moves(role: str) -> bool:
    return bool(MOVES & set(ROLE_REGISTRY[role].action_types))


def _hits_viewer(dealt, role: str) -> bool:
    """A mover at the seat whose first pick is the viewer changes the viewer's card: a
    taker takes it; a swapper swaps it with the viewer's other neighbour, if that differs.
    Not for a viewer that moves its own card afterwards (it ends with what it takes)."""
    if OWN_MOVES & set(ROLE_REGISTRY[dealt[VIEWER]].action_types):
        return False
    if ActionType.SWAP_WITH_PLAYER in ROLE_REGISTRY[role].action_types:
        return True
    return _moves(role) and dealt[VIEWER - 1] != dealt[VIEWER]


def _variations(dealt, centre) -> dict[str, Plan]:
    """One plan of each kind the deal allows, kept only if it hides the change (the rule
    in two_deals.py)."""
    seats = [s for s in range(len(dealt)) if s != VIEWER]
    left = (VIEWER + 1) % len(dealt)  # the seat whose first pick is the viewer
    pairs = {
        "seat-swap": [
            (a, b)
            for a in seats
            for b in seats
            if dealt[a] == "Werewolf" and dealt[b] != "Werewolf"
        ],
        "hit": [
            (m, left)
            for m in seats
            if _hits_viewer(dealt, dealt[m]) and m != left and not _moves(dealt[left])
        ]
        + [
            (left, b)
            for b in seats
            if _hits_viewer(dealt, dealt[left]) and not _moves(dealt[b])
        ],
        "seat-centre": [
            (a, f"c{i}")
            for a in seats
            for i in range(CENTRE)
            if dealt[a] != centre[i] and "Werewolf" in (dealt[a], centre[i])
        ]
        + [(a, f"c{i}") for a in seats for i in range(CENTRE) if dealt[a] != centre[i]],
        "centre-reorder": [
            (f"c{i}", f"c{j}")
            for i in range(CENTRE)
            for j in range(i + 1, CENTRE)
            if centre[i] != centre[j]
        ],
    }
    out = {}
    for kind, candidates in pairs.items():
        for swap in candidates:
            plan = Plan(dealt, centre, VIEWER, swap=swap)
            if plan.hidden_from_viewer() and (kind != "hit" or not plan.protected()):
                out[kind] = plan
                break
    return out


def _cases() -> list[Any]:
    cases, changed = [], set()
    deals = []
    for turn, role in enumerate(sorted(ROLE_REGISTRY)):
        deals.append(_deal(role, 7 if turn % 2 == 0 else 9, turn))
    for dealt, centre in deals:
        for kind, plan in _variations(dealt, centre).items():
            cards = {plan.card(p) for p in plan.changed()} | {
                plan.other().card(p) for p in plan.changed()
            }
            changed |= cards
            cases.append(
                pytest.param(
                    kind,
                    plan,
                    id=f"{dealt[VIEWER]}-{len(dealt)}-{kind}-{'-'.join(sorted(cards))}",
                )
            )
    for role in sorted(
        set(ROLE_REGISTRY) - changed
    ):  # every role is a changed card once
        for dealt, centre in deals:
            seats = [s for s in range(len(dealt)) if s != VIEWER]
            found = next(
                (
                    Plan(dealt, centre, VIEWER, swap=(a, b))
                    for a in seats
                    for b in seats
                    if dealt[a] == role
                    and dealt[b] != role
                    and Plan(dealt, centre, VIEWER, swap=(a, b)).hidden_from_viewer()
                ),
                None,
            )
            if found:
                changed.add(role)
                cases.append(
                    pytest.param(
                        "seat-swap",
                        found,
                        id=f"{dealt[VIEWER]}-{len(dealt)}-changes-{role}",
                    )
                )
                break
    return cases


CASES = _cases()
VOTE_CASES = [
    pytest.param(
        Plan(*_deal("Villager", 7, 0), VIEWER, wavering=4), id="villager-at-7"
    ),
    pytest.param(
        Plan(*_deal("Werewolf", 9, 5), VIEWER, wavering=5), id="werewolf-at-9"
    ),
]


def _places(facts: dict[str, Any]) -> dict[Any, str]:
    return {
        **dict(enumerate(facts["dealt"])),
        **{f"c{i}": card for i, card in enumerate(facts["centre"])},
    }


def test_the_cases_cover_every_role_every_kind_and_two_table_sizes() -> None:
    plans = [case.values[1] for case in CASES]
    changed = {p.card(x) for p in plans for x in p.changed()} | {
        p.other().card(x) for p in plans for x in p.changed()
    }
    assert {p.dealt[VIEWER] for p in plans} == set(ROLE_REGISTRY)
    assert changed == set(ROLE_REGISTRY), (
        f"never a changed card: {set(ROLE_REGISTRY) - changed}"
    )
    assert {case.values[0] for case in CASES} == {
        "seat-swap",
        "hit",
        "seat-centre",
        "centre-reorder",
    }
    assert {len(p.dealt) for p in plans} == {7, 9}


@pytest.mark.parametrize("plan", VOTE_CASES)
def test_another_seats_vote_before_the_reveal_never_changes_what_a_seat_is_told(
    plan: Plan, django_capture_on_commit_callbacks: Any
) -> None:
    off, off_facts = told(django_capture_on_commit_callbacks, plan.first())
    onto, onto_facts = told(django_capture_on_commit_callbacks, plan.other())

    votes = list(zip(off_facts["first_votes"], onto_facts["first_votes"], strict=True))
    differ = [seat for seat, (a, b) in enumerate(votes) if a != b]
    assert differ == [plan.wavering], (
        f"the votes did not differ as the case says: {differ}"
    )
    viewer = off_facts["ids"][VIEWER]
    assert onto_facts["first_votes"][plan.wavering] == viewer, (
        "the vote never landed on the viewer"
    )
    assert off_facts["first_votes"][plan.wavering] != viewer
    difference = first_difference(off, onto)
    assert difference is None, (
        f"seat {VIEWER} learns seat {plan.wavering}'s vote: {difference}"
    )


@pytest.mark.parametrize(("kind", "plan"), CASES)
def test_a_hidden_card_never_changes_what_a_seat_is_told(
    kind: str, plan: Plan, django_capture_on_commit_callbacks: Any
) -> None:
    first, first_facts = told(django_capture_on_commit_callbacks, plan.first())
    second, second_facts = told(django_capture_on_commit_callbacks, plan.other())

    one, two = _places(first_facts), _places(second_facts)
    moved = {place for place in one if one[place] != two[place]}
    assert moved == plan.changed(), (
        f"the games did not differ as the case says: {moved}"
    )
    if kind == "hit":
        assert first_facts["now"][VIEWER] != second_facts["now"][VIEWER], (
            "the viewer's card was not moved in one game only: the case proves nothing"
        )
    assert any(item[0] == "ws" for item in first), "no socket frame reached the viewer"
    difference = first_difference(first, second)
    assert difference is None, (
        f"seat {VIEWER} learns the {kind} of {plan.changed()}: {difference}"
    )


def test_the_comparison_sees_what_the_viewer_may_know(
    django_capture_on_commit_callbacks,
) -> None:
    """Not blind: the viewer's own card, which it may know, shows."""
    plan = CASES[0].values[1]
    mine = list(plan.dealt)
    taken = mine + list(plan.centre) + list(PAIRED)
    mine[VIEWER] = next(r for r in ROLE_REGISTRY if r not in taken)
    assert first_difference(
        told(django_capture_on_commit_callbacks, Plan(plan.dealt, plan.centre, VIEWER))[
            0
        ],
        told(
            django_capture_on_commit_callbacks, Plan(tuple(mine), plan.centre, VIEWER)
        )[0],
    )
