"""The game phone-frames plays, moment by moment, and the names of its moments.

Two legs. The join leg: a cold load of a table's link, the name, Join, 02 as a guest.
The host leg: a cold load of 01, Start a table, 02, 03 set-up (a deck change, Done),
bots joining, then up to three games, the phone's role set at the deal (a DEBUG
backend's `forced_assignment`, added to the app's own Start request): the Drunk (pick a
card), the Troublemaker (pick players), a Villager (nothing to do). Each game: the deal,
04 (hold the card, Ready), the night, the talk (hold My night, Ready to vote), the vote
(a pick, Lock in), the end board's reveal, Play again.

The script only names moments (`run.tap`, `run.event`, `run.rest`, ...) and asks the
table (`t`: the bots and the server, phone_frames.Table) for what the bots do. So the
same script lists its own moments without a browser (`names()`: `--list`, `--moments`).
"""

import asyncio

# The table's own lengths (its settings): long enough that no stage ends by its clock.
LENGTHS = {
    "card_look_seconds": 60,
    "night_wave_seconds": 60,
    "night_min_window_seconds": 6,
    "night_doppelganger_window_seconds": 0,
    "discussion_seconds": 180,
    "voting_seconds": 120,
}
DECK = {
    "Werewolf": 2,
    "Seer": 1,
    "Troublemaker": 1,
    "Drunk": 1,
    "Villager": 1,
    "Insomniac": 1,
}
# Per game: the phone's role, then Bea's, Cal's and Dan's, and the centre.
GAMES = [
    (
        "Drunk",
        ["Werewolf", "Seer", "Villager"],
        ["Werewolf", "Troublemaker", "Insomniac"],
    ),
    (
        "Troublemaker",
        ["Seer", "Werewolf", "Drunk"],
        ["Werewolf", "Villager", "Insomniac"],
    ),
    (
        "Villager",
        ["Werewolf", "Werewolf", "Insomniac"],
        ["Seer", "Troublemaker", "Drunk"],
    ),
]
BOTS = ["Bea", "Cal", "Dan"]


async def join_leg(run, t):
    code = await t.new_table()
    await run.cold("first screen by a link (join)", f"/join/{code}", ["Join"])
    await run.rest("join screen")
    # No Join: the join screen's name field is focused as it opens, and on the headless
    # phone no touch then lets a name in (its input holds the letters, the app shows
    # none), so every Join here was a tap on a button that does nothing, timed as real
    # (moments.type_name now says so). The host's name on 01 types; the guest's Join
    # waits for that field to be checked on a real phone.


async def host_leg(run, t, games):
    await run.cold("first screen 01 (cold)", "/", ["Start a table"])
    await run.rest("01 first screen")
    await run.type_name("Host")
    # Words, not the QR code: a step's answer is pictured, and each table's code differs.
    await run.tap(
        "Start a table -> 02",
        "^Start a table$",
        ["Need 3 players", "Scan to join"],
        screen=True,
    )
    await run.rest("02 table, alone")
    # Names are not in the semantics; the button says what the table needs.
    # Dan is the fourth: "Start the game" already shows from the third on.
    joined = {"Bea": "~", "Cal": "!Need 3 players", "Dan": "~"}
    for n, button in joined.items():
        await run.event(f"02 {n} joins (socket)", lambda n=n: t.join(n), [button])
    await run.rest("02 table, four seated")
    # The deck panel is one button; its "Edit" is at the top right.
    await run.tap(
        "Edit -> 03 set-up", "^Edit\\s", ["Classic"], at=(0.92, 0.15), screen=True
    )
    await run.rest("03 set-up")
    await run.tap("03 add a Minion", "^Minion$", ["Take one Minion out"])
    await run.tap("03 take it out", "^Take one Minion out", ["!Take one Minion out"])
    await run.tap("Done -> 02", "^Done", ["Start the game", "Need"], screen=True)
    # The table's own lengths and deck, set once the set-up page is closed.
    await t.settings({"deck": "custom", "roles": DECK, **LENGTHS})
    for g, (mine, theirs, centre) in enumerate(GAMES[:games], 1):
        t.force(mine, dict(zip(BOTS, theirs)), centre)
        await game(run, t, g, mine)


