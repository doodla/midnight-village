# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""Two deals that differ only in what one seat must not know tell that seat the same bytes.

Principle 2, tested as the property (non-interference), not as words to look for: the
same seeded game is played twice, seat for seat, and the second deal swaps the cards of
two other seats (or one other seat's first vote, before any reveal, goes elsewhere).
Everything the viewer is told until the vote's last lock must be byte-identical: every
answer it gets (status, headers, body; errors included), every frame its lobby and game
sockets would deliver, and an answer from every GET route at every stage.

The cases come from the engine's role table (``ROLE_REGISTRY``): each role is a viewer
once, at six or eight seats, and every role is dealt somewhere; the routes come from the
urlconf. A new role or endpoint is covered without a line here. Detail: two_deals.py.
"""

from __future__ import annotations

from typing import Any

import pytest

from apps.onuw.engine.roles import ROLE_REGISTRY
from tests.privacy.two_deals import (
    CENTRE,
    Plan,
    deck_pool,
    first_difference,
    sees_others,
    told,
)

pytestmark = [pytest.mark.django_db, pytest.mark.uses_timers]

VIEWER = 1  # never the host (seat 0), never the last to lock its vote
PAIRED = ("Mason",)  # cards a deck holds two of or none


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
        centre = [c for c in pool[seats - 1 :] if c != "Werewolf"][:CENTRE]
        if len(centre) < CENTRE:
            centre = pool[seats - 1 : seats - 1 + CENTRE]
    dealt = [*others[:VIEWER], role, *others[VIEWER:]]
    used = dealt + list(centre)
    spare = [c for c in pool if c not in PAIRED and c not in used]
    for paired in PAIRED:  # the deck holds two or none (engine/validation.py)
        cards = dealt + list(centre)
        if cards.count(paired) == 1:
            where = dealt if role == paired else (dealt if paired in dealt else centre)
            if role == paired:
                seat = max(
                    s for s, c in enumerate(dealt) if c != "Werewolf" and s != VIEWER
                )
                dealt[seat] = paired
            else:
                where[where.index(paired)] = spare.pop(0)
    return tuple(dealt), tuple(centre)


def _swaps(dealt: tuple[str, ...]) -> list[tuple[int, int]]:
    """Two other seats with different cards the viewer's own night cannot show it: a
    werewolf and a seat that is not one, and two seats that act at night."""
    viewer = dealt[VIEWER]
    open_seats = [
        s
        for s, role in enumerate(dealt)
        if s != VIEWER and not (sees_others(viewer) and sees_others(role))
    ]
    pairs = []
    wolves = [s for s in open_seats if dealt[s] == "Werewolf"]
    plain = [s for s in open_seats if dealt[s] != "Werewolf"]
    if wolves and plain:
        pairs.append((wolves[0], plain[0]))
    acting = [s for s in plain if ROLE_REGISTRY[dealt[s]].wave is not None]
    used = {s for pair in pairs for s in pair}
    acting = [s for s in acting if s not in used] or acting
    for x in acting:
        y = next((s for s in acting if dealt[s] != dealt[x] and s != x), None)
        if y is not None:
            pairs.append((x, y))
            break
    return pairs


def _cases() -> list[Any]:
    cases = []
    for turn, role in enumerate(sorted(ROLE_REGISTRY)):
        seats = 6 if turn % 2 == 0 else 8
        dealt, centre = _deal(role, seats, turn)
        for swap in _swaps(dealt):
            plan = Plan(dealt, centre, VIEWER, swap=swap)
            label = f"{role}-at-{seats}-swap-{dealt[swap[0]]}-{dealt[swap[1]]}"
            cases.append(pytest.param(plan, id=label))
    return cases


CASES = _cases()


def test_the_cases_cover_every_role_as_viewer_and_dealt() -> None:
    viewers = {case.values[0].dealt[VIEWER] for case in CASES}
    dealt = {role for case in CASES for role in case.values[0].dealt}
    assert viewers == set(ROLE_REGISTRY)
    assert dealt == set(ROLE_REGISTRY)
    assert {len(case.values[0].dealt) for case in CASES} == {6, 8}


@pytest.mark.parametrize("plan", CASES)
def test_another_seats_card_never_changes_what_a_seat_is_told(
    plan: Plan, django_capture_on_commit_callbacks: Any
) -> None:
    first = told(django_capture_on_commit_callbacks, plan)
    second = told(django_capture_on_commit_callbacks, plan.swapped())

    assert first, "the viewer was told nothing: the script did not play"
    assert any(item[0] == "ws" for item in first), "no socket frame reached the viewer"
    difference = first_difference(first, second)
    assert difference is None, (
        f"seat {VIEWER} learns the swap of seats {plan.swap}: {difference}"
    )


VOTE_CASES = [
    pytest.param(
        Plan(*_deal("Villager", 6, 0), VIEWER, wavering=3), id="villager-at-6"
    ),
    pytest.param(
        Plan(*_deal("Werewolf", 8, 5), VIEWER, wavering=5), id="werewolf-at-8"
    ),
]


@pytest.mark.parametrize("plan", VOTE_CASES)
def test_another_seats_vote_before_the_reveal_never_changes_what_a_seat_is_told(
    plan: Plan, django_capture_on_commit_callbacks: Any
) -> None:
    straight = told(
        django_capture_on_commit_callbacks, Plan(plan.dealt, plan.centre, VIEWER)
    )
    wavered = told(django_capture_on_commit_callbacks, plan)

    difference = first_difference(straight, wavered)
    assert difference is None, (
        f"seat {VIEWER} learns seat {plan.wavering}'s vote: {difference}"
    )


def test_the_sweep_would_see_a_seat_given_away(
    django_capture_on_commit_callbacks,
) -> None:
    """The comparison is not blind: the viewer's own card, which it may know, shows."""
    plan = CASES[0].values[0]
    mine = list(plan.dealt)
    taken = mine + list(plan.centre) + list(PAIRED)
    other = next(r for r in ROLE_REGISTRY if r not in taken)
    mine[VIEWER] = other
    changed = Plan(tuple(mine), plan.centre, VIEWER)
    assert first_difference(
        told(django_capture_on_commit_callbacks, Plan(plan.dealt, plan.centre, VIEWER)),
        told(django_capture_on_commit_callbacks, changed),
    )
