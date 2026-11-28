"""The moments of a game: a screen at rest, a transition, a tap. Two passes.

The map pass turns the app's semantics on (a touch at the very centre of its
placeholder, as a screen reader's) to find each control by its words, and keeps
where it was, and what each step did (checks.py: its actions, its answer's picture).
Semantics is not left on for the numbers: it builds a DOM tree each frame and it tells
the app a screen reader is in use (`accessibleNavigation`: the end board then skips its
reveal), which a friend's phone never does. So the measured pass is the app as a phone
runs it: a finger at the places the map pass found, and the compositor's screencast to
see what changed and when. Each measured step is checked against the map pass; a step
that did not do the same is lost (`Lost`): the run stops there, loudly.

A plan (`Plan`) names the moments to measure: the others are played, and checked, but
not timed, and the run ends after the last one asked for (`Enough`).
"""

import asyncio
import base64
import re
import time

import checks
from page_probe import NODES, changes

STEP = 0.03  # share that counts as a visible step of a screen filling in


class Lost(Exception):
    """The measured pass did not do what the map pass did at this step."""

    def __init__(self, name, why):
        super().__init__(f"{name}: {why}")
        self.name, self.why = name, why


class Enough(Exception):
    """Every moment the plan asked for is measured."""


class Plan:
    """The moments to measure (None: all) and the last of them, where the run ends."""

    def __init__(self, names=None, last=None):
        self.names = None if names is None else set(names)
        self.last = last

    def wants(self, name):
        return self.names is None or name in self.names


