"""The app's own field recorder (`?perf=1`), read in the lab: `just phone-frames --perf`.

The phone opens the app with `?perf=1`; after the games it pictures the strip and the
summary sheet (412 points wide), copies the short report and the whole JSON through
the sheet's own buttons (the clipboard, as the owner would), and compares the app's
numbers with phone-frames' for the same taps: the app times from the pointer event's
own stamp to the first frame it handed the browser, phone-frames from the same
pointer event to the first changed pixel of Chrome's screencast, so the app's is
the earlier by about one compositor frame; the requests' leaving and round trips
should agree within a few milliseconds.
"""

import asyncio
import json
import os


async def read(P, ctx, app, out_dir):
    """Pictures, the two copies, saved in `out_dir`; the whole record returned."""
    os.makedirs(out_dir, exist_ok=True)
    page = P.page
    await ctx.grant_permissions(["clipboard-read", "clipboard-write"], origin=app)
    await asyncio.sleep(1.5)
    await page.screenshot(path=os.path.join(out_dir, "strip.png"), scale="css")
    view = page.viewport_size
    # The strip is the bottom edge; its summary's three actions sit at the
    # sheet's foot: "Copy report", "Copy everything", "Clear".
    await P.touch(view["width"] / 2, view["height"] - 8)
    await asyncio.sleep(2.5)
    await page.screenshot(path=os.path.join(out_dir, "sheet.png"), scale="css")
    foot = view["height"] - 12 - 22
    copies = {}
    for name, x in (("report.txt", 50), ("everything.json", view["width"] / 2)):
        await P.touch(x, foot)
        await asyncio.sleep(1.5)
        copies[name] = await page.evaluate("() => navigator.clipboard.readText()")
        write(os.path.join(out_dir, name), copies[name])
    try:
        return json.loads(copies["everything.json"])
    except ValueError:
        return None


def write(path, text):
    with open(path, "w") as f:
        f.write(text)


def compare(moments, record):
    """Each phone-frames tap beside the app's record of the same finger (matched by
    the pointer-down's own time stamp): first change, request left, round trip."""
    if not record:
        return ["the app's record could not be read"]
    taps = record["taps"]
    requests = {r["id"]: r for r in record["requests"]}
    lines = [
        (
            "tap | first change: phone-frames / app | request left: pf / app | "
            "round trip: pf / app"
        )
    ]
    for m in moments:
        if m.get("kind") != "tap":
            continue
        mine = min(taps, key=lambda t: abs(t["down"] - m["t0"]), default=None)
        if mine is None or abs(mine["down"] - m["t0"]) > 30:
            lines.append(f"{m['name']} | no app record")
            continue
        tap = m["tap"]
        frame = mine["down_frame"] if mine["hold"] else mine["up_frame"]
        app_first = None if frame is None else round(frame - mine["down"])
        req = requests.get(mine["request"])
        app_left = app_trip = None
        if req and req["left"] is not None:
            app_left = round(req["left"] - mine["down"])
            end = req["arrived"] if req["arrived"] is not None else req["done"]
            app_trip = None if end is None else round(end - req["left"])
        pf_left = pf_trip = None
        if tap["requests"]:
            left, trip = tap["requests"][0].rsplit(" ", 2)[-2].split("+")
            pf_left, pf_trip = int(left), int(trip)
        lines.append(
            f"{m['name']} ({mine['control']}) | {tap['first_ms']} / {app_first} | "
            f"{pf_left} / {app_left} | {pf_trip} / {app_trip}"
        )
    return lines
