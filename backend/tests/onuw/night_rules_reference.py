"""Reference night models written straight from the rules, plus a bridge to the engine.

Test support only. These are deliberately independent of the engine so the
engine can be checked against them.

A "game" is: dealt (list of role per player), center (3 roles), choices (dict).
choices keys (all optional; missing = the player does nothing):
  doppel_target: player id the Doppelganger looks at
  doppel_follow: the Doppelganger's immediate action if it copied Seer/Robber/Troublemaker/Drunk
                 (same shape as the matching role's choice below)
  wolf_center:   center index a lone Werewolf looks at
  seer:          ("player", pid) or ("center", [i, j])
  robber:        pid
  troublemaker:  [pid_a, pid_b]
  drunk:         center index
Views are recorded as {player id: [(kind, value), ...]} in the order that player learned them.
"""

from __future__ import annotations

import copy
import random
from typing import Any

ACTING_NOW = {"Seer", "Robber", "Troublemaker", "Drunk"}


def _who(dealt, role):
    return [p for p, r in enumerate(dealt) if r == role]


def _doppel_window(dealt, center, choices):
    """Step 1 in both models: the Doppelganger looks, copies, and acts at once if the role acts."""
    cards = list(dealt)
    center = list(center)
    views: dict[int, list[tuple[str, Any]]] = {p: [] for p in range(len(dealt))}
    copied = None
    d = _who(dealt, "Doppelganger")
    if d and choices.get("doppel_target") is not None:
        me = d[0]
        copied = cards[choices["doppel_target"]]
        views[me].append(("copied", copied))
        f = choices.get("doppel_follow")
        if copied == "Minion":
            views[me].append(("werewolves", tuple(_who(dealt, "Werewolf"))))
        elif copied in ACTING_NOW and f is not None:
            if copied == "Seer":
                if f[0] == "player":
                    views[me].append(("saw_player", (f[1], cards[f[1]])))
                else:
                    views[me].append(
                        ("saw_center", tuple((i, center[i]) for i in f[1]))
                    )
            elif copied == "Robber":
                views[me].append(("took", cards[f]))
                cards[me], cards[f] = cards[f], cards[me]
            elif copied == "Troublemaker":
                a, b = f
                cards[a], cards[b] = cards[b], cards[a]
            elif copied == "Drunk":
                cards[me], center[f] = center[f], cards[me]
    return cards, center, views, copied, (d[0] if d else None)


def _teams(dealt, copied, doppel):
    wolves = _who(dealt, "Werewolf") + ([doppel] if copied == "Werewolf" else [])
    masons = _who(dealt, "Mason") + ([doppel] if copied == "Mason" else [])
    return sorted(wolves), sorted(masons)


def sequential(dealt, center, choices):
    """Role by role, in the official wake order. Every step reads the table as it is at that moment."""
    cards, center, views, copied, doppel = _doppel_window(dealt, center, choices)
    wolves, masons = _teams(dealt, copied, doppel)
    for w in wolves:
        views[w].append(("werewolves", tuple(x for x in wolves if x != w)))
    if len(wolves) == 1 and choices.get("wolf_center") is not None:
        i = choices["wolf_center"]
        views[wolves[0]].append(("saw_center", ((i, center[i]),)))
    for m in _who(dealt, "Minion"):
        views[m].append(("werewolves", tuple(wolves)))
    for m in masons:
        views[m].append(("masons", tuple(x for x in masons if x != m)))
    for s in _who(dealt, "Seer"):
        c = choices.get("seer")
        if c:
            if c[0] == "player":
                views[s].append(("saw_player", (c[1], cards[c[1]])))
            else:
                views[s].append(("saw_center", tuple((i, center[i]) for i in c[1])))
    for r in _who(dealt, "Robber"):
        t = choices.get("robber")
        if t is not None:
            views[r].append(("took", cards[t]))
            cards[r], cards[t] = cards[t], cards[r]
    for _ in _who(dealt, "Troublemaker"):
        t = choices.get("troublemaker")
        if t:
            cards[t[0]], cards[t[1]] = cards[t[1]], cards[t[0]]
    for k in _who(dealt, "Drunk"):
        i = choices.get("drunk")
        if i is not None:
            cards[k], center[i] = center[i], cards[k]
    for n in _who(dealt, "Insomniac"):
        views[n].append(("own_card", cards[n]))
    if copied == "Insomniac":
        assert doppel is not None  # only a Doppelganger can have copied
        views[doppel].append(("own_card", cards[doppel]))
    return cards, center, views, copied


