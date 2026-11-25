"""What the tool reads inside the phone's page, and how it touches it.

- RECORDER (an init script, before the app loads): every animation-frame callback
  the app asks for (Flutter's frame: build, layout, paint and CanvasKit's drawing all
  run in it), timed from its start to the next task (so the microtasks and the
  browser's own paint of that frame count); the browser's long animation frames
  (`long-animation-frame`, with the scripts they ran) and long tasks; the first
  frame (`flutter-first-frame`); pointer downs and ups; and, while a step waits for
  a screen, the first frame whose semantics show one of its words.
- Touch: a finger through CDP (`Input.dispatchTouchEvent`), as Chrome on Android
  gets it, so Flutter's gesture arena sees a touch, not a mouse.
- Screencast: the compositor's frames while a tap is measured; a frame is sent only
  when the screen changed, so the first one that differs from the frame before the
  finger is the tap's first visible answer.
"""

import asyncio
import base64
import io
import os
import re
import time

from PIL import Image, ImageChops

RECORDER = r"""
(() => {
  const R = window.__pf = {frames: [], loaf: [], lt: [], first: null, want: null,
                           seen: {}, touches: []};
  const sem = () => {
    const host = document.querySelector('flt-semantics-host');
    if (!host) return '';
    return Array.from(host.querySelectorAll('flt-semantics, input'))
      .map(e => (e.getAttribute('aria-label') || '') + '|' + e.style.height + '|' +
                (e.childElementCount ? '' : (e.innerText || '')))
      .join(' / ');
  };
  R.sem = sem;
  const scan = (t) => {
    if (!R.want) return;
    const text = sem();
    for (const m of R.want) {
      // "!words": the moment the words are gone.
      // "~": the moment the screen's words or boxes change at all.
      const hit = m === '~' ? text !== R.base
        : m[0] === '!' ? !text.includes(m.slice(1)) : text.includes(m);
      if (hit && !(m in R.seen)) R.seen[m] = t;
    }
  };
  const raf = window.requestAnimationFrame.bind(window);
  const ch = new MessageChannel();
  let open = [];
  ch.port1.onmessage = () => {
    const t = performance.now();
    for (const f of open) f[2] = t - f[0];
    open = [];
    scan(t);
  };
  window.requestAnimationFrame = function (cb) {
    return raf(function (ts) {
      const t0 = performance.now();
      try { cb(ts); } finally {
        const f = [t0, performance.now() - t0, 0];
        R.frames.push(f); open.push(f); ch.port2.postMessage(0);
      }
    });
  };
  try {
    new PerformanceObserver(l => { for (const e of l.getEntries()) R.loaf.push({
      start: e.startTime, dur: e.duration, block: e.blockingDuration,
      scripts: (e.scripts || []).map(s => ({inv: s.invoker, type: s.invokerType,
        dur: Math.round(s.duration), fn: s.sourceFunctionName,
        src: (s.sourceURL || '').split('/').pop(), pos: s.sourceCharPosition}))}); })
      .observe({type: 'long-animation-frame', buffered: true});
  } catch (e) { R.noLoaf = String(e); }
  new PerformanceObserver(l => { for (const e of l.getEntries())
    R.lt.push([e.startTime, e.duration]); }).observe({type: 'longtask', buffered: true});
  window.addEventListener('flutter-first-frame', () => { R.first = performance.now(); });
  for (const k of ['pointerdown', 'pointerup'])
    window.addEventListener(k, e => R.touches.push([k, e.timeStamp]), true);
})();
"""

# The box of the first semantics node whose label matches `re` (a JS regex source).
FIND = r"""([re, nth]) => {
  const host = document.querySelector('flt-semantics-host');
  if (!host) return null;
  const rx = new RegExp(re);
  const hits = [];
  for (const e of host.querySelectorAll('flt-semantics, input')) {
    const label = (e.getAttribute('aria-label') || '') ||
                  (e.childElementCount ? '' : (e.innerText || ''));
    if (!rx.test(label.trim())) continue;
    const r = e.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) continue;
    hits.push({x: r.x, y: r.y, w: r.width, h: r.height, label: label.trim(),
               role: e.getAttribute('role') || e.tagName});
  }
  hits.sort((a, b) => (b.role === 'button') - (a.role === 'button'));
  return hits[nth] || null;
}"""


NODES = r"""() => Array.from(document.querySelectorAll('flt-semantics, input')).map(e => {
  const r = e.getBoundingClientRect();
  const label = (e.getAttribute('aria-label') || '') || (e.childElementCount ? '' : (e.innerText || ''));
  return [label.replace(/\n/g, ' | ').slice(0, 40), e.getAttribute('role') || '',
          Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)];
}).filter(n => n[0] || n[1])"""


