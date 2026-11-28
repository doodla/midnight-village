"""The tap/hold check: on the real game, a quick touch does a part's tap thing and
never its hold thing, and a held one does the hold thing, at each CPU speed.

One phone (headless Chrome, the release web build) hosts a table with three bots
(`tool/phone_frames/`'s): 03 (a role card, the players label), the deal, 04 (the
card), the night (the phone's own card), the talk (My night). Each part is touched
`--touches` times for each quick length under its hold time (by the touch's own
pointer times, read in the page) and LONG times for a long one, at each speed
(`Emulation.setCPUThrottlingRate`) and in each `--busy` row: the page idle, and the
page's main thread kept busy from the landing to past the hold (a phone's long
frame), where Chrome hands the app the lift frames late.
The touches land on the app, as on a phone with no screen reader; the semantics are
on only to be read, and are read once a touch has settled (what they said meanwhile
was recorded as it changed): a read during a touch is page work that changes it.
Semantics off is not covered. The parts and their hold times come from the code
(`parts.py`). Exits 1 when a part did the wrong thing, 2 when the game could not be
played. Run through `just tap-hold`.
"""

import argparse
import asyncio
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "phone_frames"))
from moments import Run
from page_probe import NODES, RECORDER, Page
from parts import PARTS, hold_ms, lift_frames
from phone_frames import DECK, UA, Bots
from playwright.async_api import async_playwright

QUICK = (80, 150)
LONG = 3  # long touches per part, speed and row: a hold either works or it does not
# The table's own lengths: long enough for every touch (the night is closed by
# the debug backend's timer once its part is done).
LENGTHS = {
    "card_look_seconds": 120,
    "night_wave_seconds": 3600,
    "night_min_window_seconds": 6,
    "night_doppelganger_window_seconds": 0,
    "discussion_seconds": 3600,
    "voting_seconds": 120,
}
# Each touch, recorded by the page as it happens and read once it settled: the
# landing and the lift (their own times and when they reached the page), the
# frames the app began, and every value the semantics' labels and texts took.
TH = r"""
(() => {
  const T = window.__th = {on: false, downs: [], ups: [], muts: []};
  for (const [k, l] of [['pointerdown', 'downs'], ['pointerup', 'ups']])
    addEventListener(k, e => T.on && T[l].push([e.timeStamp, performance.now()]), true);
  new MutationObserver(rs => { if (T.on) T.muts.push(...rs); }).observe(document, {
    subtree: true, childList: true, attributes: true, attributeFilter: ['aria-label'],
    attributeOldValue: true, characterData: true, characterDataOldValue: true});
})();
"""
# What a semantics node says: its label, or a leaf's text (as `NODES` names it).
NAME = "const name = e => (e.getAttribute('aria-label') || '') || (e.childElementCount ? '' : (e.textContent || ''));"
# Each node's name as the touch starts, kept on the node.
START = (
    "() => { "
    + NAME
    + " const T = window.__th; T.downs = []; T.ups = []; T.muts = []; T.on = true;"
    " for (const e of document.querySelectorAll('flt-semantics')) e.__th = name(e);"
    " return window.__pf.frames.length; }"
)
# Every name a node took during the touch other than the one it had (a node
# added since had none): its label's or its text's old values, the text taken
# out of it, and what it says now.
SETTLED = (
    r"""(from) => {
  const T = window.__th; T.on = false;
  """
    + NAME
    + r"""
  const took = new Map();
  const add = (e, v) => { if (!e) return; if (!took.has(e)) took.set(e, new Set()); took.get(e).add(v); };
  const all = e => { if (!e.getAttribute) return; add(e, name(e)); for (const c of e.children) all(c); };
  for (const r of T.muts) {
    const e = r.type === 'characterData' ? r.target.parentElement : r.target;
    if (r.oldValue !== null) add(e, r.oldValue);
    for (const n of [...r.removedNodes, ...r.addedNodes]) n.nodeType === 3 ? add(e, n.textContent) : all(n);
    all(e);
  }
  const shown = [];
  for (const [e, vs] of took) for (const v of vs) if (v && v !== (e.__th || '')) shown.push(v);
  return {downs: T.downs, ups: T.ups, shown, frames: window.__pf.frames.slice(from).map(f => f[0])};
}"""
)
# The page busy, from the landing (its own time) until `until` ms after it.
BUSY = """(until) => { const t0 = performance.now(); const d = window.__th.downs[0];
  const end = (d ? d[0] : t0) + until; while (performance.now() < end) {}
  return [t0, performance.now()]; }"""