def shared_window(dealt, center, choices):
    """Doppelganger window, then ONE window where everyone chooses at once.

    Everything a player is shown in the shared window is read from a frozen photograph of the
    table taken when that window opens. Only afterwards are the swaps applied, in the official
    order. The Insomniac is answered last, from the finished table.
    """
    cards, center, views, copied, doppel = _doppel_window(dealt, center, choices)
    photo_cards, photo_center = tuple(cards), tuple(center)  # frozen
    wolves, masons = _teams(dealt, copied, doppel)

    # --- shown at once, from the photograph ---
    for w in wolves:
        views[w].append(("werewolves", tuple(x for x in wolves if x != w)))
    if len(wolves) == 1 and choices.get("wolf_center") is not None:
        i = choices["wolf_center"]
        views[wolves[0]].append(("saw_center", ((i, photo_center[i]),)))
    for m in _who(dealt, "Minion"):
        views[m].append(("werewolves", tuple(wolves)))
    for m in masons:
        views[m].append(("masons", tuple(x for x in masons if x != m)))
    for s in _who(dealt, "Seer"):
        c = choices.get("seer")
        if c:
            if c[0] == "player":
                views[s].append(("saw_player", (c[1], photo_cards[c[1]])))
            else:
                views[s].append(
                    ("saw_center", tuple((i, photo_center[i]) for i in c[1]))
                )
    for r in _who(dealt, "Robber"):
        t = choices.get("robber")
        if t is not None:
            views[r].append(("took", photo_cards[t]))

    # --- after the window closes: apply swaps in the official order ---
    for r in _who(dealt, "Robber"):
        t = choices.get("robber")
        if t is not None:
            cards[r], cards[t] = cards[t], cards[r]
    for _ in _who(dealt, "Troublemaker"):
        t = choices.get("troublemaker")
        if t:
            cards[t[0]], cards[t[1]] = cards[t[1]], cards[t[0]]
    for k in _who(dealt, "Drunk"):
        i = choices.get("drunk")
        if i is not None:
            cards[k], center[i] = center[i], cards[k]

    # --- dawn ---
    for n in _who(dealt, "Insomniac"):
        views[n].append(("own_card", cards[n]))
    if copied == "Insomniac":
        assert doppel is not None  # only a Doppelganger can have copied
        views[doppel].append(("own_card", cards[doppel]))
    return cards, center, views, copied


def engine(dealt, center, choices):
    """The same game through the project's real rules engine (role by role, as built today)."""
    n = len(dealt)
    final, results = engine_night(dealt, center, choices)
    views: dict[int, list[tuple[str, Any]]] = {p: [] for p in range(n)}
    for res in results:
        _record_view(views, res)
    cards = [final.player_roles[p] for p in range(n)]
    return cards, list(final.center_cards), views, dict(final.doppelganger_copied_role)


def engine_night(dealt, center, choices, ids=None):
    """The night through the real engine, collecting actions the way the server does.

    ``night_window._collect_window_actions`` asks ``get_required_actions_for_window`` who
    acts, which walks the dealt cards in SEAT order (so a Minion can sit between two
    Werewolves) and appends a Doppelganger's follow-up last; the window is then
    resolved with ``resolve_window``, the Doppelganger's look having been resolved on
    its own when she submitted it. This does the same, so the log has the order
    production writes, not an order built by hand.

    ``dealt[i]`` is the card of the player in seat ``i`` and ``ids[i]`` that
    player's user id (default: the seat index). ``choices`` name players by seat.
    Returns (final GameState with its action log, the results in resolution order).
    """
    from apps.onuw.engine import (
        GameState,
        NightAction,
        get_doppelganger_followup_wave,
        get_required_actions_for_window,
        resolve_wave,
        resolve_window,
    )
    from apps.onuw.engine.behaviors import is_effective_werewolf

    ids = list(range(len(dealt))) if ids is None else list(ids)
    roles = {ids[seat]: role for seat, role in enumerate(dealt)}  # seat order
    state = GameState(
        player_roles=dict(roles),
        center_cards=list(center),
        original_roles=dict(roles),
    )
    doppelganger = next(
        (uid for uid, role in roles.items() if role == "Doppelganger"), None
    )

    def chosen(role, uid, c):
        if role == "Seer":
            if c[0] == "player":
                return NightAction(uid, "Seer", "peek_player", {"player_id": ids[c[1]]})
            return NightAction(
                uid, "Seer", "peek_center", {"center_indices": list(c[1])}
            )
        if role == "Robber":
            return NightAction(uid, "Robber", "swap_with_player", {"player_id": ids[c]})
        if role == "Troublemaker":
            return NightAction(
                uid, "Troublemaker", "swap_others", {"player_ids": [ids[x] for x in c]}
            )
        return NightAction(uid, "Drunk", "swap_with_center", {"center_index": c})

    def action_for(uid, role, state):
        """What a player submits, or its role's automatic default (None: nothing)."""
        if role in ("Minion", "Mason"):
            return NightAction(uid, role, "see_team", {})
        if role == "Insomniac":
            return NightAction(uid, role, "none", {})
        if role == "Werewolf":
            lone = sum(is_effective_werewolf(p, state) for p in state.player_roles) == 1
            peek = choices.get("wolf_center")
            targets = {"center_index": peek} if lone and peek is not None else {}
            return NightAction(uid, role, "see_team", targets)
        key = {"Seer": "seer", "Robber": "robber", "Troublemaker": "troublemaker"}.get(
            role, "drunk"
        )
        pick = choices.get("doppel_follow") if uid == doppelganger else choices.get(key)
        if pick is not None:
            return chosen(role, uid, pick)
        return NightAction(uid, role, "skip", {}) if role != "Drunk" else None

    results: list = []
    # Window 1: the look is resolved on its own, then the close brings the follow-up.
    if doppelganger is not None and choices.get("doppel_target") is not None:
        look = NightAction(
            doppelganger,
            "Doppelganger",
            "peek_player",
            {"player_id": ids[choices["doppel_target"]]},
        )
        state, got = resolve_wave(state, [look], 1)  # as resolve_doppelganger_look
        results += got
        copied = state.doppelganger_copied_role[doppelganger]
        if get_doppelganger_followup_wave(copied) == 1:
            follow = action_for(doppelganger, copied, state)
            state, got = resolve_window(state, [follow] if follow else [], 1)
            results += got
    # Window 2: everyone who acts, in the order the server collects them.
    prompts = get_required_actions_for_window(state, 2, state.doppelganger_copied_role)
    window_two = [
        action_for(p["player_id"], p["role_acting_as"], state) for p in prompts
    ]
    state, got = resolve_window(state, [a for a in window_two if a], 2)
    results += got
    return state, results


