"""A whole game on a phone profile: every screen, transition and tap, measured.

One phone (headless Chrome: Android's user agent, touch, 412 x 915 at 2.625 device
pixels, the release web build as Vercel builds it, CanvasKit) plays the game in
`script.py` (a guest joining by a link; a host setting up, then up to three games)
while bots fill the table over the API.

The profile: CPU slowed `--cpu` times (4 by default: Chrome's "mid-tier mobile",
the factor Lighthouse uses to make a desktop core stand for a mid-range Android;
1 and 2 for a fast phone), 150 ms added latency, 9 Mbit/s down, 3 up (as
`just phone-timing`). The GPU is not slowed (headless Chrome draws WebGL in
software, SwiftShader, on another process).

Every number comes from the page (`page_probe.RECORDER`) and the compositor's
screencast; `report.py` turns them into rows and budgets (reported, never failing:
every tap is over the 100 ms one today). Each measured step is checked against the map
pass (checks.py); the first that did not do the same stops the run, loudly.
Exits 0 when everything asked for was measured, 3 when a step was lost (what was
measured before it is kept), 2 when the game could not be played.
`--list` prints the moments; `--moments a,b` measures only those (parts of their names)
and stops after the last. Run through `just phone-frames`, or two refs side by side
through `just speed-verdict`.

`--perf <dir>`: the app's own field recorder on (`?perf=1`, `frontend/lib/core/perf/`,
the readout a real phone gives the owner); after the games its strip and summary are
pictured, its report copied through its own buttons, and its numbers put beside these
(`perf_readout.py`; `<dir>/compare.txt`).
"""

import argparse
import base64
import asyncio
import json
import os
import sys

import httpx
import perf_readout
import script
from moments import Enough, Lost, Plan, Run
from page_probe import RECORDER, Page
from playwright.async_api import async_playwright
from report import BUDGETS, markdown, measure, over_budget, save, table

UA = (
    "Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/131.0.0.0 Mobile Safari/537.36"
)
NET = {"latency": 150, "down": 9e6 / 8, "up": 3e6 / 8}


class Bots:
    def __init__(self, api):
        self.api = api
        self.c = httpx.AsyncClient(timeout=15)
        self.players = {}  # name -> (user id, headers)

    async def guest(self, name):
        r = await self.c.post(self.api + "/auth/guest/", json={"display_name": name})
        body = r.json()
        self.players[name] = (
            body["user"]["id"],
            {"Authorization": "Bearer " + body["access"]},
        )

    async def call(self, method, path, name, **kw):
        r = await self.c.request(
            method, self.api + path, headers=self.players[name][1], **kw
        )
        return r

    async def me(self, game, name):
        return (await self.call("GET", f"/onuw/games/{game}/me/", name)).json()

    async def staged(self, game, name, tail, body, phase=None, look=False):
        """POST at the stage the bot's /me/ shows, once it shows `phase` (and,
        with `look`, the look stage): the phone may be ahead of the server."""
        for _ in range(100):
            me = await self.me(game, name)
            stage = me.get("stage") or ""
            if stage and (phase is None or me.get("phase") == phase):
                if not look or stage.startswith("look"):
                    break
            await asyncio.sleep(0.3)
        r = await self.call(
            "POST",
            f"/onuw/games/{game}/{tail}/",
            name,
            json={**body, "stage": me.get("stage")},
        )
        if r.status_code >= 400:
            raise RuntimeError(f"{name} {tail} refused: {r.status_code} {r.text[:200]}")
        return r

    async def night(self, game, names):
        """Each bot with something to choose chooses, once its window is open."""
        left = set(names)
        for _ in range(60):
            for n in sorted(left):
                me = await self.me(game, n)
                if me.get("phase") != "night":
                    return
                prompt = me.get("action_prompt") or {}
                if prompt.get("chooses_left", 0) <= 0:
                    if me.get("current_wave") == 2:
                        left.discard(n)
                    continue
                others = [
                    p["player_id"]
                    for p in me["players"]
                    if p["player_id"] != me["player_id"]
                ]
                picks = {
                    "seer": [{"center_index": 0}, {"center_index": 1}],
                    "robber": [{"player_id": others[0]}],
                    "troublemaker": [
                        {"player_id": others[0]},
                        {"player_id": others[1]},
                    ],
                    "drunk": [{"center_index": 0}],
                    "lone_werewolf": [{"center_index": 2}],
                }.get(prompt.get("kind"), [])
                await self.call(
                    "POST",
                    f"/onuw/games/{game}/action/",
                    n,
                    json={
                        "action_type": "choose",
                        "picks": picks,
                        "chosen": prompt.get("chosen", 0),
                        "stage": me.get("stage"),
                    },
                )
            if not left:
                return
            await asyncio.sleep(0.5)