class Run:
    def __init__(self, args, phone, bots, boxes, measuring, plan=None):
        self.args = args
        self.P = phone
        self.bots = bots
        self.boxes = boxes
        self.expect = boxes.setdefault("_expect", {})
        self.measuring = measuring
        self.plan = plan or Plan()
        self.moments = []
        # The share of each step's answer that differed from the map pass's picture.
        self.checked = {}
        self.rec = None

    def _done(self, name):
        if name == self.plan.last:
            raise Enough()

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
        if self.measuring and self.plan.wants(name):
            self.moments.append(
                {"name": name, "kind": "screen", "t0": t0, "t1": await self.P.now()}
            )
        await self.note(name)

    def _steps(self, since_s, box=None):
        return changes(self.P.shots, since_s, box)

    # ---- what a step did, recorded by the map pass, checked by the measured one ----

    async def _crop(self, box):
        shot = await self.P.page.screenshot(
            clip={"x": box["x"], "y": box["y"], "width": box["w"], "height": box["h"]},
            scale="css",
            type="png",
        )
        return shot

    async def record(self, name, wall, markers):
        """Map pass: the actions the step sent at once and its answer's picture."""
        soon = checks.actions(self.P.sent, wall, wall + checks.ACT_SOON)
        seen = await self.P.page.evaluate("window.__pf.seen") or {}
        words = [m for m in sorted(seen, key=seen.get) if m[:1] not in ("!", "~")]
        answer = None
        for word in words:
            box = await self.P.page.evaluate(_FIND_ANY, [re.escape(word), 0])
            # Words only: a picture (the table's QR code) differs from table to table.
            if box and box["role"] != "img":
                crop = await self._crop(box)
                answer = {
                    "word": word,
                    "box": box,
                    "png": base64.b64encode(crop).decode(),
                }
                break
        if answer is None and any(m[:1] not in ("!", "~") for m in markers):
            # Words it waits for that never showed: the script's words are stale.
            print(
                f"[phone-frames] map: {name}: none of {markers} showed as words, so its"
                " answer cannot be checked (only that the screen changed). Fix: give"
                " it words its screen shows (`--dump` prints them).",
                flush=True,
            )
        self.expect[name] = {"actions": soon, "answer": answer}

    async def check(self, name, wall):
        """Measured pass: raises Lost when the step did not do what the map pass saw."""
        exp = self.expect.get(name)
        if exp is None:
            raise Lost(name, "the map pass has no record of this step (map it again)")
        want = exp.get("actions") or []
        end = time.monotonic() + checks.ACT_WAIT
        sent = checks.actions(self.P.sent, wall)
        while checks.missing(want, sent) and time.monotonic() < end:
            await asyncio.sleep(0.1)
            sent = checks.actions(self.P.sent, wall)
        why = checks.lost_actions(name, want, sent)
        if why:
            raise Lost(name, why)
        answer = exp.get("answer")
        if answer:
            got = checks.png(await self._crop(answer["box"]))
            share = checks.differs(checks.png(base64.b64decode(answer["png"])), got)
            self.checked[name] = round(share, 3)
            why = checks.lost_answer(answer["word"], share)
            if why:
                raise Lost(name, why)

    def _shows(self, name, before=None):
        """Does the newest screencast frame (before `before`, epoch s) show the step's
        answer where the map pass saw it? None when the step has no answer to see."""
        answer = (self.expect.get(name) or {}).get("answer")
        if not answer:
            return None
        shots = sorted(
            (s for s in self.P.shots if before is None or s[0] <= before),
            key=lambda s: s[0],
        )
        return bool(shots) and checks.shows(answer, shots[-1][1])

    async def _arrives(self, name, since, most):
        """Until the step's answer shows (or, for a step whose answer is words going
        away, until the screen changes at all): False after `most` seconds."""
        if self._shows(name) is None:
            return await self.P.changed(since, STEP, most)
        end = time.monotonic() + most
        while time.monotonic() < end:
            if self._shows(name):
                return True
            await asyncio.sleep(0.25)
        return False

    # ---- the moments ------------------------------------------------------------------

    async def wait(self, name, trigger, markers, most=30.0):
        """A step the script goes through and checks but does not time."""
        P = self.P
        if not self.measuring:
            await P.want(markers)
            wall = time.time()
            await trigger()
            if await P.seen() is None:
                raise LookupError(f"{name}: none of {markers} showed: {await P.text()}")
            await self.quiet()
            await self.record(name, wall, markers)
            return
        await P.screencast(True)
        await asyncio.sleep(0.4)
        await P.base()
        wall = time.time()
        await trigger()
        came = await self._arrives(name, wall, most)
        await self.quiet()
        await P.screencast(False)
        if not came:
            raise Lost(name, f"none of {markers} showed within {most:.0f} s")
        await self.check(name, wall)

    async def event(self, name, trigger, markers, most=6.0):
        """A screen change the server causes (another player's request)."""
        P = self.P
        if not self.measuring:
            await P.want(markers)
            wall = time.time()
            await trigger()
            if await P.seen() is None:
                raise LookupError(f"{name}: none of {markers} showed: {await P.text()}")
            await self.quiet(most=most)
            await self.record(name, wall, markers)
            await self.note(name)
            self._done(name)
            return
        await P.screencast(True)
        await asyncio.sleep(0.4)
        await P.base()
        t0 = await P.now()
        since = (await P.origin() + t0) / 1000
        if self._shows(name, before=since):
            raise Lost(
                name,
                "its answer was on the screen before it began, so there is nothing to"
                " time. Fix the script (script.py): make it a `run.wait`, or start it"
                " before what brings the answer",
            )
        await trigger()
        came = await self._arrives(name, since, 30)
        await self.quiet(most=most)
        t1 = await P.now()
        await P.screencast(False)
        steps = [(round(t * 1000), s) for t, s in self._steps(since) if s > STEP]
        if not came or not steps:
            raise Lost(name, f"none of {markers} showed within 30 s of it")
        await self.check(name, since)
        if self.plan.wants(name):
            self.moments.append(
                {
                    "name": name,
                    "kind": "transition",
                    "t0": t0,
                    "t1": t1,
                    "content_ms": steps[-1][0],
                    "first_change_ms": steps[0][0],
                    "steps": steps[:12],
                }
            )
        self._done(name)

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
            wall = time.time()
            # A screen reader's hold is a tap ("Activate to show").
            await P.touch(box["x"] + box["w"] * at[0], box["y"] + box["h"] * at[1])
            if await P.seen(20) is None and not tolerate:
                raise LookupError(f"{name}: none of {final} showed after the tap")
            await self.quiet(most=most)
            await self.record(name, wall, final)
            await self.note(name)
            self._done(name)
            return
        box = self.boxes.get(name)
        if box is None:
            raise LookupError(f"{name}: the map pass never reached it")
        await P.screencast(True)
        await asyncio.sleep(0.4)
        based = await P.base()
        t0 = await P.now()
        wall = time.time()
        await P.touch(box["x"] + box["w"] * at[0], box["y"] + box["h"] * at[1], hold)
        await asyncio.sleep(0.3)
        came = True
        if screen:
            # A tap that opens another screen: until it has arrived (its answer shows).
            came = await self._arrives(name, wall, 20)
        await self.quiet(gap=0.6, most=most)
        t1 = await P.now()
        await P.screencast(False)
        origin = await P.origin()
        downs = await P.page.evaluate(
            "t => window.__pf.touches.filter(e => e[0] == 'pointerdown' && e[1] >= t)",
            t0,
        )
        if not downs:
            raise Lost(name, "the page never got the finger (no pointerdown)")
        down = downs[0][1]
        down_s = (origin + down) / 1000
        near = self._steps(down_s, box)
        anywhere = self._steps(down_s)
        if not came:
            raise Lost(name, "the screen it opens never came (20 s)")
        if hold >= checks.HOLD_CHECKED and not checks.held_showed(anywhere, hold):
            raise Lost(
                name,
                f"nothing showed while it was held ({hold} s): the hold did not register",
            )
        await self.check(name, down_s)
        if self.plan.wants(name):
            self.moments.append(
                {
                    "name": name,
                    "kind": "tap",
                    "t0": down,
                    "t1": t1,
                    "tap": {
                        **_tap(P, box, hold, down_s, near, anywhere),
                        "base": based,
                    },
                }
            )
        self._done(name)

    async def type_name(self, name):
        P = self.P
        if not self.measuring:
            self.boxes["name field"] = await P.find("^Your name")
        box = self.boxes["name field"]
        # Until the field has the keyboard (set-up, not timed: a touch again if not),
        # and then the field must hold the name: the join screen's name (focused as it
        # opens) was never typed on the headless phone, and its Join was timed as a tap
        # on a button that does nothing.
        touches = 0
        for touches in range(1, 4):
            await P.touch(box["x"] + box["w"] / 2, box["y"] + box["h"] / 2)
            end = time.monotonic() + 3
            while time.monotonic() < end and not await P.page.evaluate(_TYPING):
                await asyncio.sleep(0.1)
            if await P.page.evaluate(_TYPING):
                break
        await P.page.keyboard.type(name, delay=60)
        await asyncio.sleep(0.3)
        got = await P.page.evaluate(_TYPED)
        if got != name:
            why = (
                f"the name field holds {got!r}, not {name!r}: the next tap would do"
                f" nothing ({touches} touches; {await P.page.evaluate(_FIELDS)})"
            )
            if self.measuring:
                raise Lost(f"typing {name}", why)
            raise LookupError(why)

    async def cold(self, name, path, markers):
        P = self.P
        url = self.args.app + path
        if self.args.perf:
            # The app's own field recorder on (`just phone-frames --perf <dir>`).
            url += ("&" if "?" in url else "?") + "perf=1"
        await P.page.goto(url, wait_until="commit")
        await P.page.wait_for_function("window.__pf !== undefined")
        if not self.measuring:
            await P.want(markers)
            wall = time.time()
            await P.page.wait_for_selector(
                "flt-semantics-placeholder", state="attached", timeout=90000
            )
            await P.touch(206, 457.5)
            if await P.seen(90) is None:
                raise LookupError(f"{name}: none of {markers} showed")
            await self.quiet()
            await self.record(name, wall, markers)
            await self.note(name)
            self._done(name)
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
        if not steps:
            raise Lost(name, "nothing showed within 90 s of opening it")
        await self.check(name, origin / 1000)
        if not self.plan.wants(name):
            self._done(name)
            return
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
                "content_ms": steps[-1][0],
                "first_change_ms": steps[0][0],
                "steps": steps[:12],
                "note": nav,
            }
        )
        self._done(name)

    async def collect(self):
        self.rec = await self.P.page.evaluate(
            "() => { const R = window.__pf; return {frames: R.frames, loaf: R.loaf, lt: R.lt}; }"
        )


