#!/usr/bin/env python3
"""Where a frame's time goes, from the traces `just phone-frames --trace <dir>`
writes (one Chrome trace per screen at rest, best on a profile build:
PHONE_FRAMES_PROFILE=1 keeps the Dart names).

For each screen: its frames (the animation-frame tasks that draw a Flutter
frame) and what one costs on the page's main thread, how long the GPU process
was busy per frame (where a software-drawn Chrome fills the pixels), and the
JavaScript samples inside the frames, by function (self time) and by the
stages of a Flutter frame (inclusive time).

Usage: python3 -I tool/phone_frames/trace_cost.py <trace dir> [--top N]
"""

import argparse
import json
import os
import sys
from collections import Counter

# Stages of a frame, by the Dart function that runs it (inclusive time).
STAGES = [
    ("build", ("buildScope", "BuildOwner.buildScope")),
    ("layout", ("flushLayout",)),
    ("paint (record)", ("flushPaint",)),
    ("composite (scene)", ("compositeFrame",)),
    (
        "raster (CanvasKit)",
        ("Rasterizer.draw", "rasterize", "_rasterize", "renderScene"),
    ),
    ("image decode", ("instantiateImageCodec", "decodeImage", "_decode")),
    ("toImageSync", ("toImageSync",)),
]


def threads(events):
    names = {}
    for e in events:
        if e.get("ph") == "M" and e.get("name") == "thread_name":
            names[(e["pid"], e["tid"])] = e["args"]["name"]
    return names


def busy(events, key, lo, hi):
    """Time the thread ran top-level tasks inside [lo, hi] (microseconds)."""
    total = 0
    for e in events:
        if (e.get("pid"), e.get("tid")) != key or e.get("ph") != "X":
            continue
        if e.get("name") not in ("ThreadControllerImpl::RunTask", "RunTask"):
            continue
        a, b = e["ts"], e["ts"] + e.get("dur", 0)
        total += max(0, min(b, hi) - max(a, lo))
    return total


def profile(events, windows):
    """Self and inclusive sample time per function inside the windows."""
    nodes, parent = {}, {}
    samples = []
    start = None
    for e in events:
        if e.get("name") == "Profile":
            start = e["args"]["data"].get("startTime", start)
        if e.get("name") != "ProfileChunk":
            continue
        data = e["args"]["data"]
        cpu = data.get("cpuProfile", {})
        for n in cpu.get("nodes", []):
            nodes[n["id"]] = n["callFrame"].get("functionName") or "(anon)"
            if "parent" in n:
                parent[n["id"]] = n["parent"]
        ts = data.get("timeDeltas", [])
        t = samples[-1][0] if samples else (start or e["ts"])
        for node, d in zip(cpu.get("samples", []), ts):
            t += d
            samples.append((t, node))
    self_t, incl = Counter(), Counter()
    for i, (t, node) in enumerate(samples):
        if not any(a <= t <= b for a, b in windows):
            continue
        dt = samples[i + 1][0] - t if i + 1 < len(samples) else 0
        if dt <= 0 or dt > 50_000:
            continue
        self_t[nodes.get(node, "?")] += dt
        seen = set()
        n = node
        while n is not None:
            name = nodes.get(n, "?")
            if name not in seen:
                incl[name] += dt
                seen.add(name)
            n = parent.get(n)
    return self_t, incl


def screen(path, top):
    with open(path) as f:
        raw = json.load(f)
    events = raw["traceEvents"] if isinstance(raw, dict) else raw
    names = threads(events)
    main = [k for k, v in names.items() if v == "CrRendererMain"]
    gpu = [k for k, v in names.items() if v == "CrGpuMain"]
    frames = []
    for e in events:
        if (
            e.get("ph") == "X"
            and e.get("name") == "FireAnimationFrame"
            and (e["pid"], e["tid"]) in main
        ):
            frames.append((e["ts"], e["ts"] + e.get("dur", 0)))
    out = {"frames": len(frames)}
    if not frames:
        return out
    durs = sorted(b - a for a, b in frames)
    out["frame_ms_median"] = durs[len(durs) // 2] / 1000
    out["frame_ms_worst"] = durs[-1] / 1000
    lo, hi = frames[0][0], frames[-1][1] + 100_000
    if gpu:
        out["gpu_ms_per_frame"] = busy(events, gpu[0], lo, hi) / 1000 / len(frames)
    self_t, incl = profile(events, frames)
    total = sum(self_t.values()) or 1
    out["js_ms_per_frame"] = total / 1000 / len(frames)
    out["stages_ms_per_frame"] = {
        stage: round(
            max((incl[n] for n in incl if any(m in n for m in marks)), default=0)
            / 1000
            / len(frames),
            1,
        )
        for stage, marks in STAGES
    }
    out["top_self"] = [
        (n, round(t / 1000 / len(frames), 1)) for n, t in self_t.most_common(top)
    ]
    return out


def main():
    a = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    a.add_argument("folder")
    a.add_argument("--top", type=int, default=12)
    a.add_argument("--json", default="", help="write the numbers here")
    args = a.parse_args()
    got = {}
    for name in sorted(os.listdir(args.folder)):
        if name.endswith(".json"):
            got[name[:-5]] = screen(os.path.join(args.folder, name), args.top)
    for name, r in got.items():
        print(f"\n## {name}: {r.get('frames')} frames")
        if not r.get("frames"):
            continue
        print(
            f"  frame median {r['frame_ms_median']:.0f} ms, worst "
            f"{r['frame_ms_worst']:.0f} ms; JS {r['js_ms_per_frame']:.0f} ms/frame; "
            f"GPU process {r.get('gpu_ms_per_frame', 0):.0f} ms/frame"
        )
        print(
            "  stages (ms/frame, inclusive): "
            + ", ".join(f"{k} {v}" for k, v in r["stages_ms_per_frame"].items())
        )
        print(
            "  top self time (ms/frame): "
            + "; ".join(f"{n} {t}" for n, t in r["top_self"])
        )
    if args.json:
        with open(args.json, "w") as f:
            json.dump(got, f, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