async def phone(browser, args, measuring):
    ctx = await browser.new_context(
        viewport={"width": 412, "height": 915},
        device_scale_factor=args.dpr,
        is_mobile=True,
        has_touch=True,
        user_agent=UA,
    )
    page = await ctx.new_page()
    await page.add_init_script(RECORDER)
    cdp = await ctx.new_cdp_session(page)
    await cdp.send("Network.enable")
    if not measuring:
        return ctx, Page(page, cdp)
    await cdp.send(
        "Network.emulateNetworkConditions",
        {
            "offline": False,
            "latency": NET["latency"],
            "downloadThroughput": NET["down"],
            "uploadThroughput": NET["up"],
        },
    )
    await cdp.send("Emulation.setCPUThrottlingRate", {"rate": args.cpu})
    return ctx, Page(page, cdp)


class Table:
    """What the bots and the server do for the script (script.py's `t`)."""

    def __init__(self, bots, api, seen, me, tokens, forced):
        self.bots, self.api = bots, api
        self.seen, self.me, self.tokens, self.forced = seen, me, tokens, forced

    async def new_table(self):
        r = await self.bots.call(
            "POST", "/lobbies/", "Ada", json={"game_type": "onuw", "defaults": "v2"}
        )
        return r.json()["code"]

    async def join(self, name):
        return await self.bots.call("POST", f"/lobbies/{self.seen['code']}/join/", name)

    async def settings(self, settings):
        r = await self.bots.c.patch(
            self.api + f"/lobbies/{self.seen['code']}/",
            headers={"Authorization": self.tokens["h"]},
            json={"settings": settings},
        )
        if r.status_code != 200:
            raise RuntimeError(
                f"the table's settings were refused: {r.status_code} {r.text[:300]}"
            )

    def force(self, mine, theirs, centre):
        self.forced.clear()
        self.forced["player_roles"] = {
            str(self.me["id"]): mine,
            **{str(self.bots.players[n][0]): r for n, r in theirs.items()},
        }
        self.forced["center"] = centre

    async def all_ready(self, phase=None, look=False):
        for n in script.BOTS:
            await self.bots.staged(
                self.seen["game"], n, "ready", {"ready": True}, phase, look
            )

    def night(self):
        return asyncio.ensure_future(self.bots.night(self.seen["game"], script.BOTS))

    async def all_lock(self):
        ids = {n: self.bots.players[n][0] for n in script.BOTS}
        for n in script.BOTS:
            target = ids["Cal"] if n == "Bea" else ids["Bea"]
            await self.bots.staged(
                self.seen["game"],
                n,
                "vote",
                {"target_player_id": target, "lock": True},
                "voting",
            )


async def leg(run, ctx, play_it):
    """One leg of the script: (the run went on, why it was lost or None)."""
    lost, more = None, True
    try:
        await play_it
    except Enough:
        more = False
    except Lost as e:
        lost, more = {"at": e.name, "why": e.why}, False
        if run.args.out:
            # What the screen showed instead: its last frame, and the step's answer.
            stem = run.args.out.rsplit(".", 1)[0]
            shot = run.P.shots[-1][1] if run.P.shots else await run.P.page.screenshot()
            with open(stem + ".lost.jpg", "wb") as f:
                f.write(shot)
            lost["picture"] = stem + ".lost.jpg"
            answer = (run.expect.get(e.name) or {}).get("answer")
            if answer:
                with open(stem + ".lost.answer.png", "wb") as f:
                    f.write(base64.b64decode(answer["png"]))
                lost["answer"] = {"word": answer["word"], "box": answer["box"]}
    await run.collect()
    await ctx.close()
    return more, lost