def _ms(seconds):
    return None if seconds is None else round(seconds * 1000)


def _tap(P, box, hold, down_s, near, anywhere):
    calls = [r for r in P.requests if r[2] >= down_s - 0.005 and "/api/" in r[0]]
    answered = min((r[3] for r in calls), default=None)
    first = near[0][0] if near else None
    big = [t for t, s in anywhere if s > STEP] + [t for t, s in near if s > 0.05]
    last = max(big, default=None)
    tap = {
        "control": box["label"][:40],
        "held_ms": round(hold * 1000),
        "first_ms": _ms(first),
        "first_anywhere_ms": _ms(anywhere[0][0] if anywhere else None),
        "final_ms": _ms(last),
        "server_ms": None if answered is None else _ms(answered - down_s),
        "requests": [
            f"{r[1]} {r[0].split('/api', 1)[-1]} {_ms(r[2] - down_s)}+{_ms(r[3] - r[2])} ms"
            for r in calls
        ][:5],
        # The screen's steps: (ms after the finger, share of the screen changed).
        "steps": [(_ms(t), s) for t, s in anywhere if s > STEP][:12],
    }
    if answered is None:
        tap["before_server"] = "no request"
    elif first is not None:
        tap["before_server"] = first < answered - down_s
    return tap


# Flutter's text field is a real <input> (with semantics off too): has it the keyboard,
# and what does it hold?
_FOCUSED = "let e = document.activeElement; while (e && e.shadowRoot && e.shadowRoot.activeElement) e = e.shadowRoot.activeElement;"
_TYPING = (
    "() => { "
    + _FOCUSED
    + " return !!e && (e.tagName == 'INPUT' || e.tagName == 'TEXTAREA'); }"
)
_TYPED = "() => { " + _FOCUSED + " return e && 'value' in e ? e.value : null; }"
# What the page has instead: the focus chain and every text field, shadow roots too.
_FIELDS = r"""() => { const chain = []; let e = document.activeElement;
  while (e) { chain.push(e.tagName.toLowerCase()); e = e.shadowRoot && e.shadowRoot.activeElement; }
  const all = []; const walk = r => { for (const x of r.querySelectorAll('*')) {
    if (x.tagName == 'INPUT' || x.tagName == 'TEXTAREA') all.push(x.tagName.toLowerCase() + '=' + JSON.stringify(x.value));
    if (x.shadowRoot) walk(x.shadowRoot); } };
  walk(document); return 'focus ' + chain.join(' > ') + '; fields ' + (all.join(', ') || 'none'); }"""

# The box of the first semantics node whose label holds `re` anywhere (page_probe.FIND
# matches a control's whole label; an answer's words may be part of a longer one).
_FIND_ANY = r"""([re, nth]) => {
  const host = document.querySelector('flt-semantics-host');
  if (!host) return null;
  const rx = new RegExp(re);
  for (const e of host.querySelectorAll('flt-semantics, input')) {
    const label = (e.getAttribute('aria-label') || '') ||
                  (e.childElementCount ? '' : (e.innerText || ''));
    if (!rx.test(label.trim())) continue;
    const r = e.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) continue;
    return {x: r.x, y: r.y, w: r.width, h: r.height, label: label.trim(),
            role: e.getAttribute('role') || ''};
  }
  return null;
}"""
