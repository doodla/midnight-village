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
    for wave in (1, 2, 3, 4):
        for res in results.get(wave, []):
            _record_view(views, res)
    cards = [final.player_roles[p] for p in range(n)]
    return cards, list(final.center_cards), views, dict(final.doppelganger_copied_role)


def engine_night(dealt, center, choices):
    """The night through the real engine: (final GameState with its action log, results by group)."""
    from apps.onuw.engine import GameState, NightAction, resolve_night

    state = GameState(
        player_roles=dict(enumerate(dealt)),
        center_cards=list(center),
        original_roles=dict(enumerate(dealt)),
    )
    acts = {1: [], 2: [], 3: [], 4: []}

    def role_action(pid, role, c):
        if role == "Seer":
            if c[0] == "player":
                return NightAction(pid, "Seer", "peek_player", {"player_id": c[1]})
            return NightAction(
                pid, "Seer", "peek_center", {"center_indices": list(c[1])}
            )
        if role == "Robber":
            return NightAction(pid, "Robber", "swap_with_player", {"player_id": c})
        if role == "Troublemaker":
            return NightAction(
                pid, "Troublemaker", "swap_others", {"player_ids": list(c)}
            )
        if role == "Drunk":
            return NightAction(pid, "Drunk", "swap_with_center", {"center_index": c})
        raise AssertionError(role)

    d = _who(dealt, "Doppelganger")
    copied = None
    if d and choices.get("doppel_target") is not None:
        me = d[0]
        copied = dealt[choices["doppel_target"]]
        acts[1].append(
            NightAction(
                me,
                "Doppelganger",
                "peek_player",
                {"player_id": choices["doppel_target"]},
            )
        )
        if copied == "Minion":
            acts[1].append(NightAction(me, "Minion", "see_team", {}))
        elif copied in ACTING_NOW and choices.get("doppel_follow") is not None:
            acts[1].append(role_action(me, copied, choices["doppel_follow"]))
        elif copied in ("Werewolf", "Mason"):
            acts[2].append(NightAction(me, copied, "see_team", {}))
        elif copied == "Insomniac":
            acts[4].append(NightAction(me, "Insomniac", "none", {}))
    wolves, _ = _teams(dealt, copied, d[0] if d else None)
    for w in _who(dealt, "Werewolf"):
        t = {}
        if len(wolves) == 1 and choices.get("wolf_center") is not None:
            t = {"center_index": choices["wolf_center"]}
        acts[2].append(NightAction(w, "Werewolf", "see_team", t))
    for m in _who(dealt, "Minion"):
        acts[2].append(NightAction(m, "Minion", "see_team", {}))
    for m in _who(dealt, "Mason"):
        acts[2].append(NightAction(m, "Mason", "see_team", {}))
    for role, key in (
        ("Seer", "seer"),
        ("Robber", "robber"),
        ("Troublemaker", "troublemaker"),
        ("Drunk", "drunk"),
    ):
        for p in _who(dealt, role):
            if choices.get(key) is not None:
                acts[3].append(role_action(p, role, choices[key]))
    for p in _who(dealt, "Insomniac"):
        acts[4].append(NightAction(p, "Insomniac", "none", {}))

    return resolve_night(state, acts)


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