async def play(args, measuring, boxes, plan, legs, games):
    api = args.api.rstrip("/") + "/api"
    bots = Bots(api)
    for n in ("Ada", "Bea", "Cal", "Dan"):
        await bots.guest(n)
    runs, lost, more = [], None, True
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path=args.chrome or None,
            args=[
                "--no-sandbox",
                "--enable-unsafe-swiftshader",
                "--ignore-gpu-blocklist",
            ],
        )
        ctx, P = await phone(browser, args, measuring)
        gpu = await P.page.evaluate(
            """() => { const g = document.createElement('canvas').getContext('webgl2');
               if (!g) return 'no WebGL2'; const d = g.getExtension('WEBGL_debug_renderer_info');
               return d ? g.getParameter(d.UNMASKED_RENDERER_WEBGL) : 'WebGL2'; }"""
        )
        none = Table(bots, api, {}, {}, {}, {})
        if "join" in legs:
            # Leg 1: a guest by the table's link.
            run = Run(args, P, bots, boxes, measuring, plan)
            runs.append(run)
            more, lost = await leg(run, ctx, script.join_leg(run, none))
        else:
            await ctx.close()
        if "host" in legs and more:
            # Leg 2: the host.
            ctx, P = await phone(browser, args, measuring)
            run = Run(args, P, bots, boxes, measuring, plan)
            runs.append(run)
            seen, me, tokens, forced = {}, {}, {}, {}

            async def seen_response(resp):
                if resp.request.method != "POST" or resp.status != 201:
                    return
                if resp.url.endswith("/auth/guest/"):
                    me.update((await resp.json())["user"])
                elif resp.url.endswith("/api/lobbies/"):
                    seen["code"] = (await resp.json())["code"]
                elif resp.url.endswith("/start/"):
                    seen["game"] = (await resp.json())["game_id"]

            P.page.on("response", seen_response)
            P.page.on(
                "request",
                lambda req: tokens.__setitem__("h", req.headers["authorization"])
                if "authorization" in req.headers
                else None,
            )

            async def start_route(route):
                if route.request.method != "POST":
                    await route.continue_()
                    return
                body = json.loads(route.request.post_data or "{}")
                body["debug"] = {"forced_assignment": forced}
                if args.dump:
                    print(f"[start] {route.request.url} {body}", file=sys.stderr)
                await route.continue_(post_data=json.dumps(body))

            await P.page.route("**/onuw/lobbies/*/start/", start_route)
            table = Table(bots, api, seen, me, tokens, forced)

            async def host():
                await script.host_leg(run, table, games)
                if args.perf and measuring:
                    # The app's own readout, as the owner would copy it.
                    record = await perf_readout.read(P, ctx, args.app, args.perf)
                    lines = perf_readout.compare(run.moments, record)
                    print("\n[phone-frames] the app's readout beside phone-frames:")
                    print("\n".join(lines))
                    perf_readout.write(
                        os.path.join(args.perf, "compare.txt"), "\n".join(lines) + "\n"
                    )

            more, lost = await leg(run, ctx, host())
        await browser.close()
    return runs, gpu, lost


