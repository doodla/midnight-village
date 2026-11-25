"""The numbers for each moment of the game, and the budgets they are held to.

A moment is a screen (from the moment it settled until the next touch or event),
a transition (from its trigger until its content shows and the frames stop), or a
tap (the finger down until the answer). For each: Flutter's frames (an animation
frame callback timed to the next task: the work one frame costs the phone's main
thread), how many took over 16.7 ms (a missed 60 Hz frame) and over 50 ms (a
stall anyone sees), the worst, the long tasks (count and total ms), the long
animation frames, and the time to its content. A tap also gets the time to the
first changed pixel near the finger and anywhere, the time to its final state, and
whether anything changed before the server answered.
"""

import json

FRAME = 1000 / 60

# Budgets for a game that feels smooth (see the docstring of phone_frames.py for
# where the numbers come from). A moment breaks one when it is over it.
BUDGETS = {
    # A tap shows it was heard within 100 ms (the human threshold for "instant"),
    # its own control or anything on screen.
    "tap_first_ms": 100,
    # Its final state (the next screen, the control's done state) within 1 s when
    # the server is local; the live server's round trip comes on top.
    "tap_final_ms": 1000,
    # No frame on a screen or in a transition takes over 100 ms (a visible stall).
    "worst_frame_ms": 100,
    # At most 10% of a transition's frames miss 60 Hz.
    "over16_share": 0.10,
    # A screen at rest costs under 100 ms of long tasks per second.
    "rest_longtask_ms_per_s": 100,
    # A screen's content shows within 1.5 s of its trigger (the first screen: 4 s,
    # it downloads the app on a phone's network).
    "content_ms": 1500,
    "first_content_ms": 4000,
}


def window(rec, a, b):
    frames = [f for f in rec["frames"] if a <= f[0] < b]
    spans = [max(f[1], f[2]) for f in frames]
    lts = [t for t in rec["lt"] if a <= t[0] < b]
    loafs = [x for x in rec["loaf"] if a <= x["start"] < b]
    top = {}
    for x in loafs:
        for s in x["scripts"]:
            key = f"{s['type']}:{s['inv']}"
            top[key] = top.get(key, 0) + s["dur"]
    return {
        "seconds": round((b - a) / 1000, 2),
        "frames": len(frames),
        "over16": sum(1 for s in spans if s > FRAME),
        "over50": sum(1 for s in spans if s > 50),
        "worst_ms": round(max(spans, default=0), 1),
        "frame_ms_median": round(sorted(spans)[len(spans) // 2], 1) if spans else 0,
        "longtasks": len(lts),
        "longtask_ms": round(sum(t[1] for t in lts)),
        "loaf": len(loafs),
        "loaf_worst_ms": round(max((x["dur"] for x in loafs), default=0)),
        "loaf_scripts": dict(sorted(top.items(), key=lambda kv: -kv[1])[:3]),
    }


def measure(rec, moments):
    rows = []
    for m in moments:
        row = {"name": m["name"], "kind": m["kind"], **window(rec, m["t0"], m["t1"])}
        for k in ("content_ms", "tap", "note"):
            if k in m:
                row[k] = m[k]
        rows.append(row)
    return rows


def over_budget(rows):
    over = []
    for r in rows:
        name = f"{r['kind']} {r['name']}"
        if r["worst_ms"] > BUDGETS["worst_frame_ms"]:
            over.append(f"{name}: worst frame {r['worst_ms']} ms")
        if r["kind"] in ("transition", "tap") and r["frames"] >= 10:
            share = r["over16"] / r["frames"]
            if share > BUDGETS["over16_share"]:
                over.append(f"{name}: {r['over16']} of {r['frames']} frames over 16 ms")
        if r["kind"] == "screen" and r["seconds"] > 1:
            rate = r["longtask_ms"] / r["seconds"]
            if rate > BUDGETS["rest_longtask_ms_per_s"]:
                over.append(f"{name}: {round(rate)} ms of long tasks a second at rest")
        limit = BUDGETS["first_content_ms" if "first" in r["name"] else "content_ms"]
        if r.get("content_ms") is not None and r["content_ms"] > limit:
            over.append(f"{name}: content after {r['content_ms']} ms")
        if r.get("content_ms", 0) is None:
            over.append(f"{name}: its content never showed")
        tap = r.get("tap")
        if tap:
            first = tap.get("first_ms")
            if first is None or first > BUDGETS["tap_first_ms"]:
                over.append(f"{name}: first answer to the finger {first} ms")
            if tap.get("final_ms") is None or tap["final_ms"] > BUDGETS["tap_final_ms"]:
                over.append(f"{name}: final state {tap.get('final_ms')} ms")
    return over


def table(rows):
    head = (
        f"{'moment':44} {'s':>5} {'fr':>4} {'>16':>4} {'>50':>4} {'worst':>6} "
        f"{'LT':>3} {'LTms':>5} {'content':>7} {'tap1st':>6} {'final':>6} {'srv':>5}"
    )
    lines = [head]
    for r in rows:
        tap = r.get("tap") or {}

        def n(v):
            return "-" if v is None else str(round(v))

        lines.append(
            f"{(r['kind'][0] + ' ' + r['name'])[:44]:44} {r['seconds']:>5} "
            f"{r['frames']:>4} {r['over16']:>4} {r['over50']:>4} {r['worst_ms']:>6} "
            f"{r['longtasks']:>3} {r['longtask_ms']:>5} {n(r.get('content_ms')):>7} "
            f"{n(tap.get('first_ms')) if tap else '':>6} "
            f"{n(tap.get('final_ms')) if tap else '':>6} "
            f"{n(tap.get('server_ms')) if tap else '':>5}"
        )
    return "\n".join(lines)


def markdown(rows):
    out = [
        "| moment | s | frames | >16 ms | >50 ms | worst ms | long tasks | LT ms "
        "| content ms | tap: first change ms | tap: final ms | tap: server ms "
        "| before the server? |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        tap = r.get("tap") or {}
        cells = [
            f"{r['kind']} {r['name']}",
            r["seconds"],
            r["frames"],
            r["over16"],
            r["over50"],
            r["worst_ms"],
            r["longtasks"],
            r["longtask_ms"],
            r.get("content_ms", ""),
            tap.get("first_ms", ""),
            tap.get("final_ms", ""),
            tap.get("server_ms", ""),
            tap.get("before_server", ""),
        ]
        out.append(
            "| " + " | ".join("-" if c is None else str(c) for c in cells) + " |"
        )
    return "\n".join(out)


def save(path, result):
    with open(path, "w") as f:
        json.dump(result, f, indent=1)
