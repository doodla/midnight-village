"""Tap to guest screen on a slowed phone: the deal and play again, against a budget.

A real guest phone (headless Chrome, the release web build) sits at a local table;
the host and a second guest are driven over the API. For each round it times, from
the host's request:

- event: the socket event (`game_started`, `play_again`) reaching the guest's page;
- screen: the guest's screen showing its content: the card or the night board with
  this player's own seat (not the empty frame the dusk lands on), or 02 with its
  code ("Scan to join").

Rounds: `--rounds` with the socket connected, then `--missed` deals with the guest's
sockets cut just before the deal (the app reconnects after its own backoff), which is
the path a phone that slept or dropped its socket takes.

The phone profile is the one the diagnosis of 24 November 2026 used: CPU 4x slower,
150 ms added latency, 9 Mbit/s down, 3 up. Exits 1 when any round's step is over its
budget (`--budget-*`, seconds), and prints every number either way.

Run through `just phone-timing` (it starts a backend, builds and serves the app).
"""

import argparse
import asyncio
import json
import sys
import time

import httpx
from playwright.async_api import async_playwright

SEM_JS = """() => {
  const host = document.querySelector('flt-semantics-host');
  if (!host) return '';
  return Array.from(host.querySelectorAll('flt-semantics, input'))
    .map(e => (e.getAttribute('aria-label')||'') + '|' + (e.childElementCount ? '' : (e.innerText||'')))
    .filter(s => s !== '|').join(' / ').slice(0, 400);
}"""

PHONE = {"latency": 150, "down": 9e6 / 8, "up": 3e6 / 8, "cpu": 4}


# The page's sockets, kept so a round can cut them (the app's own reconnect then
# runs as after a real drop).
KEEP_SOCKETS = """
window.__sockets = [];
const Native = window.WebSocket;
window.WebSocket = class extends Native {
  constructor(...a) { super(...a); window.__sockets.push(this); }
};
"""
CUT_SOCKETS = "() => window.__sockets.forEach(s => s.close())"

# What a screen shows once it has its content (lib/design_system/copy/).
# The deal: the card (04, CardCopy.readyLocked) or, with no look stage, the night
# board's own seat ("You, hidden. Activate to show."); never the empty frame.
CARD = ("Look first", "Activate to show")
# Play again: 02's code block (TableCopy.scan), drawn once the lobby is read.
TABLE = ("Scan to join",)


async def shows(page, markers, since, timeout=30):
    """Seconds from `since` until the guest's screen shows one of `markers`."""
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        text = await page.evaluate(SEM_JS)
        if any(m in text for m in markers):
            return time.monotonic() - since
        await asyncio.sleep(0.02)
    return None


