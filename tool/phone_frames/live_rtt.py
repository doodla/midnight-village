"""The live server's round trips, as a phone's requests meet them (read-mostly).

The local backend answers in milliseconds and hides what a phone at a real table
waits for. This opens ONE throwaway table on the public live server with three
throwaway guests ("Perf check A", "B", "C"), as the check after each merge does
(tool/deployed_sockets.py, whose socket client and game driver it reuses), and times:

- each endpoint a tap waits on, 10 or more samples (the first apart: it may meet a
  cold function), median and worst;
- how long a socket event takes to reach the other two guests, from the moment
  the request that causes it is sent (a deck change, the deal, play again).

Then everyone leaves (the last one out closes the table). No load: one request at a
time. Never the owner's accounts: only the public API, as any phone uses it.

    python3 tool/phone_frames/live_rtt.py [--api https://...] [--app https://...]
"""

import argparse
import importlib.util
import json
import statistics
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE.parent / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    a = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    a.add_argument("--api", default="https://midnight-village-anthelion.vercel.app")
    a.add_argument("--app", default="https://midnight-village-app-anthelion.vercel.app")
    a.add_argument("--samples", type=int, default=12)
    a.add_argument("--out", default="")
    args = a.parse_args()
    check, sockets = load("deployed_check"), load("deployed_sockets")
    api, origin = args.api.rstrip("/"), args.app.rstrip("/")
    times = {}

    def request(what, method, path, want, token=None, body=None, key=None):
        sent = time.monotonic()
        status, _, raw = check.call(
            method, api + path, body=body, token=token, origin=origin
        )
        took = (time.monotonic() - sent) * 1000
        name = key or f"{method} {what}"
        times.setdefault(name, []).append(took)
        if status not in want:
            raise RuntimeError(
                f"{what}: {method} {path} answered {status}: {raw[:200]!r}"
            )
        return status, (json.loads(raw) if raw else {})

    for _ in range(args.samples):
        request("health", "GET", "/api/health/", (200,))
    tokens = [
        request("guest", "POST", "/api/auth/guest/", (201,), body={"display_name": n})[
            1
        ]["access"]
        for n in ("Perf check A", "Perf check B", "Perf check C")
    ]
    host = tokens[0]
    heard = {}
    listeners = []
    try:
        code = request(
            "open a table",
            "POST",
            "/api/lobbies/",
            (201,),
            host,
            {"game_type": "onuw", "defaults": "v2"},
        )[1]["code"]
        for t in tokens[1:]:
            request("join", "POST", f"/api/lobbies/{code}/join/", (200,), t, {})
        for t in tokens * 4:
            request("where am I", "GET", "/api/me/table/", (200,), t)
            request("the table", "GET", f"/api/lobbies/{code}/", (200,), t)
        for t in tokens[1:]:
            listeners.append(
                sockets.Listener(
                    sockets.socket_url(api, f"/ws/lobby/{code}/", t), origin
                )
            )

        def heard_by_all(kind, wanted, send):
            sent = time.monotonic()
            send()
            for listener in listeners:
                listener.hear(wanted, sockets.HEAR)
                heard.setdefault(kind, []).append((time.monotonic() - sent) * 1000)

        # A deck change (the host's set-up page): the others' 02 hears it.
        for i in range(args.samples):
            seconds = 10 + 5 * (i % 2)
            heard_by_all(
                "deck change -> others' table",
                lambda e: e.get("type") == "lobby_update",
                lambda s=seconds: request(
                    "settings",
                    "PATCH",
                    f"/api/lobbies/{code}/",
                    (200,),
                    host,
                    {
                        "settings": {
                            "deck": "custom",
                            "roles": sockets.DECK,
                            "seats": 3,
                            **sockets.LENGTHS,
                            "voting_seconds": s,
                        }
                    },
                ),
            )
        game = {}
        heard_by_all(
            "deal -> others' screen",
            lambda e: e.get("type") == "game_started",
            lambda: game.update(
                request(
                    "deal", "POST", f"/api/onuw/lobbies/{code}/start/", (201,), host, {}
                )[1]
            ),
        )
        gid = game["game_id"]
        for t in tokens * 4:
            request("game me", "GET", f"/api/onuw/games/{gid}/me/", (200,), t)

        def play_call(what, method, path, want, token=None, body=None):
            key = f"{method} {path.split('/')[-2] if path.endswith('/') else what}"
            return request(what, method, path, want, token, body, key=f"play: {key}")

        sockets.play_to_results(play_call, gid, tokens)
        heard_by_all(
            "play again -> others' table",
            lambda e: e.get("type") == "lobby_update"
            and (e.get("data") or {}).get("status") == "waiting",
            lambda: request(
                "play again",
                "POST",
                f"/api/lobbies/{code}/play-again/",
                (200,),
                host,
                {},
            ),
        )
    finally:
        for listener in listeners:
            listener.close()
        for t in reversed(tokens):
            for _ in range(45):
                table = request("where am I", "GET", "/api/me/table/", (200,), t)[
                    1
                ].get("table")
                if not table:
                    break
                st, _ = request(
                    "leave",
                    "POST",
                    f"/api/lobbies/{table['lobby_code']}/leave/",
                    (200, 409),
                    t,
                    {},
                )
                if st == 200:
                    break
                time.sleep(2)

    def stats(xs):
        rest = xs[1:] or xs
        return {
            "n": len(xs),
            "first_ms": round(xs[0]),
            "median_ms": round(statistics.median(rest)),
            "worst_ms": round(max(rest)),
        }

    result = {
        "api": api,
        "requests": {k: stats(v) for k, v in sorted(times.items())},
        "socket_events": {k: stats(v) for k, v in heard.items()},
    }
    print(f"{'request':44} {'n':>3} {'first':>6} {'median':>6} {'worst':>6}")
    for k, s in list(result["requests"].items()) + list(
        result["socket_events"].items()
    ):
        print(
            f"{k[:44]:44} {s['n']:>3} {s['first_ms']:>6} {s['median_ms']:>6} {s['worst_ms']:>6}"
        )
    if args.out:
        Path(args.out).write_text(json.dumps(result, indent=1))


if __name__ == "__main__":
    main()
