#!/usr/bin/env python3
"""Is a change faster or slower on a phone? One command, one verdict per moment.

    just speed-verdict <base> [<head>] [--moments a,b] [--runs N] [--cpu C] [--out dir]
    just speed-verdict --list                      the moments, from the script itself

`base` and `head` are git refs; `head` defaults to this working tree (uncommitted
changes and all). Each ref gets a checkout of its own (a cached worktree), its app built
once (as phone-frames builds it) and its own server. The game is played by THIS tree's
phone-frames (one instrument for both sides): first a map pass per side, then the
measured runs, alternated A B B A A B ..., N a side, so a machine that slows down over
the hour slows both sides alike. The whole command holds every slot of the heavy queue
(`tool/heavy.py --alone`): no test suite or build runs beside it. So a default verdict
stops every other builder's heavy work for about 34 minutes: run it when the machine is
free, never as a routine step of a piece. Without `--alone` its numbers are not proved
honest: other jobs' load lands on random runs, and no same-code runs were taken that way.

Per moment it prints better / level / worse, the median and range of each side and
the gap, under one rule (verdict.RULE); "level" says no measurable difference. Then
one sentence for the owner, and the same in `verdict.json` and `verdict.md` beside the
runs. A run whose step was lost (moments.Lost: a hold that did not register, a tap that
sent nothing, an answer that never came) keeps no number from that step on, and is
replaced once a side; a moment still short of N numbers a side is "not measured", with
the reason. Exit 0 when every moment asked for was measured, whatever the verdict;
1 when one was not; 2 when a side could not be built or played at all.
"""

import argparse
import datetime
import hashlib
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import script  # noqa: E402
import verdict  # noqa: E402

# Same code on both sides (13 runs of main, every split): at 3 a side a verdict called
# something in 33% of them, at 4 in 5.2%, at 5 in 0.8% (verdict.py's docstring). A
# default verdict is about 34 min of the whole heavy queue (8 runs of 4 min, a build and
# a map pass); `--moments` of a few, the cheapest that holds, ends each run early.
DEFAULT_RUNS = 4
DEFAULT_GAMES = 1


def options():
    a = argparse.ArgumentParser(
        prog="just speed-verdict", description=__doc__.split("\n\n")[0]
    )
    a.add_argument("base", nargs="?", help="the ref to compare against (origin/main)")
    a.add_argument("head", nargs="?", help="the ref measured (default: this tree)")
    a.add_argument("--moments", default="", help="only these (parts of names, a,b)")
    a.add_argument("--runs", type=int, default=DEFAULT_RUNS, help="runs a side")
    a.add_argument("--games", type=int, default=DEFAULT_GAMES, help="games (1 to 3)")
    a.add_argument("--cpu", type=float, default=4, help="CPU slowdown (4)")
    a.add_argument("--out", default="", help="where the runs and the verdict go")
    a.add_argument("--list", action="store_true", help="print the moments and stop")
    return a


def git(*args, cwd=ROOT):
    return subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True, check=True
    ).stdout.strip()


def commit(ref):
    try:
        return git("rev-parse", "--verify", f"{ref}^{{commit}}")
    except subprocess.CalledProcessError:
        raise SystemExit(f"[speed-verdict] {ref!r} is not a commit here (git fetch?)")


def cache_dir():
    return Path(
        os.environ.get("SPEED_VERDICT_DIR")
        or Path.home() / ".cache" / "midnight-village" / "speed-verdict"
    )


def checkout(sha):
    """A worktree of `sha` of its own (kept, so its build is reused next time)."""
    place = cache_dir() / sha[:12]
    if place.exists():
        try:
            if git("rev-parse", "HEAD", cwd=place) == sha:
                return place
        except subprocess.CalledProcessError:
            pass
        git("worktree", "remove", "--force", str(place))
    place.parent.mkdir(parents=True, exist_ok=True)
    git("worktree", "prune")
    git("worktree", "add", "--detach", "--force", str(place), sha)
    return place


def port_for(place):
    """A port that stays the same for a checkout (its build names the server's port,
    so a new port is a new build), or a free one when that is taken."""
    preferred = 20000 + int(hashlib.sha1(str(place).encode()).hexdigest(), 16) % 9000
    for port in (preferred, 0):
        s = socket.socket()
        try:
            s.bind(("127.0.0.1", port))
            return s.getsockname()[1]
        except OSError:
            continue
        finally:
            s.close()
    raise SystemExit("[speed-verdict] no free port")