async def run(args):
    api = args.api.rstrip("/") + "/api"
    c = httpx.Client(timeout=15)
    host = c.post(api + "/auth/guest/", json={"display_name": "Host"}).json()
    other = c.post(api + "/auth/guest/", json={"display_name": "Cal"}).json()
    hh = {"Authorization": "Bearer " + host["access"]}
    oh = {"Authorization": "Bearer " + other["access"]}
    code = c.post(
        api + "/lobbies/", json={"game_type": "onuw", "defaults": "v2"}, headers=hh
    ).json()["code"]
    # Short stages, so a round reaches the results quickly (the table's own settings).
    r = c.patch(
        api + f"/lobbies/{code}/",
        json={
            "settings": {
                "night_wave_seconds": 5,
                "night_min_window_seconds": 5,
                "night_doppelganger_window_seconds": 1,
                "discussion_seconds": 2,
                "voting_seconds": 2,
                "card_look_seconds": 0,
            }
        },
        headers=hh,
    )
    if r.status_code != 200:
        print("the short stages were refused:", r.status_code, r.text[:300])
        return 2
    c.post(api + f"/lobbies/{code}/join/", headers=oh)

    rounds = {"deal": [], "missed_deal": [], "play_again": []}
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path=args.chrome or None, args=["--no-sandbox"]
        )
        page = await browser.new_page(viewport={"width": 390, "height": 844})
        await page.add_init_script(KEEP_SOCKETS)
        cdp = await page.context.new_cdp_session(page)
        await cdp.send("Network.enable")
        await cdp.send(
            "Network.emulateNetworkConditions",
            {
                "offline": False,
                "latency": PHONE["latency"],
                "downloadThroughput": PHONE["down"],
                "uploadThroughput": PHONE["up"],
            },
        )
        await cdp.send("Emulation.setCPUThrottlingRate", {"rate": PHONE["cpu"]})
        events = []

        def on_ws(ws):
            ws.on(
                "framereceived",
                lambda f: events.append((time.monotonic(), str(f))),
            )

        page.on("websocket", on_ws)

        # The guest joins by the table's link, as a phone does.
        await page.goto(f"{args.app}/join/{code}")
        await page.wait_for_selector(
            "flt-semantics-placeholder", state="attached", timeout=60000
        )
        await page.wait_for_timeout(1500)
        await page.evaluate(
            "() => document.querySelector('flt-semantics-placeholder').click()"
        )
        await page.wait_for_timeout(1000)
        field = page.get_by_label("Your name").last
        box = await field.bounding_box()
        await page.mouse.click(
            box["x"] + box["width"] / 2, box["y"] + box["height"] / 2
        )
        await page.keyboard.type("Bea", delay=50)
        await page.get_by_role("button", name="Join").click()
        await page.wait_for_timeout(5000)

        def event_after(kind, since):
            for t, frame in events:
                if t >= since and kind in frame:
                    return t - since
            return None

        for n in range(args.rounds + args.missed):
            missed = n >= args.rounds
            await asyncio.sleep(2)
            if missed:
                await page.evaluate(CUT_SOCKETS)
                await asyncio.sleep(0.1)
            t = time.monotonic()
            r = c.post(api + f"/onuw/lobbies/{code}/start/", headers=hh, json={})
            if r.status_code != 201:
                print("deal refused:", r.status_code, r.text[:300])
                return 2
            game = r.json()["game_id"]
            screen = await shows(page, CARD, t)
            step = {"screen": screen}
            if not missed:
                step["event"] = event_after("game_started", t)
            rounds["missed_deal" if missed else "deal"].append(step)
            for _ in range(120):
                me = c.get(api + f"/onuw/games/{game}/me/", headers=hh).json()
                if me.get("phase") == "results":
                    break
                await asyncio.sleep(1)
            await asyncio.sleep(4)
            t = time.monotonic()
            c.post(api + f"/lobbies/{code}/play-again/", headers=hh)
            screen = await shows(page, TABLE, t)
            rounds["play_again"].append(
                {"event": event_after("play_again", t), "screen": screen}
            )
            await asyncio.sleep(3)
        await browser.close()

    budgets = {
        "deal": {"event": args.budget_event, "screen": args.budget_deal},
        "missed_deal": {"screen": args.budget_missed},
        "play_again": {"event": args.budget_event, "screen": args.budget_again},
    }
    over = []
    for kind, runs in rounds.items():
        for i, step in enumerate(runs):
            for name, seconds in step.items():
                limit = budgets[kind][name]
                # The session's first deal decodes the night's art for the first time.
                if kind == "deal" and name == "screen" and i == 0:
                    limit = args.budget_first_deal
                if seconds is None or seconds > limit:
                    over.append(f"{kind} round {i + 1}: {name} {seconds} s > {limit} s")
    result = {
        "profile": PHONE,
        "budgets": budgets,
        "rounds": rounds,
        "over": over,
        "note": (
            "The connected deal is a guard against getting slower: start-lands-fast "
            "did not make it faster (the card waits for /me/ and for drawing the "
            "night either way). The missed deal is that piece's gain: on e48d802 "
            "it waited for the 15 s poll."
        ),
    }
    print(json.dumps(result, indent=2))
    if args.out:
        with open(args.out, "w") as f:
            json.dump(result, f, indent=2)
    return 1 if over else 0


def main():
    a = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    a.add_argument(
        "--api", required=True, help="the backend, e.g. http://127.0.0.1:8791"
    )
    a.add_argument("--app", required=True, help="the served web build")
    a.add_argument("--rounds", type=int, default=3, help="deals, socket connected")
    a.add_argument("--missed", type=int, default=2, help="deals, sockets cut")
    a.add_argument("--chrome", default="", help="a Chrome to use (else Playwright's)")
    a.add_argument("--budget-event", type=float, default=0.5)
    # Measured 24 November 2026, an idle machine, three connected deals and two
    # missed, five plays again each (seconds to the screen's content):
    #   start-lands-fast  deal 1.99 1.41 1.51  missed 2.62 2.60  again 0.89-0.98
    #   main (e48d802)    deal 1.69 1.32 1.36  missed 6.59 6.27  again 1.14-1.32
    # The connected deal did not get faster (a guard only); the missed deal and
    # play again budgets fail main and pass this branch.
    a.add_argument("--budget-first-deal", type=float, default=3.0)
    a.add_argument("--budget-deal", type=float, default=2.0)
    a.add_argument("--budget-again", type=float, default=1.1)
    a.add_argument("--budget-missed", type=float, default=4.0)
    a.add_argument("--out", default="")
    sys.exit(asyncio.run(run(a.parse_args())))


if __name__ == "__main__":
    main()
