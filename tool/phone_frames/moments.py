"""The moments of a game: a screen at rest, a transition, a tap. Two passes.

The map pass turns the app's semantics on (a touch at the very centre of its
placeholder, as a screen reader's) to find each control by its words, and keeps
where it was. Semantics is not left on for the numbers: it builds a DOM tree each
frame and it tells the app a screen reader is in use (`accessibleNavigation`: the
end board then skips its reveal), which a friend's phone never does. So the
measured pass is the app as a phone runs it: a finger at the places the map pass
found, and the compositor's screencast to see what changed and when.
"""

import asyncio
import time

from page_probe import NODES, changes

BIG = 0.2  # share of the screen that changes when a new screen arrives
STEP = 0.03  # share that counts as a visible step of a screen filling in


class Run:
    def __init__(self, args, phone, bots, boxes, measuring):
        self.args = args
        self.P = phone
        self.bots = bots
        self.boxes = boxes
        self.measuring = measuring
        self.moments = []
        self.rec = None

    async def note(self, what):
        if self.args.dump and not self.measuring:
            nodes = await self.P.page.evaluate(NODES)
            print(f"--- {what}\n{nodes}", flush=True)

    async def quiet(self, gap=0.4, most=6.0):
        """Until the app asks for no frame for `gap` seconds and no request of
        the app's is in flight (or `most` seconds)."""
        end = time.monotonic() + most
        while time.monotonic() < end:
            since = await self.P.page.evaluate(
                "() => { const f = window.__pf.frames; const l = f[f.length - 1];"
                " return l ? performance.now() - l[0] : 1e9; }"
            )
            if since > gap * 1000 and not self.P.inflight:
                return
            await asyncio.sleep(0.1)

    async def rest(self, name, seconds=3.0):
        t0 = await self.P.now()
        await asyncio.sleep(seconds)
        if self.measuring:
            self.moments.append(
                {"name": name, "kind": "screen", "t0": t0, "t1": await self.P.now()}
            )
        await self.note(name)

    def _steps(self, since_s, box=None):
        return changes(self.P.shots, since_s, box)

    async def event(self, name, trigger, markers, most=6.0):
        """A screen change the server causes (another player's request)."""
        P = self.P
        if not self.measuring:
            await P.want(markers)
            await trigger()
            if await P.seen() is None:
                raise LookupError(
                    f"{name}: none of {markers} showed: {await P.text()}"
                )
            await self.quiet(most=most)
            await self.note(name)
            return
        await P.screencast(True)
        await asyncio.sleep(0.4)
        t0 = await P.now()
        since = (await P.origin() + t0) / 1000
        await trigger()
        await P.changed(since, BIG, 30)
        await self.quiet(most=most)
        t1 = await P.now()
        await P.screencast(False)
        steps = [(round(t * 1000), s) for t, s in self._steps(since) if s > STEP]
        self.moments.append(
            {
                "name": name,
                "kind": "transition",
                "t0": t0,
                "t1": t1,
                "content_ms": steps[-1][0] if steps else None,
                "first_change_ms": steps[0][0] if steps else None,
                "steps": steps[:12],
            }
        )

    async def tap(
        self,
        name,
        pattern,
        final,
        hold=0.07,
        tolerate=False,
        at=(0.5, 0.5),
        most=6.0,
        screen=False,
    ):
        """A finger on the control named by `pattern` (map pass: until one of
        `final` shows; measured pass: until the screen and the network are still)."""
        P = self.P
        if not self.measuring:
            box = await P.find(pattern)
            self.boxes[name] = box
            await P.want(final)
            # A screen reader's hold is a tap ("Activate to show").
            await P.touch(box["x"] + box["w"] * at[0], box["y"] + box["h"] * at[1])
            if await P.seen(20) is None and not tolerate:
                raise LookupError(f"{name}: none of {final} showed after the tap")
            await self.quiet(most=most)
            await self.note(name)
            return
        box = self.boxes.get(name)
        if box is None:
            raise LookupError(f"{name}: the map pass never reached it")
        await P.screencast(True)
        await asyncio.sleep(0.4)
        t0 = await P.now()
        wall = time.time()
        await P.touch(box["x"] + box["w"] * at[0], box["y"] + box["h"] * at[1], hold)
        await asyncio.sleep(0.3)
        if screen:
            # A tap that opens another screen: until it has arrived.
            await P.changed(wall, BIG, 20)
        await self.quiet(gap=0.6, most=most)
        t1 = await P.now()
        await P.screencast(False)
        origin = await P.origin()
        downs = await P.page.evaluate(
            "t => window.__pf.touches.filter(e => e[0] == 'pointerdown' && e[1] >= t)",
            t0,
        )
        down = downs[0][1] if downs else t0
        down_s = (origin + down) / 1000
        near = self._steps(down_s, box)
        anywhere = self._steps(down_s)
        calls = [r for r in P.requests if r[2] >= down_s - 0.005 and "/api/" in r[0]]
        answered = min((r[3] for r in calls), default=None)
        first = near[0][0] if near else None
        big = [t for t, s in anywhere if s > STEP] + [t for t, s in near if s > 0.05]
        last = max(big, default=None)

        def ms(seconds):
            return None if seconds is None else round(seconds * 1000)

        tap = {
            "control": box["label"][:40],
            "held_ms": round(hold * 1000),
            "first_ms": ms(first),
            "first_anywhere_ms": ms(anywhere[0][0] if anywhere else None),
            "final_ms": ms(last),
            "server_ms": None if answered is None else ms(answered - down_s),
            "requests": [
                f"{r[1]} {r[0].split('/api', 1)[-1]} {ms(r[2] - down_s)}+{ms(r[3] - r[2])} ms"
                for r in calls
            ][:5],
            # The screen's steps: (ms after the finger, share of the screen changed).
            "steps": [(ms(t), s) for t, s in anywhere if s > STEP][:12],
        }
        if answered is None:
            tap["before_server"] = "no request"
        elif first is not None:
            tap["before_server"] = first < answered - down_s
        self.moments.append(
            {"name": name, "kind": "tap", "t0": down, "t1": t1, "tap": tap}
        )

    async def type_name(self, name):
        P = self.P
        if not self.measuring:
            self.boxes["name field"] = await P.find("^Your name")
        box = self.boxes["name field"]
        await P.touch(box["x"] + box["w"] / 2, box["y"] + box["h"] / 2)
        await asyncio.sleep(0.5)
        await P.page.keyboard.type(name, delay=60)
        await asyncio.sleep(0.3)

    async def cold(self, name, url, markers):
        P = self.P
        await P.page.goto(url, wait_until="commit")
        await P.page.wait_for_function("window.__pf !== undefined")
        if not self.measuring:
            await P.want(markers)
            await P.page.wait_for_selector(
                "flt-semantics-placeholder", state="attached", timeout=90000
            )
            await P.touch(206, 457.5)
            if await P.seen(90) is None:
                raise LookupError(f"{name}: none of {markers} showed")
            await self.quiet()
            await self.note(name)
            return
        await P.screencast(True)
        origin = await P.origin()
        await P.page.wait_for_function("window.__pf.first !== null", timeout=90000)
        await self.quiet(gap=0.8, most=20)
        t1 = await P.now()
        await P.screencast(False)
        steps = [
            (round(t * 1000), s) for t, s in changes(P.shots, origin / 1000) if s > STEP
        ]
        nav = await P.page.evaluate(
            """() => { const r = n => { const e = performance.getEntriesByType('resource')
                 .find(x => x.name.includes(n)); return e ? Math.round(e.responseEnd) : null; };
               return {first_frame: Math.round(window.__pf.first), main_js: r('main.dart.js'),
                       canvaskit_wasm: r('canvaskit.wasm'), loaf: window.__pf.noLoaf || 'on'}; }"""
        )
        self.moments.append(
            {
                "name": name,
                "kind": "transition",
                "t0": 0,
                "t1": t1,
                "content_ms": steps[-1][0] if steps else None,
                "first_change_ms": steps[0][0] if steps else None,
                "steps": steps[:12],
                "note": nav,
            }
        )

    async def collect(self):
        self.rec = await self.P.page.evaluate(
            "() => { const R = window.__pf; return {frames: R.frames, loaf: R.loaf, lt: R.lt}; }"
        )