class Side:
    def __init__(self, label, ref, sha, place):
        self.label, self.ref, self.sha, self.place = label, ref, sha, place
        self.port = port_for(place)
        self.runs = []

    def describe(self):
        return {"ref": self.ref, "commit": self.sha, "checkout": str(self.place)}


def phone_frames(side, out, name, extra):
    """One call of run.sh for a side: (exit code, the json it wrote or None, its log)."""
    env = {
        **os.environ,
        "PHONE_FRAMES_FRONTEND": str(side.place / "frontend"),
        "PHONE_FRAMES_BACKEND": str(side.place),
        "PHONE_FRAMES_PORT": str(side.port),
    }
    log = out / f"{name}.log"
    with open(log, "w") as f:
        code = subprocess.run(
            [str(HERE / "run.sh"), *extra], cwd=ROOT, env=env, stdout=f, stderr=f
        ).returncode
    got = out / f"{name}.json"
    return code, (json.loads(got.read_text()) if got.exists() else None), log


def tail(log, lines=6):
    text = [x for x in log.read_text().splitlines() if x.strip()]
    return " | ".join(text[-lines:])


def values(result, chosen):
    """Each moment's number in one run: a tap's first answer near the finger, an
    event's first change, a cold load's content."""
    rows = {r["name"]: r for r in result["rows"]}
    out = {}
    for m in chosen:
        r = rows.get(m["name"])
        if r is None:
            continue
        if m["kind"] == "tap":
            out[m["name"]] = (r.get("tap") or {}).get("first_ms")
        elif m["kind"] == "event":
            out[m["name"]] = r.get("first_change_ms") or _first_step(r)
        else:
            out[m["name"]] = r.get("content_ms")
    return out


def _first_step(row):
    steps = row.get("steps") or []
    return steps[0][0] if steps else None


def write(path, data):
    path.write_text(json.dumps(data, indent=1) + "\n")


def exit_code(rows):
    return 1 if any(r["verdict"] == "not measured" for r in rows) else 0


def order(runs):
    """A B B A A B ...: a drift over the hour falls on both sides alike."""
    out = []
    for i in range(runs):
        out += ["base", "head"] if i % 2 == 0 else ["head", "base"]
    return out