def options():
    a = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    a.add_argument("--api", default="")
    a.add_argument("--app", default="")
    a.add_argument("--chrome", default="")
    a.add_argument(
        "--cpu", type=float, default=4, help="CPU slowdown (4: a mid-range Android)"
    )
    a.add_argument("--out", default="", help="write every number here (JSON)")
    a.add_argument("--dump", action="store_true", help="print each screen's words")
    a.add_argument("--map-only", action="store_true", help="only the map pass")
    a.add_argument("--boxes", default="", help="keep the map pass here, reuse it")
    a.add_argument("--games", type=int, default=3, help="games to play (1 to 3)")
    a.add_argument(
        "--moments",
        default="",
        help="measure only these (comma-separated parts of their names; `--list`)",
    )
    a.add_argument("--list", action="store_true", help="print the moments and stop")
    a.add_argument(
        "--dpr", type=float, default=2.625, help="device pixels per point (2.625)"
    )
    a.add_argument("--analyse", default="", help="report a saved .raw.json again")
    a.add_argument(
        "--perf",
        default="",
        help="open the app with ?perf=1 and keep its readout here (perf_readout.py)",
    )
    return a


def planned(args):
    """(the plan, the legs to play, the games to play) for `--moments` and `--games`."""
    if not args.moments:
        return Plan(), {"join", "host"}, args.games
    chosen, games = script.pick(args.moments, args.games)
    names = [m["name"] for m in chosen]
    return Plan(names, names[-1]), {m["leg"] for m in chosen}, games


def main():
    args = options().parse_args()
    if args.list:
        print(script.describe())
        sys.exit(0)
    try:
        plan, legs, games = planned(args)
    except LookupError as e:
        print(f"[phone-frames] {e}", file=sys.stderr)
        sys.exit(2)
    boxes, lost, checked = {}, None, {}
    if not args.analyse:
        if not (args.api and args.app):
            print("[phone-frames] --api and --app are needed (run.sh gives them)")
            sys.exit(2)
        try:
            if args.boxes and os.path.exists(args.boxes):
                with open(args.boxes) as f:
                    boxes.update(json.load(f))
            else:
                print("[phone-frames] map pass (semantics on, unslowed): each control")
                asyncio.run(play(args, False, boxes, plan, legs, games))
                if args.boxes:
                    save(args.boxes, boxes)
            if args.map_only:
                sys.exit(0)
            print(
                f"[phone-frames] measured pass: CPU {args.cpu}x slower, semantics off"
            )
            runs, gpu, lost = asyncio.run(play(args, True, boxes, plan, legs, games))
        except (LookupError, RuntimeError) as e:
            print(f"[phone-frames] the game could not be played: {e}", file=sys.stderr)
            sys.exit(2)
        raw = [{"rec": r.rec, "moments": r.moments} for r in runs]
        for r in runs:
            checked.update(r.checked)
        if args.out:
            save(
                args.out.rsplit(".", 1)[0] + ".raw.json",
                {"gpu": gpu, "runs": raw, "lost": lost},
            )
    else:
        with open(args.analyse) as f:
            got = json.load(f)
        gpu, raw, lost = got["gpu"], got["runs"], got.get("lost")
    rows = [row for run in raw for row in measure(run["rec"], run["moments"])]
    over = over_budget(rows)
    print(table(rows))
    print(f"\nCPU {args.cpu}x slower, {args.dpr} px/pt, network {NET}, WebGL: {gpu}")
    if args.out:
        save(
            args.out,
            {
                "cpu": args.cpu,
                "net": NET,
                "gpu": gpu,
                "budgets": BUDGETS,
                "asked": sorted(plan.names) if plan.names else None,
                "games": games,
                "rows": rows,
                "over": over,
                "lost": lost,
                "checked": checked,
            },
        )
        with open(args.out.rsplit(".", 1)[0] + ".md", "w") as f:
            f.write(markdown(rows) + "\n")
    print(
        f"\n{len(over)} budget(s) over (reported; a budget never fails the run)"
        + "".join(f"\n  {o}" for o in over)
    )
    if lost:
        print(
            f"\n[phone-frames] NOT MEASURED from {lost['at']!r} on: {lost['why']}."
            "\nNothing after it is a number; what is above it was checked and kept.",
            file=sys.stderr,
        )
        sys.exit(3)
    sys.exit(0)


if __name__ == "__main__":
    main()