def _record_view(views, res):
    info = res.revealed_info
    p = res.player_id
    if "copied_role" in info:
        views[p].append(("copied", info["copied_role"]))
    if "werewolves" in info:
        views[p].append(("werewolves", tuple(sorted(info["werewolves"]))))
    if "center_card" in info:
        cc = info["center_card"]
        views[p].append(("saw_center", ((cc["index"], cc["role"]),)))
    if "masons" in info:
        views[p].append(("masons", tuple(sorted(info["masons"]))))
    if "peeked_role" in info:
        views[p].append(("saw_player_role", info["peeked_role"]))
    if "peeked_center" in info:
        views[p].append(
            (
                "saw_center",
                tuple((x["index"], x["role"]) for x in info["peeked_center"]),
            )
        )
    if "new_role" in info:
        views[p].append(("took", info["new_role"]))
    if "current_role" in info:
        views[p].append(("own_card", info["current_role"]))


def normalise(views):
    """Make the rule models comparable with the engine (which reports a peeked role without the target)."""
    out = copy.deepcopy(views)
    for p, items in out.items():
        out[p] = [
            ("saw_player_role", v[1])
            if k == "saw_player"
            else (k, tuple(sorted(v)) if k in ("werewolves", "masons") else v)
            for k, v in items
        ]
    return out


# --- random games -----------------------------------------------------------

POOL = (
    ["Werewolf"] * 2
    + ["Mason"] * 2
    + ["Villager"] * 3
    + [
        "Minion",
        "Seer",
        "Robber",
        "Troublemaker",
        "Drunk",
        "Insomniac",
        "Hunter",
        "Tanner",
        "Doppelganger",
    ]
)


def _pick(rng, role, me, n):
    others = [p for p in range(n) if p != me]
    if role == "Seer":
        return (
            ("player", rng.choice(others))
            if rng.random() < 0.5
            else ("center", rng.sample(range(3), 2))
        )
    if role == "Robber":
        return rng.choice(others)
    if role == "Troublemaker":
        return rng.sample(others, 2) if len(others) >= 2 else None
    if role == "Drunk":
        return rng.randrange(3)


def random_game(rng: random.Random):
    n = rng.randint(3, 10)
    deck = rng.sample(POOL, n + 3)
    rng.shuffle(deck)
    dealt, center = deck[:n], deck[n:]
    ch: dict[str, Any] = {}

    def skip():
        return rng.random() < 0.15

    d = _who(dealt, "Doppelganger")
    if d and not skip():
        t = rng.choice([p for p in range(n) if p != d[0]])
        ch["doppel_target"] = t
        if dealt[t] in ACTING_NOW and not skip():
            ch["doppel_follow"] = _pick(rng, dealt[t], d[0], n)
    if not skip():
        ch["wolf_center"] = rng.randrange(3)
    for role, key in (
        ("Seer", "seer"),
        ("Robber", "robber"),
        ("Troublemaker", "troublemaker"),
        ("Drunk", "drunk"),
    ):
        p = _who(dealt, role)
        if p and not skip():
            c = _pick(rng, role, p[0], n)
            if c is not None:
                ch[key] = c
    return dealt, center, ch
