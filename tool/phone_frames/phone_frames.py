"""A whole game on a phone profile: every screen, transition and tap, measured.

One phone (headless Chrome: Android's user agent, touch, 412 x 915 at 2.625 device
pixels, the release web build as Vercel builds it, CanvasKit) plays through every
screen while bots fill the table over the API:

- join: a cold load of a table's link, the name, Join, 02 as a guest;
- host: a cold load of 01, Start a table, 02, 03 set-up (a deck change, Done),
  bots joining, then three games, the phone's role set at the deal (a DEBUG
  backend's `forced_assignment`, added to the app's own Start request): the Drunk
  (pick a card), the Troublemaker (pick players), a Villager (nothing to do). Each
  game: the deal, 04 (hold the card, Ready), the night, the talk (hold My night,
  Ready to vote), the vote (a pick, Lock in), the end board's reveal, Play again.

The profile: CPU slowed `--cpu` times (4 by default: Chrome's "mid-tier mobile",
the factor Lighthouse uses to make a desktop core stand for a mid-range Android;
1 and 2 for a fast phone), 150 ms added latency, 9 Mbit/s down, 3 up (as
`just phone-timing`). The GPU is not slowed (headless Chrome draws WebGL in
software, SwiftShader, on another process).

Every number comes from the page (`page_probe.RECORDER`) and the compositor's
screencast; `report.py` turns them into rows and budgets. Exits 1 when a budget
is broken, 2 when the game could not be played. Run through `just phone-frames`.
"""

import argparse
import asyncio
import json
import os
import sys

import httpx
from moments import Run
from page_probe import RECORDER, Page
from playwright.async_api import async_playwright
from report import BUDGETS, markdown, measure, over_budget, save, table

UA = (
    "Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/131.0.0.0 Mobile Safari/537.36"
)
NET = {"latency": 150, "down": 9e6 / 8, "up": 3e6 / 8}
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


async def play(args, measuring, boxes):
    api = args.api.rstrip("/") + "/api"
    bots = Bots(api)
    for n in ("Ada", "Bea", "Cal", "Dan"):
        await bots.guest(n)
    runs = []
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path=args.chrome or None,
            args=[
                "--no-sandbox",
                "--enable-unsafe-swiftshader",
                "--ignore-gpu-blocklist",
            ],
        )
        # Leg 1: a guest by the table's link.
        ctx, P = await phone(browser, args, measuring)
        run = Run(args, P, bots, boxes, measuring)
        runs.append(run)
        gpu = await P.page.evaluate(
            """() => { const g = document.createElement('canvas').getContext('webgl2');
               if (!g) return 'no WebGL2'; const d = g.getExtension('WEBGL_debug_renderer_info');
               return d ? g.getParameter(d.UNMASKED_RENDERER_WEBGL) : 'WebGL2'; }"""
        )
        r = await bots.call(
            "POST", "/lobbies/", "Ada", json={"game_type": "onuw", "defaults": "v2"}
        )
        code = r.json()["code"]
        await run.cold(
            "first screen by a link (join)", f"{args.app}/join/{code}", ["Join"]
        )
        await run.rest("join screen")
        await run.type_name("Zed")
        await run.tap(
            "Join (by link) -> 02", "^Join$", ["Ada deals", "Scan to join"], screen=True
        )
        await run.rest("02 table as a guest")
        await run.collect()
        await ctx.close()

        # Leg 2: the host.
        ctx, P = await phone(browser, args, measuring)
        run = Run(args, P, bots, boxes, measuring)
        runs.append(run)
        me = {}

        seen = {}

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
        tokens = {}
        P.page.on(
            "request",
            lambda req: tokens.__setitem__("h", req.headers["authorization"])
            if "authorization" in req.headers
            else None,
        )
        forced = {}

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
        await run.cold("first screen 01 (cold)", args.app + "/", ["Start a table"])
        await run.rest("01 first screen")
        await run.type_name("Host")
        await run.tap(
            "Start a table -> 02", "^Start a table$", ["Scan to join"], screen=True
        )
        await run.rest("02 table, alone")
        code = seen["code"]
        host = {"Authorization": tokens["h"]}
        # Names are not in the semantics; the button says what the table needs.
        joined = {"Bea": "~", "Cal": "!Need 3 players", "Dan": "Start the game"}
        for n, button in joined.items():
            await run.event(
                f"02 {n} joins (socket)",
                lambda n=n: bots.call("POST", f"/lobbies/{code}/join/", n),
                [button],
            )
        await run.rest("02 table, four seated")
        # The deck panel is one button; its "Edit" is at the top right.
        await run.tap(
            "Edit -> 03 set-up", "^Edit\\s", ["Classic"], at=(0.92, 0.15), screen=True
        )
        await run.rest("03 set-up")
        await run.tap("03 add a Minion", "^Minion$", ["Take one Minion out"])
        await run.tap(
            "03 take it out", "^Take one Minion out", ["!Take one Minion out"]
        )
        await run.tap("Done -> 02", "^Done", ["Start the game", "Need"], screen=True)
        # The table's own lengths and deck, set once the set-up page is closed.
        r = await bots.c.patch(
            api + f"/lobbies/{code}/",
            headers=host,
            json={"settings": {"deck": "custom", "roles": DECK, **LENGTHS}},
        )
        if r.status_code != 200:
            raise RuntimeError(
                f"the table's settings were refused: {r.status_code} {r.text[:300]}"
            )
        for g, (mine, theirs, centre) in enumerate(GAMES[: args.games], 1):
            names = ["Bea", "Cal", "Dan"]
            forced.clear()
            forced["player_roles"] = {
                str(me["id"]): mine,
                **{str(bots.players[n][0]): r for n, r in zip(names, theirs)},
            }
            forced["center"] = centre
            await game(run, bots, g, mine, names, seen)
        await run.collect()
        await ctx.close()
        await browser.close()
    return runs, gpu