def lift(timing):
    """When the lift reached the page: ms after it was made (its own time, set
    right by the landing, which reached a free page at once), and after the busy
    spell ended, and the frames the app began between the spell's end (or the
    lift's own time) and it."""
    if not timing["up"] or not timing["down"]:
        return {}
    (dstamp, dcame), (stamp, came) = timing["down"][0], timing["up"][0]
    made = stamp + (dcame - dstamp)
    out = {"late": round(came - made)}
    since = made
    if timing["spell"]:
        since = timing["spell"][1]
        out["after_spell"] = round(came - since)
    out["frames"] = sum(1 for f in timing["frames"] if since <= f < came)
    return out


FIX = "see frontend/lib/design_system/primitives/finger_hold.dart: a touch shorter than the hold time by its own timestamps is a tap"


def long_ms(part, hold, timings):
    """A long touch: 500 ms, or twice the hold where 500 is not past it. A face
    that shows only while held is held past the hold by `liftFrames` + 3 of the
    page's long frames (the 90th of every 100 gaps between the frames the app drew
    in the quick touches so far at this speed): on a page blocked across the hold the face shows
    up to `liftFrames` frames late (finger_hold.dart), after the frame that blocked
    the timer, and must be drawn once; one more for headroom."""
    ms = 500 if hold < 400 else 2 * hold
    gaps = sorted(
        b - a
        for t in timings
        for a, b in zip(t["frames"], t["frames"][1:])
        if b - a < 1500  # longer: the page was still, not drawing
    )
    # none drawn yet at this speed (a part checked alone): a long frame of a slow phone
    frame = gaps[9 * len(gaps) // 10] if gaps else 1000
    return max(ms, round(hold + (lift_frames() + 3) * frame)) if part.while_held else ms


class Toucher:
    def __init__(self, run, args):
        self.run, self.P, self.args = run, run.P, args
        self.results = []  # (part, cpu, kind, nominal ms, measured ms, hold ms, tapped, held)
        self.started = time.monotonic()

    async def finger(self, x, y, ms, busy=None):
        """Down, and up `ms` later, each stamped with its own time as a phone
        stamps a finger's: Chrome takes a lift sent while the page is busy only
        once it is free, and would time it then. `busy`: once the landing is
        delivered, the page's main thread is kept busy until that many ms after
        it (a frame of a slow phone: a socket event rebuilding, art decoding)."""
        cdp = self.P.cdp
        point = [{"x": x, "y": y, "radiusX": 6, "radiusY": 6, "force": 1}]
        down = time.time()
        await cdp.send(
            "Input.dispatchTouchEvent",
            {"type": "touchStart", "touchPoints": point, "timestamp": down},
        )
        spell = None
        if busy:
            spell = asyncio.ensure_future(self.P.page.evaluate(BUSY, busy))
        await asyncio.sleep(max(0.0, down + ms / 1000 - time.time()))
        await cdp.send(
            "Input.dispatchTouchEvent",
            {"type": "touchEnd", "touchPoints": [], "timestamp": down + ms / 1000},
        )
        return await spell if spell else None

    async def has(self, words):
        return words in await self.P.text()

    async def one(self, part, box, ms, busy):
        P = self.P
        text = await P.text()
        before = {w: text.count(w) for _, w in filter(None, (part.tap, part.held))}
        frames = await P.page.evaluate(START)
        x, y = box["x"] + box["w"] * part.at[0], box["y"] + box["h"] * part.at[1]
        spell = await self.finger(x, y, ms, hold_ms(part) + busy if busy else None)
        await asyncio.sleep(0.3)
        await self.run.quiet(gap=0.5, most=8)
        # Read only now, the touch settled: what the semantics said meanwhile
        # was recorded as it changed (`TH`), not read while the finger was down.
        got = await P.page.evaluate(SETTLED, frames)
        downs, ups = got["downs"], got["ups"]
        length = round(ups[0][0] - downs[0][0]) if downs and ups else None
        timing = {
            "down": downs[:1],
            "up": ups[:1],
            "spell": spell,
            "frames": got["frames"],
        }

        def flipped(words):
            return (before[words] > 0) != (words in text)

        text = await P.text()
        tapped = flipped(part.tap[1]) if part.tap else False
        kind, words = part.held
        if kind == "shows":
            # a node said exactly the words, which it did not say before the touch
            held = words in got["shown"]
        elif kind == "count":
            held = before[words] != text.count(words)
        else:
            held = flipped(words)
        return length, tapped, held, timing

    async def part(self, part, cpu):
        hold = hold_ms(part)
        box = await self.P.find(part.find)
        if self.args.dump:
            print(f"--- {part.name} at {cpu}x, hold {hold} ms, box {box}", flush=True)
        for busy in (int(b) for b in self.args.busy.split(",")):
            plan = [
                ("quick", q)
                for q in QUICK
                if q < hold
                for _ in range(min(self.args.touches, part.most or self.args.touches))
            ]
            plan += [("long", None)] * min(LONG, part.most or LONG)
            long = None
            for kind, ms in plan:
                if ms is None:
                    # once per row, after its quick touches: the frames at this speed are known
                    long = long or long_ms(
                        part,
                        hold,
                        [r[9] for r in self.results if r[1] == cpu and r[3] == "quick"],
                    )
                    ms = long
                if part.tap and part.tap[0] == "flips" and part.name.startswith("03"):
                    # a tap adds a Minion: each touch starts from none
                    if await self.has(part.tap[1]):
                        await self.run.tap(
                            "minion out", f"^{part.tap[1]}", [f"!{part.tap[1]}"]
                        )
                # found again each time: a tap can move the page (03 scrolls its count into view)
                box = await self.P.find(part.find)
                length, tapped, held, timing = await self.one(part, box, ms, busy)
                self.results.append(
                    (part.name, cpu, busy, kind, ms, length, hold, tapped, held, timing)
                )
                if self.args.dump:
                    print(
                        f"   busy {busy} {kind} {ms} ms: measured {length}, tap {tapped},"
                        f" hold {held}, {lift(timing)}",
                        flush=True,
                    )
                if held:
                    await self.undo(part)

    async def undo(self, part):
        """Put a hold's sheet away (a touch on the page's top, above any sheet)."""
        if part.held[0] == "shows" and part.held[1] == "Close":
            await self.finger(206, 30, 60)
            await asyncio.sleep(0.3)
            await self.run.quiet(gap=0.5, most=8)


async def speeds(t, part, cpus):
    for cpu in cpus:
        await t.P.cdp.send("Emulation.setCPUThrottlingRate", {"rate": cpu})
        await t.part(part, cpu)
    await t.P.cdp.send("Emulation.setCPUThrottlingRate", {"rate": 1})


async def play(args):
    api = args.api.rstrip("/") + "/api"
    bots = Bots(api)
    names = ["Bea", "Cal", "Dan"]
    for n in names:
        await bots.guest(n)
    want = [
        p
        for p in PARTS
        if not args.parts or any(w in p.name for w in args.parts.split(","))
    ]
    by = {p.name: p for p in want}
    cpus = [float(c) for c in args.speeds.split(",")]
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(
            executable_path=args.chrome or None,
            args=[
                "--no-sandbox",
                "--enable-unsafe-swiftshader",
                "--ignore-gpu-blocklist",
            ],
        )
        ctx = await browser.new_context(
            viewport={"width": 412, "height": 915},
            device_scale_factor=2.625,
            is_mobile=True,
            has_touch=True,
            user_agent=UA,
        )
        page = await ctx.new_page()
        await page.add_init_script(RECORDER)
        await page.add_init_script(TH)
        if args.dump:
            page.on(
                "console",
                lambda m: (
                    m.text.startswith("th: ") and print("     " + m.text, flush=True)
                ),
            )
        cdp = await ctx.new_cdp_session(page)
        P = Page(page, cdp)
        run = Run(args, P, bots, {}, False)
        t = Toucher(run, args)
        me, seen, tokens, forced = {}, {}, {}, {}

        async def response(resp):
            if resp.request.method != "POST" or resp.status != 201:
                return
            if resp.url.endswith("/auth/guest/"):
                me.update((await resp.json())["user"])
            elif resp.url.endswith("/api/lobbies/"):
                seen["code"] = (await resp.json())["code"]
            elif resp.url.endswith("/start/"):
                seen["game"] = (await resp.json())["game_id"]

        page.on("response", response)
        page.on(
            "request",
            lambda r: (
                tokens.__setitem__("h", r.headers["authorization"])
                if "authorization" in r.headers
                else None
            ),
        )

        async def start_route(route):
            if route.request.method != "POST":
                await route.continue_()
                return
            body = json.loads(route.request.post_data or "{}")
            body["debug"] = {"forced_assignment": forced}
            await route.continue_(post_data=json.dumps(body))

        await page.route("**/onuw/lobbies/*/start/", start_route)
        await run.cold("01", args.app + "/", ["Start a table"])
        await run.type_name("Host")
        await run.tap("start", "^Start a table$", ["Scan to join"])
        code = seen["code"]
        for n in names:
            await bots.call("POST", f"/lobbies/{code}/join/", n)
        await P.want(["Start the game"])
        if await P.seen(30) is None:
            raise LookupError("02: the bots never sat down")
        await run.tap("edit", "^Edit\\s", ["Classic"], at=(0.92, 0.15))
        await run.quiet()
        lowers = (await P.text()).count("Lower")
        # A finger lands where it does on a phone with no screen reader: on
        # the app, not on a semantics node (where Flutter holds a landing back
        # up to 200 ms to see if a click follows, and a quick touch is then a
        # semantics tap, whatever the hold does). The semantics are only read.
        await page.add_style_tag(
            content="flt-semantics, flt-semantics * { pointer-events: none !important; }"
        )
        for name in ("03 role card", "03 players label"):
            if name in by:
                await speeds(t, by[name], cpus)
        # The deck as it was: no Minion, no practice players.
        if await t.has("Take one Minion out"):
            await run.tap(
                "minion out", "^Take one Minion out", ["!Take one Minion out"]
            )
        label = next(p for p in PARTS if p.name == "03 players label")
        if (await P.text()).count("Lower") != lowers:
            box = await P.find(label.find)
            await t.finger(
                box["x"] + box["w"] * label.at[0], box["y"] + box["h"] / 2, 1200
            )
            await run.quiet()
        await run.tap("done", "^Done", ["Start the game", "Need"])
        host = {"Authorization": tokens["h"]}
        r = await bots.c.patch(
            api + f"/lobbies/{code}/",
            headers=host,
            json={"settings": {"deck": "custom", "roles": DECK, **LENGTHS}},
        )
        if r.status_code != 200:
            raise RuntimeError(
                f"the table's settings were refused: {r.status_code} {r.text[:300]}"
            )
        forced["player_roles"] = {
            str(me["id"]): "Drunk",
            **{
                str(bots.players[n][0]): role
                for n, role in zip(names, ["Werewolf", "Seer", "Villager"])
            },
        }
        forced["center"] = ["Werewolf", "Troublemaker", "Insomniac"]
        await run.tap("deal", "^Start the game", ["Look first"])
        game = seen["game"]
        await run.quiet()
        if "04 your card" in by:
            await speeds(t, by["04 your card"], cpus)
        box = await P.find("^Your card, hidden")
        await t.finger(box["x"] + box["w"] / 2, box["y"] + box["h"] / 2, 3500)
        await run.tap("ready", "^Ready$", ["Ready ✓", "of 4 ready"], tolerate=True)
        for n in names:
            await bots.staged(game, n, "ready", {"ready": True}, look=True)
        await P.want(["Choose a card", "Choose"])
        if await P.seen(60) is None:
            raise LookupError("the night never opened")
        await run.quiet()
        if "06 own night card" in by:
            await speeds(t, by["06 own night card"], cpus)
        night = asyncio.ensure_future(bots.night(game, names))
        for _ in range(20):
            if (await bots.me(game, "Bea")).get("phase") != "night":
                break
            await bots.call(
                "POST",
                f"/onuw/games/{game}/debug-fire-timer/",
                "Bea",
                json={"key": "current"},
            )
            await asyncio.sleep(1)
        night.cancel()
        await P.want(["Ready to vote"])
        if await P.seen(60) is None:
            raise LookupError("the talk never opened")
        await run.quiet()
        if args.dump:
            print(f"--- 08 arrived: {await page.evaluate(NODES)}", flush=True)
        # My night comes up by itself the first time: a touch at the edge puts it away.
        await t.finger(4, 400, 60)
        await run.quiet()
        if "08 My night" in by:
            await speeds(t, by["08 My night"], cpus)
        await browser.close()
    return t.results


def verdicts(results):
    """Each part, speed, busy spell and length: the failures, as a failure says them."""
    groups = {}
    for name, cpu, busy, kind, ms, length, hold, tapped, held, _ in results:
        groups.setdefault((name, cpu, busy, kind, ms, hold), []).append(
            (length, tapped, held)
        )
    lines, bad = [], []
    for (name, cpu, busy, kind, ms, hold), got in groups.items():
        at = f"{name} at {cpu:g}x" + (
            f", the page busy to {hold + busy} ms after the landing" if busy else ""
        )
        if kind == "quick":
            quick = [g for g in got if g[0] is not None and g[0] < hold]
            wrong = [g for g in quick if g[2]]
            part = next(p for p in PARTS if p.name == name)
            missed = [g for g in quick if part.tap and not g[1] and not g[2]]
            lines.append(
                f"{at}: {len(quick)} quick {ms} ms touches (of {len(got)} under the {hold} ms hold), {len(wrong)} held"
            )
            if wrong:
                bad.append(
                    f"{len(wrong)} of {len(quick)} quick {ms} ms touches on {at} started the hold; {FIX}"
                )
            if missed:
                bad.append(
                    f"{len(missed)} of {len(quick)} quick {ms} ms touches on {at} did nothing"
                )
            if not quick:
                bad.append(
                    f"no {ms} ms touch on {at} was under the {hold} ms hold by its own times"
                )
        else:
            held = [g for g in got if g[2]]
            lines.append(f"{at}: {len(held)} of {len(got)} {ms} ms touches held")
            if len(held) < len(got):
                bad.append(
                    f"{len(got) - len(held)} of {len(got)} {ms} ms touches on {at} did not hold"
                )
    return lines, bad


def main():
    a = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    a.add_argument("--api", required=True)
    a.add_argument("--app", required=True)
    a.add_argument("--chrome", default="")
    a.add_argument("--speeds", default="1,4", help="CPU slowdowns")
    a.add_argument(
        "--touches",
        type=int,
        default=4,
        help="quick touches per length, part and speed",
    )
    a.add_argument(
        "--parts",
        default="",
        help="only these parts (words of their names, comma-separated)",
    )
    a.add_argument("--dump", default="", help="'on': each touch")
    a.add_argument(
        "--busy",
        default="0,100",
        help="rows: 0 unloaded, n the page busy from the landing to n ms past the hold",
    )
    a.add_argument("--out", default="", help="every touch here (JSON)")
    args = a.parse_args()
    args.perf = ""
    started = time.monotonic()
    try:
        results = asyncio.run(play(args))
    except (LookupError, RuntimeError) as e:
        print(f"[tap-hold] the game could not be played: {e}", file=sys.stderr)
        sys.exit(2)
    if args.out:
        Path(args.out).write_text(json.dumps(results))
    lines, bad = verdicts(results)
    print("\n".join(lines))
    print(f"[tap-hold] {len(results)} touches in {time.monotonic() - started:.0f} s")
    for b in bad:
        print(f"[tap-hold] FAIL {b}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