async def game(run, t, g, mine):
    tag = f"g{g} {mine}"
    await run.tap(
        f"{tag}: Start the game -> deal -> 04",
        "^Start the game",
        ["Look first"],
        screen=True,
    )
    await run.rest(f"{tag}: 04 your card")
    await run.tap(
        f"{tag}: 04 hold the card",
        "^Your card, hidden",
        ["Ready"],
        # As a person holds: until the card has counted as looked at. On the
        # slowed phone the face shows about 1.2 s after the touch and its timers
        # run up to 1 s late, so 1.6 s raced the count (seen 2.3 s in the app):
        # lost, the phone stayed on 04 and every later moment measured a
        # different screen than it named. Now a lost hold stops the run
        # (moments.py: its answer, Ready, is not where the map pass saw it).
        hold=3.5,
        tolerate=True,
    )
    await run.tap(
        f"{tag}: 04 Ready", "^Ready$", ["Ready ✓", "of 4 ready"], tolerate=True
    )
    await run.event(
        f"{tag}: 04 -> night (others ready)",
        lambda: t.all_ready(look=True),
        ["Choose a card", "Choose", "Nothing to do", "sleeps"],
    )
    await run.rest(f"{tag}: night {mine}", 2.5)
    night = t.night()
    if mine == "Drunk":
        await run.tap(f"{tag}: night pick Left", "^Left", ["Swap with"], tolerate=True)
        await run.tap(f"{tag}: night Swap", "^Swap with", ["Chosen"], tolerate=True)
    elif mine == "Troublemaker":
        await run.tap(
            f"{tag}: night pick Bea", "^Bea", ["Choose 1 more"], tolerate=True
        )
        await run.tap(
            f"{tag}: night pick Cal", "^Cal", ["Swap Bea", "Swap Cal"], tolerate=True
        )
        await run.tap(f"{tag}: night Swap", "^Swap ", ["Chosen"], tolerate=True)
    if mine == "Villager":
        await run.event(
            f"{tag}: night -> talk (window closes)", lambda: night, ["Ready to vote"]
        )
    else:
        # The phone acts last: the talk comes with its own Swap (that tap's final), so
        # there is nothing left to time here (it read "never showed", 30 s lost).
        await run.wait(f"{tag}: night -> talk", lambda: night, ["Ready to vote"])
    await run.rest(f"{tag}: 08 talk", 4)
    await run.tap(
        f"{tag}: 08 hold My night",
        "My night",
        ["Ready to vote"],
        hold=1.5,
        tolerate=True,
    )
    await run.tap(
        f"{tag}: 08 Ready to vote", "^Ready to vote", ["Ready ✓"], tolerate=True
    )
    await run.event(
        f"{tag}: 08 -> 09 vote (others ready)",
        lambda: t.all_ready("discussion"),
        ["Who dies today?", "Pick a name"],
    )
    await run.rest(f"{tag}: 09 vote", 3)
    await run.tap(f"{tag}: 09 pick Bea", "^Bea", ["Lock in Bea"], tolerate=True)
    await run.tap(f"{tag}: 09 Lock in", "^Lock in", ["Locked"], tolerate=True)
    await run.event(f"{tag}: 09 -> end board reveal", t.all_lock, ["Play again"])
    await run.rest(f"{tag}: 12 end board", 3)
    await run.tap(
        f"{tag}: Play again -> 02", "^Play again", ["Start the game"], screen=True
    )
    await run.rest(f"{tag}: 02 table again", 2)


# ---- the moments by name, without a browser ------------------------------------------

# The kinds a verdict compares (a screen at rest has no answer to time).
TIMED = ("tap", "event", "cold")


class _Names:
    """A run that only notes each moment's name, kind and leg."""

    def __init__(self, leg):
        self.leg, self.found = leg, []

    def _note(self, name, kind):
        self.found.append({"name": name, "kind": kind, "leg": self.leg})

    async def cold(self, name, *_a, **_k):
        self._note(name, "cold")

    async def rest(self, name, *_a, **_k):
        self._note(name, "screen")

    async def tap(self, name, *_a, **_k):
        self._note(name, "tap")

    async def event(self, name, *_a, **_k):
        self._note(name, "event")

    async def wait(self, name, *_a, **_k):
        self._note(name, "wait")

    async def type_name(self, *_a, **_k):
        return None