async def game(run, bots, g, mine, names, seen):
    tag = f"g{g} {mine}"
    await run.tap(
        f"{tag}: Start the game -> deal -> 04",
        "^Start the game",
        ["Look first"],
        screen=True,
    )
    game_id = seen["game"]
    await run.rest(f"{tag}: 04 your card")
    await run.tap(
        f"{tag}: 04 hold the card",
        "^Your card, hidden",
        ["Ready"],
        hold=1.6,
        tolerate=True,
    )
    await run.tap(
        f"{tag}: 04 Ready", "^Ready$", ["Ready ✓", "of 4 ready"], tolerate=True
    )

    async def all_ready(phase=None, look=False):
        for n in names:
            await bots.staged(game_id, n, "ready", {"ready": True}, phase, look)

    await run.event(
        f"{tag}: 04 -> night (others ready)",
        lambda: all_ready(look=True),
        ["Choose a card", "Choose", "Nothing to do", "sleeps"],
    )
    await run.rest(f"{tag}: night {mine}", 2.5)
    bot_night = asyncio.ensure_future(bots.night(game_id, names))
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
    await run.event(
        f"{tag}: night -> talk (window closes)", lambda: bot_night, ["Ready to vote"]
    )
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
        lambda: all_ready("discussion"),
        ["Who dies today?", "Pick a name"],
    )
    await run.rest(f"{tag}: 09 vote", 3)
    await run.tap(f"{tag}: 09 pick Bea", "^Bea", ["Lock in Bea"], tolerate=True)
    await run.tap(f"{tag}: 09 Lock in", "^Lock in", ["Locked"], tolerate=True)
    ids = {n: bots.players[n][0] for n in names}

    async def all_lock():
        for n in names:
            target = ids["Cal"] if n == "Bea" else ids["Bea"]
            await bots.staged(
                game_id,
                n,
                "vote",
                {"target_player_id": target, "lock": True},
                "voting",
            )

    await run.event(f"{tag}: 09 -> end board reveal", all_lock, ["Play again"])
    await run.rest(f"{tag}: 12 end board", 3)
    await run.tap(
        f"{tag}: Play again -> 02", "^Play again", ["Start the game"], screen=True
    )
    await run.rest(f"{tag}: 02 table again", 2)


def main():
    a = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    a.add_argument("--api", required=True)
    a.add_argument("--app", required=True)
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
        "--dpr", type=float, default=2.625, help="device pixels per point (2.625)"
    )
    a.add_argument("--analyse", default="", help="report a saved .raw.json again")
    a.add_argument(
        "--trace", default="", help="a Chrome trace of each screen at rest, here"
    )
    args = a.parse_args()
    boxes = {}
    if not args.analyse:
        try:
            if args.boxes and os.path.exists(args.boxes):
                with open(args.boxes) as f:
                    boxes.update(json.load(f))
            else:
                print("[phone-frames] map pass (semantics on, unslowed): each control")
                asyncio.run(play(args, False, boxes))
                if args.boxes:
                    save(args.boxes, boxes)
            if args.map_only:
                sys.exit(0)
            print(
                f"[phone-frames] measured pass: CPU {args.cpu}x slower, semantics off"
            )
            runs, gpu = asyncio.run(play(args, True, boxes))
        except (LookupError, RuntimeError) as e:
            print(f"[phone-frames] the game could not be played: {e}", file=sys.stderr)
            sys.exit(2)
        raw = [{"rec": r.rec, "moments": r.moments} for r in runs]
        if args.out:
            save(args.out.rsplit(".", 1)[0] + ".raw.json", {"gpu": gpu, "runs": raw})
    else:
        with open(args.analyse) as f:
            got = json.load(f)
        gpu, raw = got["gpu"], got["runs"]
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
                "rows": rows,
                "over": over,
            },
        )
        with open(args.out.rsplit(".", 1)[0] + ".md", "w") as f:
            f.write(markdown(rows) + "\n")
    print(f"\n{len(over)} budget(s) broken" + "".join(f"\n  {o}" for o in over))
    sys.exit(1 if over else 0)


if __name__ == "__main__":
    main()