class Page:
    """One phone: the page, its CDP session, its network log."""

    def __init__(self, page, cdp):
        self.page = page
        self.cdp = cdp
        self.requests = []  # (url, method, start epoch s, end epoch s)
        self.shots = []  # (epoch s, jpeg bytes) while a screencast runs
        cdp.on("Page.screencastFrame", self._frame)

        def done(req):
            t = req.timing
            start = t["startTime"] / 1000
            end = start + max(t.get("responseEnd", 0), 0) / 1000
            self.requests.append((req.url, req.method, start, end))

        self.inflight = 0

        def sent(req):
            if "/api/" in req.url:
                self.inflight += 1

        def over(req):
            if "/api/" in req.url:
                self.inflight = max(0, self.inflight - 1)

        page.on("request", sent)
        page.on("requestfinished", done)
        page.on("requestfinished", over)
        page.on("requestfailed", over)

    def _frame(self, f):
        self.shots.append((f["metadata"]["timestamp"], base64.b64decode(f["data"])))
        asyncio.ensure_future(
            self.cdp.send("Page.screencastFrameAck", {"sessionId": f["sessionId"]})
        )

    async def now(self):
        return await self.page.evaluate("performance.now()")

    async def origin(self):
        return await self.page.evaluate("performance.timeOrigin")

    async def text(self):
        return await self.page.evaluate("window.__pf.sem()")

    async def find(self, pattern, nth=0, timeout=20.0):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            box = await self.page.evaluate(FIND, [pattern, nth])
            if box:
                return box
            await asyncio.sleep(0.1)
        raise LookupError(f"nothing on screen matches /{pattern}/: {await self.text()}")

    async def want(self, markers):
        await self.page.evaluate(
            "m => { const R = window.__pf; R.base = R.sem(); R.want = m; R.seen = {}; }",
            list(markers),
        )

    async def seen(self, timeout=30.0):
        """The page time the first wanted word showed, or None."""
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            seen = await self.page.evaluate("window.__pf.seen")
            if seen:
                return min(seen.values())
            await asyncio.sleep(0.05)
        return None

    async def changed(self, since, share, timeout):
        """Until a screencast frame after `since` (epoch s) differs from the last
        one before it by `share` of the screen, or `timeout` seconds."""
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            before = [s for s in self.shots if s[0] <= since]
            after = [s for s in self.shots if s[0] > since]
            if before and after:
                base, cur = _img(before[-1][1]), _img(after[-1][1])
                if base.size == cur.size:
                    diff = ImageChops.difference(base, cur).point(
                        lambda v: 255 if v > 24 else 0
                    )
                    if diff.histogram()[255] / (cur.size[0] * cur.size[1]) > share:
                        return True
            await asyncio.sleep(0.25)
        return False

    async def touch(self, x, y, hold=0.07):
        point = [{"x": x, "y": y, "radiusX": 6, "radiusY": 6, "force": 1}]
        await self.cdp.send(
            "Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": point}
        )
        await asyncio.sleep(hold)
        await self.cdp.send(
            "Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []}
        )

    # A Chrome trace of a moment (`--trace`): the main thread's tasks, the
    # JavaScript samples (named in a profile build) and the GPU process.
    TRACE = [
        "devtools.timeline",
        "disabled-by-default-devtools.timeline",
        "disabled-by-default-devtools.timeline.frame",
        "v8.execute",
        "disabled-by-default-v8.cpu_profiler",
        "blink.user_timing",
        "gpu",
        "viz",
        "toplevel",
    ]

    async def trace_start(self):
        await self.cdp.send(
            "Tracing.start",
            {
                "transferMode": "ReturnAsStream",
                "traceConfig": {"includedCategories": self.TRACE},
            },
        )

    async def trace_stop(self, folder, name):
        done = asyncio.get_running_loop().create_future()
        self.cdp.once(
            "Tracing.tracingComplete",
            lambda e: done.done() or done.set_result(e["stream"]),
        )
        await self.cdp.send("Tracing.end")
        stream = await done
        chunks = []
        while True:
            got = await self.cdp.send("IO.read", {"handle": stream})
            chunks.append(got["data"])
            if got.get("eof"):
                break
        await self.cdp.send("IO.close", {"handle": stream})
        os.makedirs(folder, exist_ok=True)
        safe = re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_")
        with open(os.path.join(folder, safe + ".json"), "w") as f:
            f.write("".join(chunks))

    async def screencast(self, on):
        if on:
            self.shots = []
            await self.cdp.send(
                "Page.startScreencast",
                {"format": "jpeg", "quality": 60, "maxWidth": 412, "maxHeight": 915},
            )
        else:
            await self.cdp.send("Page.stopScreencast")


def _img(jpeg):
    return Image.open(io.BytesIO(jpeg)).convert("L")


def changes(shots, since, box=None, scale=1.0, threshold=24):
    """The screencast frames after `since` (epoch s) that differ from the frame
    before it: [(seconds after, share of the box changed)]. A pixel counts when it
    moved by more than `threshold` of 255 (JPEG noise stays under it)."""
    before = [s for s in shots if s[0] <= since]
    after = [s for s in shots if s[0] > since]
    if not before and len(after) > 1:
        # A cold load: the screencast's first frame (the empty page) is the base.
        before, after = after[:1], after[1:]
    if not before or not after:
        return []
    out = []
    prev = _img(before[-1][1])
    for t, jpeg in after:
        cur = _img(jpeg)
        if cur.size != prev.size:
            prev = prev.resize(cur.size)
        diff = ImageChops.difference(cur, prev)
        if box:
            k = cur.size[0] / 412 * scale
            diff = diff.crop(
                (
                    int(box["x"] * k),
                    int(box["y"] * k),
                    int((box["x"] + box["w"]) * k) + 1,
                    int((box["y"] + box["h"]) * k) + 1,
                )
            )
        hist = diff.point(lambda v: 255 if v > threshold else 0).histogram()
        share = hist[255] / max(1, diff.size[0] * diff.size[1])
        if share > 0.002:
            out.append((round(t - since, 3), round(share, 3)))
        prev = cur
    return out