class _NoTable:
    """The bots and the server, doing nothing."""

    async def new_table(self):
        return "CODE"

    async def join(self, _name):
        return None

    async def settings(self, _settings):
        return None

    def force(self, *_a):
        return None

    async def all_ready(self, *_a, **_k):
        return None

    def night(self):
        return None

    async def all_lock(self):
        return None


def names(games=3):
    """Every moment of the script, in order: [{name, kind, leg}]."""

    async def walk():
        join, host = _Names("join"), _Names("host")
        await join_leg(join, _NoTable())
        await host_leg(host, _NoTable(), games)
        return join.found + host.found

    return asyncio.run(walk())


def pick(wanted, games):
    """The moments named by `wanted` (comma-separated, each a case-insensitive part of
    a name), and the fewest games that reach them all. A word that names nothing is a
    LookupError that lists the names."""
    every = names(3)
    timed = [m for m in every if m["kind"] in TIMED]
    if not wanted:
        chosen = [m for m in timed if _game(m) <= games]
        return chosen, games
    chosen, missing = [], []
    for word in [w.strip() for w in wanted.split(",") if w.strip()]:
        hits = [m for m in timed if word.lower() in m["name"].lower()]
        if not hits:
            missing.append(word)
        # Within the games asked for, unless a word names only a later game.
        inside = [m for m in hits if _game(m) <= games] or hits
        chosen += [m for m in inside if m not in chosen]
    if missing:
        raise LookupError(
            f"no moment is named {', '.join(repr(w) for w in missing)}. The moments"
            " (`--list`):\n" + listing(every)
        )
    order = [m["name"] for m in every]
    chosen.sort(key=lambda m: order.index(m["name"]))
    return chosen, max(_game(m) for m in chosen)


def _game(moment):
    name = moment["name"]
    return int(name[1]) if name[:1] == "g" and name[1:2].isdigit() else 0


def listing(moments):
    return "\n".join(
        f"  {m['kind']:6} {m['name']}" for m in moments if m["kind"] in TIMED
    )


# Each moment in the owner's words (`just speed-verdict`'s sentence), by its name
# without the game ("g1 Drunk: ").
PLAIN = {
    "first screen by a link (join)": "opening a table's link",
    "first screen 01 (cold)": "opening the app",
    "Start a table -> 02": "Start a table",
    "02 Bea joins (socket)": "a friend joining",
    "02 Cal joins (socket)": "a friend joining",
    "02 Dan joins (socket)": "a friend joining",
    "Edit -> 03 set-up": "opening the set-up",
    "03 add a Minion": "adding a role",
    "03 take it out": "taking a role out",
    "Done -> 02": "Done on the set-up",
    "Start the game -> deal -> 04": "Start the game",
    "04 hold the card": "holding your card",
    "04 Ready": "Ready on your card",
    "04 -> night (others ready)": "the night arriving",
    "night pick Left": "picking a card at night",
    "night pick Bea": "picking a player at night",
    "night pick Cal": "picking a player at night",
    "night Swap": "Swap at night",
    "night -> talk (window closes)": "the talk arriving",
    "08 hold My night": "holding My night",
    "08 Ready to vote": "Ready to vote",
    "08 -> 09 vote (others ready)": "the vote arriving",
    "09 pick Bea": "picking a name to vote",
    "09 Lock in": "Lock in",
    "09 -> end board reveal": "the end board arriving",
    "Play again -> 02": "Play again",
}


def plain(name):
    """The owner's words for a moment (its name when it has none yet)."""
    return PLAIN.get(name.split(": ", 1)[-1], name)


def describe():
    return (
        "The moments of the game, in order, as `--moments` names them (a part of a\n"
        "name is enough: 'hold the card' is each game's hold; with `--moments`, only\n"
        "the games they need are played):\n" + listing(names(3))
    )


if __name__ == "__main__":
    print(describe())