def main(argv):
    args = options().parse_args(argv)
    if args.list:
        print(script.describe())
        return 0
    if not args.base:
        options().print_usage(sys.stderr)
        print("[speed-verdict] name a base ref (origin/main)", file=sys.stderr)
        return 2
    try:
        chosen, games = script.pick(args.moments, args.games)
    except LookupError as e:
        print(f"[speed-verdict] {e}", file=sys.stderr)
        return 2
    if args.runs < 2:
        print("[speed-verdict] a verdict needs at least 2 runs a side", file=sys.stderr)
        return 2
    if not os.environ.get("HEAVY_SLOT"):
        # Every slot of the heavy queue for the whole verdict: nothing runs beside it.
        heavy = [sys.executable, str(ROOT / "tool" / "heavy.py"), "--alone"]
        heavy += ["--name", "speed-verdict", "--", sys.executable, __file__, *argv]
        os.execv(sys.executable, heavy)
    for m in chosen:
        m["plain"] = script.plain(m["name"])
    started = time.monotonic()
    base_sha = commit(args.base)
    base = Side(
        f"{args.base} ({base_sha[:7]})", args.base, base_sha, checkout(base_sha)
    )
    if args.head:
        head_sha = commit(args.head)
        head = Side(
            f"{args.head} ({head_sha[:7]})", args.head, head_sha, checkout(head_sha)
        )
    else:
        head_sha = git("rev-parse", "HEAD")
        dirty = " + changes" if git("status", "--porcelain") else ""
        head = Side(
            f"this tree ({head_sha[:7]}{dirty})", "working tree", head_sha, ROOT
        )
    when = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    out = Path(args.out or ROOT / "frontend" / "build" / "speed_verdict" / when)
    out.mkdir(parents=True, exist_ok=True)
    sides = {"base": base, "head": head}
    common = ["--cpu", str(args.cpu), "--games", str(games)]
    if args.moments:
        common += ["--moments", ",".join(m["name"] for m in chosen)]
    print(f"[speed-verdict] base {base.label}, head {head.label}", flush=True)
    print(
        f"[speed-verdict] {len(chosen)} moments, {args.runs} runs a side, CPU {args.cpu}x;"
        f" runs and logs in {out}",
        flush=True,
    )
    # Each side once: its build (cached by content) and its map pass.
    for label, side in sides.items():
        maps = out / f"{label}.map.json"
        if side is head and base.place == head.place:
            maps.write_text((out / "base.map.json").read_text())
            continue
        print(f"[speed-verdict] {label}: build and map pass", flush=True)
        code, _, log = phone_frames(
            side, out, f"{label}.map", [*common, "--boxes", str(maps), "--map-only"]
        )
        if code != 0 or not maps.exists():
            print(
                f"[speed-verdict] {label} ({side.label}) could not be built or played:"
                f" {tail(log)}\n  the whole log: {log}",
                file=sys.stderr,
            )
            return 2
    plan = order(args.runs)
    done = []
    spare = {"base": 1, "head": 1}
    i = 0
    while i < len(plan):
        label = plan[i]
        side = sides[label]
        n = sum(1 for x in plan[: i + 1] if x == label)
        name = f"{label}{n}"
        t0 = time.monotonic()
        code, result, log = phone_frames(
            side,
            out,
            name,
            [
                *common,
                "--boxes",
                str(out / f"{label}.map.json"),
                "--out",
                str(out / f"{name}.json"),
            ],
        )
        took = time.monotonic() - t0
        run = {
            "name": name,
            "code": code,
            "seconds": round(took),
            "lost": None,
            "failed": None,
        }
        if result is None:
            run["failed"] = f"run {name} failed (exit {code}): {tail(log, 3)}"
            run["values"] = {}
        else:
            run["lost"] = result.get("lost")
            run["values"] = values(result, chosen)
        side.runs.append(run)
        done.append(name)
        said = "measured" if not (run["lost"] or run["failed"]) else "LOST"
        print(f"[speed-verdict] {name}: {said} in {took / 60:.1f} min", flush=True)
        if run["lost"] or run["failed"]:
            why = (
                run["failed"] or f"lost at {run['lost']['at']!r}: {run['lost']['why']}"
            )
            print(f"  {why}\n  log: {log}", file=sys.stderr, flush=True)
            if spare[label]:
                spare[label] -= 1
                plan.append(label)
                print(f"  one more {label} run replaces it", flush=True)
        i += 1
    good = {
        k: [r for r in s.runs if not (r["lost"] or r["failed"])]
        for k, s in sides.items()
    }
    # A lost run still counts for the moments it measured before it was lost.
    pool = {
        k: sorted(s.runs, key=lambda r: bool(r["lost"] or r["failed"]))
        for k, s in sides.items()
    }
    rows = verdict.compare(chosen, pool["base"], pool["head"], args.runs)
    text = verdict.table(rows, base.label, head.label)
    said = verdict.sentence(rows)
    minutes = (time.monotonic() - started) / 60
    print()
    print(text)
    print(f"\nRule: {verdict.RULE}.")
    print(f"\n{said}")
    print(
        f"\n[speed-verdict] {minutes:.0f} min; {len(good['base'])}+{len(good['head'])}"
        f" whole runs; verdict in {out / 'verdict.json'}"
    )
    result = {
        "base": base.describe(),
        "head": head.describe(),
        "cpu": args.cpu,
        "games": games,
        "runs_a_side": args.runs,
        "order": done,
        "rule": verdict.RULE,
        "rows": rows,
        "sentence": said,
        "minutes": round(minutes, 1),
        "runs": {k: s.runs for k, s in sides.items()},
    }
    write(out / "verdict.json", result)
    (out / "verdict.md").write_text(
        f"base {base.label}, head {head.label}, {args.runs} runs a side, CPU {args.cpu}x\n\n"
        f"```\n{text}\n```\n\nRule: {verdict.RULE}.\n\n{said}\n"
    )
    return exit_code(rows)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
