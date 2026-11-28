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
- reorders the centre, for a viewer whose night picks from the centre;
- changes the card a pick of the viewer's that reads nothing lands on (the two seats a
  Troublemaker swaps, the centre card the Drunk takes, and either for a Doppelganger
  copying one);
- moves another seat's first vote onto the viewer, or off it.

Everything the viewer is told until the vote's last lock must be byte-identical (what it
is told, and what it may rightly learn: two_deals.py); only that comparison failing says
"learns". Each case also checks, from the database, that its two games really differed in
exactly what it claims to change: a case whose games are the same proves nothing and fails
as a ``ScriptError``, as does a scripted move the server refuses. The cases come from the
engine's role table (each role a viewer, each role a changed card); the routes from the
urlconf.
"""

from __future__ import annotations

from typing import Any

import pytest

from apps.onuw.engine.choose import pick_shapes
from apps.onuw.engine.roles import ROLE_REGISTRY, ActionType
from tests.privacy.sockets import SOCKETS
from tests.privacy.two_deals import (
    CENTRE,
    Plan,
    copies,
    deck_pool,
    first_difference,
    first_shape,
    reads,
    script_check,
    told,
)

pytestmark = [pytest.mark.django_db, pytest.mark.uses_timers]

VIEWER = 1  # never the host (seat 0), never the last to lock its vote
PAIRED = ("Mason",)  # cards a deck holds two of or none (engine/validation.py)
MOVES = {ActionType.SWAP_WITH_PLAYER, ActionType.SWAP_OTHERS}
OWN_MOVES = {ActionType.SWAP_WITH_PLAYER, ActionType.SWAP_WITH_CENTER}
KINDS = ("seat-swap", "hit", "seat-centre", "centre-reorder", "blind-pick")
# The table size each kind is played at. No kind depends on the size (each is about
# which card is where): seat-swap at the larger table, where two werewolves sit more
# often, the rest at the smaller.
SIZE = {"seat-swap": 9}


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


def _copying(role: str, turn: int) -> tuple[tuple[str, ...], tuple[str, ...]]:
    """A deal whose Doppelganger viewer copies ``role``: its look lands on its left-hand
    neighbour, who holds it."""
    for step in range(len(deck_pool())):
        dealt, centre = (list(x) for x in _deal("Doppelganger", 7, turn + step))
        if role not in dealt + centre:
            continue
        where = dealt if role in dealt else centre
        where[where.index(role)], dealt[VIEWER - 1] = dealt[VIEWER - 1], role
        if "Werewolf" in dealt[VIEWER + 1 :] or "Werewolf" in dealt[: VIEWER - 1]:
            return tuple(dealt), tuple(centre)
    raise AssertionError(f"no deal seats a Doppelganger beside a {role}")


def _lone_werewolf() -> tuple[tuple[str, ...], tuple[str, ...]]:
    """A werewolf viewer with no other at the table: it looks at a centre card."""
    dealt, centre = (list(x) for x in _deal("Werewolf", 7, 0))
    for seat, card in enumerate(dealt):
        if card == "Werewolf" and seat != VIEWER:
            spot = next(
                i for i, c in enumerate(centre) if c != "Werewolf" and c not in PAIRED
            )
            dealt[seat], centre[spot] = centre[spot], card
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


def _pairs(kind: str, dealt, centre) -> list[Any]:
    """The changes of one kind the deal allows, in the order they are tried."""
    seats = [s for s in range(len(dealt)) if s != VIEWER]
    centres = [f"c{i}" for i in range(CENTRE)]
    plan = Plan(dealt, centre, VIEWER)
    left = (VIEWER + 1) % len(dealt)  # the seat whose first pick is the viewer
    if kind == "seat-swap":
        return [
            (a, b)
            for a in seats
            for b in seats
            if dealt[a] == "Werewolf" and dealt[b] != "Werewolf"
        ]
    if kind == "hit":
        return [
            (m, left)
            for m in seats
            if _hits_viewer(dealt, dealt[m]) and m != left and not _moves(dealt[left])
        ] + [
            (left, b)
            for b in seats
            if _hits_viewer(dealt, dealt[left]) and not _moves(dealt[b])
        ]
    if kind == "seat-centre":
        wolf = [
            (a, c)
            for a in seats
            for c in centres
            if "Werewolf" in (plan.card(a), plan.card(c))
        ]
        return [
            (a, c)
            for a, c in [*wolf, *((a, c) for a in seats for c in centres)]
            if plan.card(a) != plan.card(c)
        ]
    if kind == "centre-reorder":  # only a viewer whose night picks from the centre
        if not plan.looks_at_centre():
            return []
        return [
            (one, two)
            for one in centres
            for two in centres
            if one < two and plan.card(one) != plan.card(two)
        ]
    landed = plan.blind_landing()  # blind-pick
    return [
        (p, q)
        for p in landed
        for q in [*seats, *centres]
        if q not in landed and plan.card(p) != plan.card(q)
    ]


def _variation(kind: str, dealt, centre) -> Plan | None:
    """The first change of ``kind`` hidden from the viewer by the rule in two_deals.py."""
    for swap in _pairs(kind, dealt, centre):
        plan = Plan(dealt, centre, VIEWER, swap=swap)
        if not plan.hidden_from_viewer() or (kind == "hit" and plan.protected()):
            continue
        if kind == "blind-pick" and not set(plan.blind_landing()) & plan.changed():
            continue
        return plan
    return None


def _changed_cards(plan: Plan) -> set[str]:
    return {plan.card(p) for p in plan.changed()} | {
        plan.other().card(p) for p in plan.changed()
    }


def _case(kind: str, plan: Plan, label: str = "") -> Any:
    viewer = plan.dealt[VIEWER]
    if viewer != plan.viewer_role():
        viewer += f"-as-{plan.viewer_role()}"
    tail = label or "-".join(sorted(_changed_cards(plan)))
    return pytest.param(kind, plan, id=f"{viewer}-{len(plan.dealt)}-{kind}-{tail}")


def _cases() -> list[Any]:
    """Every kind the deal allows for every role as the viewer, each kind at its table
    size. A role with no night action reads nothing of its own, so the sleepers take
    the kinds in turn, one case each. Then a Doppelganger copying each role whose pick
    reads nothing, and every role a changed card at least once."""
    cases, sleepers, deals = [], 0, []
    for turn, role in enumerate(sorted(ROLE_REGISTRY)):
        sized = {size: _deal(role, size, turn) for size in (7, 9)}
        deals += sized.values()
        found = [
            (kind, plan)
            for kind in KINDS
            if (plan := _variation(kind, *sized[SIZE.get(kind, 7)])) is not None
        ]
        if ROLE_REGISTRY[role].wave is None:
            found, sleepers = [found[sleepers % len(found)]], sleepers + 1
        cases += [_case(kind, plan) for kind, plan in found]
    for turn, role in enumerate(sorted(ROLE_REGISTRY)):
        kind = first_shape(role)[0]
        if copies(role) or kind not in ("players", "center") or reads(role, kind):
            continue
        if Plan(*_copying(role, turn), VIEWER).blind_landing():
            plan = _variation("blind-pick", *_copying(role, turn))
            assert plan is not None, f"no blind-pick case for a Doppelganger as {role}"
            cases.append(_case("blind-pick", plan))
    lone = _variation("centre-reorder", *_lone_werewolf())
    assert lone is not None, "no case for a look at the centre that reads"
    cases.append(_case("centre-reorder", lone, label="lone"))
    changed = {c for case in cases for c in _changed_cards(case.values[1])}
    for role in sorted(set(ROLE_REGISTRY) - changed):
        seat_swaps = (
            Plan(dealt, centre, VIEWER, swap=(a, b))
            for dealt, centre in deals
            for a in range(len(dealt))
            for b in range(len(dealt))
            if VIEWER not in (a, b) and dealt[a] == role and dealt[b] != role
        )
        plan = next((p for p in seat_swaps if p.hidden_from_viewer()), None)
        assert plan is not None, f"{role} is never a changed card"
        cases.append(_case("seat-swap", plan, label=f"changes-{role}"))
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


def _landed(facts: dict[str, Any]) -> set[Any]:
    """The places the viewer's own night actions named, from the game's log."""
    out: set[Any] = set()
    for entry in facts["log"]:
        if entry.get("player_id") == facts["ids"][VIEWER]:
            targets = entry.get("targets") or {}
            out |= {facts["ids"].index(i) for i in targets.get("player_ids", [])}
            if "center_index" in targets:
                out.add(f"c{targets['center_index']}")
    return out


def test_the_cases_cover_every_role_every_kind_and_every_pick_that_reads_nothing() -> (
    None
):
    plans = [case.values[1] for case in CASES]
    changed = {c for p in plans for c in _changed_cards(p)}
    assert {p.dealt[VIEWER] for p in plans} == set(ROLE_REGISTRY)
    assert changed == set(ROLE_REGISTRY), (
        f"never a changed card: {set(ROLE_REGISTRY) - changed}"
    )
    assert {case.values[0] for case in CASES} == set(KINDS)
    assert {len(p.dealt) for p in plans} == {7, 9}
    blind = {
        role
        for role in ROLE_REGISTRY
        for kind in ("players", "center")
        if any(kind in shape for shape in pick_shapes(role)) and not reads(role, kind)
    }
    assert blind, "no role picks without reading: the rule reads every pick"
    for role in blind:
        acting = {
            (p.dealt[VIEWER], p.viewer_role())
            for kind, p in (c.values for c in CASES)
            if kind == "blind-pick"
        }
        assert (role, role) in acting, f"{role}'s blind pick is never a case"
        assert ("Doppelganger", role) in acting, f"a Doppelganger as {role}: no case"


@pytest.mark.parametrize("plan", VOTE_CASES)
def test_another_seats_vote_before_the_reveal_never_changes_what_a_seat_is_told(
    plan: Plan, django_capture_on_commit_callbacks: Any
) -> None:
    off, off_facts = told(django_capture_on_commit_callbacks, plan.first())
    onto, onto_facts = told(django_capture_on_commit_callbacks, plan.other())

    votes = list(zip(off_facts["first_votes"], onto_facts["first_votes"], strict=True))
    differ = [seat for seat, (a, b) in enumerate(votes) if a != b]
    script_check(
        differ == [plan.wavering],
        f"the votes did not differ as the case says: {differ}",
    )
    viewer = off_facts["ids"][VIEWER]
    script_check(
        onto_facts["first_votes"][plan.wavering] == viewer,
        "the vote never landed on the viewer",
    )
    script_check(off_facts["first_votes"][plan.wavering] != viewer, "it always did")
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
    script_check(
        moved == plan.changed(), f"the games did not differ as the case says: {moved}"
    )
    if kind == "hit":
        script_check(
            first_facts["now"][VIEWER] != second_facts["now"][VIEWER],
            "the viewer's card was not moved in one game only: the case proves nothing",
        )
    if kind == "blind-pick":
        for facts in (first_facts, second_facts):
            script_check(
                _landed(facts) & plan.changed(),
                f"the viewer's pick {_landed(facts)} missed the changed card",
            )
    beats = {item[1] for item in first if item[0] == "ws" and item[2]["type"] == "beat"}
    script_check(beats == set(SOCKETS), f"only these sockets beat: {beats}")
    difference = first_difference(first, second)
    assert difference is None, (
        f"seat {VIEWER} learns the {kind} of {plan.changed()}: {difference}"
    )


def test_the_comparison_sees_what_the_viewer_may_know(
    django_capture_on_commit_callbacks,
) -> None:
    """Not blind: the viewer's own card, which it may know, shows."""
    plan = next(c.values[1] for c in CASES if len(c.values[1].dealt) == 7)
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
