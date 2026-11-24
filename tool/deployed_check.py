#!/usr/bin/env python3
"""Proves the live server and the live app work together, from outside.

Run by .github/workflows/deployed-check.yml after every merge to main, and by
hand. It uses only public addresses (no Vercel, database or Redis account):

1. waits until both addresses serve the merged commit (the server's
   /api/health/ and the app's /commit.txt both name it);
2. the server's health answers JSON;
3. the app's page loads and its bundle names the server it is checked against,
   the app's `/commit.txt` is the merged commit, a picture that is not there
   answers 404 (never the app's page), and the server lets the app's origin
   call it (a CORS preflight);
4. a real Start and Join through the deployed routing: guest A is made, opens a
   table, guest B joins by its code, both read the table and see two players;
   while that table is open, the app's own link to it (`/join/<code>`, what every
   QR code holds) answers 200 with the app's page: `/` is a file, so only a path
   like this one proves the host's rewrite works;
5. with `--sockets` (GitHub passes it): three guests sit at a table, two listen on
   its socket, the host deals, plays the game through and plays again, and both
   must hear the deal and the restart within seconds (tool/deployed_sockets.py).
   Nothing else opens a socket against the live server, and the deal and a restart
   reach the other phones no other way;
6. everyone leaves, always, even when a step failed or its answer was lost: each
   guest asks the server where it sits and leaves that table (the last one out
   deletes it). What stays behind: two guest accounts named `Deploy check A` and
   `Deploy check B`, and with `--sockets` three more (`A`, `B`, `C`); its two
   listeners count in "N at tables" for the seconds their sockets are open.

Every answer must be JSON with the expected status: a page of HTML where JSON
belongs (what a broken rewrite serves) fails the step that met it.

What this proves that the "Web page smoke" check does not: that check builds
the page and opens it in a browser against no server; it never makes a request
through the deployed routing. This one does, against what players are using.

usage: tool/deployed_check.py --api https://<server> [--app https://<app>]
                              [--commit <sha>] [--wait <seconds>] [--sockets]
Without --app the app steps are skipped (a local server, the backend's test).
Exit 0 when everything holds; 1 with one line per failed step.
"""

import argparse
import json
import signal
import sys
import time
import urllib.error
import urllib.request

GUEST_NAMES = ("Deploy check A", "Deploy check B")
TIMEOUT = 30


class Failed(Exception):
    pass


def call(method, url, body=None, token=None, origin=None, headers=None):
    """(status, headers, bytes) of one request; an HTTP error status is an answer, not an exception."""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/json")
    req.add_header("User-Agent", "midnight-village-deployed-check")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if origin:
        req.add_header("Origin", origin)
    for name, value in (headers or {}).items():
        req.add_header(name, value)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.status, resp.headers, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise Failed(f"{method} {url}: no answer ({e})") from e


def json_call(what, method, url, want, **kwargs):
    """The JSON body of a request that must answer `want` with JSON."""
    status, headers, raw = call(method, url, **kwargs)
    kind = headers.get("Content-Type", "")
    if status != want or "application/json" not in kind:
        start = raw[:120].decode("utf-8", "replace").replace("\n", " ")
        raise Failed(
            f"{what}: {method} {url} answered {status} {kind or 'no content type'},"
            f" wanted {want} JSON. It began: {start!r}"
        )
    try:
        body = json.loads(raw)
    except ValueError as e:
        raise Failed(f"{what}: {method} {url} said JSON but was not ({e})") from e
    if not isinstance(body, dict):
        raise Failed(f"{what}: {method} {url} answered JSON that is not an object")
    return body


def live_commits(api, app):
    """What each address says it is serving ('' when it does not say)."""
    try:
        server = json_call("health", "GET", f"{api}/api/health/", 200).get("commit", "")
    except Failed:
        server = ""
    page = ""
    if app:
        try:
            status, _, raw = call("GET", f"{app}/commit.txt")
            text = raw.decode("utf-8", "replace").strip()
            # the app's own page is served for any unknown path: that is not a commit
            page = text if status == 200 and len(text) <= 64 and "<" not in text else ""
        except Failed:
            page = ""
    return server, page


def no_deploy_message(commit, seconds, server, page, has_app, app_commit=None):
    """What to say when a wanted build never went live: each side on its own line
    (Vercel builds, and skips, the server and the app separately, and each is
    deployed from its own branch, so each may be waiting for its own commit)."""

    def side(name, serving, wanted):
        if serving == wanted:
            return f"  {name}: deployed ({wanted[:10]})."
        return (
            f"  {name}: NO deploy of {wanted[:10]} arrived;"
            f" still serving {serving[:10] or 'an unnamed build'}."
        )

    lines = [f"a build is not live after {seconds} s:"]
    lines.append(side("server", server, commit))
    if has_app:
        lines.append(side("app", page, app_commit or commit))
    lines.append(
        "  If nothing failed in Vercel's deployments list, this is its daily cap"
        " (100 deployments in 24 hours, two per merge): the next merge that gets"
        " a slot carries this one. The steps below check the builds that ARE serving."
    )
    return "\n".join(lines)


def wait_for_commit(
    api, app, commit, seconds, sleep=time.sleep, clock=time.monotonic, app_commit=None
):
    """Blocks until the server serves `commit` and the app `app_commit` (the same
    commit when not given); Failed when they do not within `seconds`."""
    app_commit = app_commit or commit
    deadline = clock() + seconds
    while True:
        server, page = live_commits(api, app)
        if server == commit and (not app or page == app_commit):
            return
        if clock() >= deadline:
            raise Failed(
                no_deploy_message(commit, seconds, server, page, bool(app), app_commit)
            )
        sleep(10)


def check_health(api):
    body = json_call("health", "GET", f"{api}/api/health/", 200)
    if body.get("status") != "ok":
        raise Failed(f"health: the server answered {body!r}, wanted status ok")


def check_join_link(app, code):
    """The link a QR code holds, for a table that is open right now, serves the app."""
    url = f"{app}/join/{code}"
    status, _, raw = call("GET", url, headers={"Accept": "text/html"})
    if status != 200 or b"flutter_bootstrap" not in raw:
        raise Failed(
            f"the table's link: GET {url} answered {status} and is not the app's page"
            " (the host's rewrite for app routes is broken: every QR link would fail)"
        )


def check_commit(app, commit):
    """The app serves the merged commit's build (/commit.txt)."""
    status, _, raw = call("GET", f"{app}/commit.txt")
    served = raw.decode("utf-8", "replace").strip()
    if status != 200 or served != commit:
        raise Failed(
            f"the app's build: GET {app}/commit.txt answered {status} {served[:40]!r},"
            f" wanted the merged commit {commit[:10]}"
        )


def check_app(api, app, commit=None):
    status, headers, raw = call("GET", f"{app}/", headers={"Accept": "text/html"})
    if status != 200 or b"flutter" not in raw.lower():
        raise Failed(f"the app's page: GET {app}/ answered {status} and is not the app")
    status, _, bundle = call("GET", f"{app}/main.dart.js", headers={"Accept": "*/*"})
    if status != 200 or api.encode() not in bundle:
        raise Failed(
            f"the app's bundle ({app}/main.dart.js, status {status}) does not name the server"
            f" {api}: the app was built against another server"
        )
    # A file that is not there must look missing: an open app that asks for a picture
    # a newer build removed must get a 404, never the app's page (frontend/vercel.json).
    status, _, _ = call("GET", f"{app}/assets/no-such-picture-deployed-check.webp")
    if status != 404:
        raise Failed(
            f"a missing picture: GET {app}/assets/no-such-picture-deployed-check.webp"
            f" answered {status}, wanted 404 (the app's page must not stand in for a file)"
        )
    if commit:
        check_commit(app, commit)
    status, headers, _ = call(
        "OPTIONS",
        f"{api}/api/auth/guest/",
        origin=app,
        headers={
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )
    allowed = headers.get("Access-Control-Allow-Origin", "")
    if status >= 400 or allowed not in (app, "*"):
        raise Failed(
            f"the server does not let the app call it: a preflight from {app} answered"
            f" {status} with Access-Control-Allow-Origin {allowed!r}"
        )


def start_and_join(api, origin=None, on_table=None):
    """Guest A opens a table, guest B joins by code, both see two players; both always leave.

    `on_table(code)` is called while the table is open (the app's link to it is probed then)."""
    guests = []  # the tokens of the guests made, in order: the host, then the joiner

    def guest(name):
        made = json_call(
            f"guest {name}",
            "POST",
            f"{api}/api/auth/guest/",
            201,
            body={"display_name": name},
            origin=origin,
        )
        if not made.get("access"):
            raise Failed(f"guest {name}: no access token in {sorted(made)}")
        guests.append(made["access"])
        return made["access"]

    try:
        a = guest(GUEST_NAMES[0])
        table = json_call(
            "Start (open a table)",
            "POST",
            f"{api}/api/lobbies/",
            201,
            body={"game_type": "onuw", "defaults": "v2"},
            token=a,
            origin=origin,
        )
        code = table.get("code")
        if not code:
            raise Failed(f"Start: no table code in {sorted(table)}")
        if on_table:
            on_table(code)
        b = guest(GUEST_NAMES[1])
        joined = json_call(
            "Join by code",
            "POST",
            f"{api}/api/lobbies/{code}/join/",
            200,
            body={},
            token=b,
            origin=origin,
        )
        for who, token, body in (("the joiner", b, joined), ("the host", a, None)):
            if body is None:
                body = json_call(
                    "read the table",
                    "GET",
                    f"{api}/api/lobbies/{code}/",
                    200,
                    token=token,
                    origin=origin,
                )
            names = sorted(p["user"]["display_name"] for p in body.get("players", []))
            if names != sorted(GUEST_NAMES):
                raise Failed(
                    f"{who} sees {names} at the table, wanted {sorted(GUEST_NAMES)}"
                )
    finally:
        # Ask the server where each guest sits and leave that table: a Start or a Join
        # that happened but whose answer was lost is cleaned up too. The joiner first,
        # the host last, so the last one out deletes the table.
        problems = []
        for token in reversed(guests):
            try:
                where = json_call(
                    "where am I",
                    "GET",
                    f"{api}/api/me/table/",
                    200,
                    token=token,
                    origin=origin,
                )
                table = where.get("table")
                if table:
                    json_call(
                        "leave",
                        "POST",
                        f"{api}/api/lobbies/{table['lobby_code']}/leave/",
                        200,
                        body={},
                        token=token,
                        origin=origin,
                    )
            except Failed as e:
                problems.append(str(e))
        if problems and sys.exc_info()[0] is None:
            raise Failed("; ".join(problems))


_socket_leg = None


def socket_leg():
    """tool/deployed_sockets.py, loaded once from beside this file (no install, no path)."""
    global _socket_leg
    if _socket_leg is None:
        import importlib.util
        from pathlib import Path

        spec = importlib.util.spec_from_file_location(
            "deployed_sockets", Path(__file__).resolve().parent / "deployed_sockets.py"
        )
        _socket_leg = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_socket_leg)
    return _socket_leg


def deal_is_heard(api, origin=None, patience=90, say=print):
    """The socket leg (tool/deployed_sockets.py): three guests, two listening on the
    lobby's socket; the host deals and plays again, and both must hear each within
    seconds. Everyone always leaves: a table in a game cannot be left, so leaving is
    tried until the game (its lengths are short) has ended, for `patience` seconds."""
    sockets = socket_leg()
    guests = []

    def request(what, method, path, want, token=None, body=None):
        status, headers, raw = call(
            method, f"{api}{path}", body=body, token=token, origin=origin
        )
        kind = headers.get("Content-Type", "")
        if status not in want or "application/json" not in kind:
            start = raw[:160].decode("utf-8", "replace").replace("\n", " ")
            raise Failed(
                f"{what}: {method} {path} answered {status}, wanted {want}. It began: {start!r}"
            )
        return status, json.loads(raw)

    def guest(name):
        made = request(
            f"guest {name}",
            "POST",
            "/api/auth/guest/",
            (201,),
            body={"display_name": name},
        )[1]
        guests.append(made["access"])
        return made["access"]

    try:
        sockets.deal_is_heard(request, api, origin, guest, say)
    except sockets.SocketFailed as e:
        raise Failed(str(e)) from e
    finally:
        problems, deadline = [], time.monotonic() + patience
        for token in reversed(guests):
            try:
                while True:
                    table = request(
                        "where am I", "GET", "/api/me/table/", (200,), token
                    )[1].get("table")
                    if not table:
                        break
                    status, _ = request(
                        "leave",
                        "POST",
                        f"/api/lobbies/{table['lobby_code']}/leave/",
                        (200, 409),
                        token,
                        {},
                    )
                    if status == 200:
                        break
                    if time.monotonic() > deadline:
                        raise Failed(
                            f"table {table['lobby_code']} is still in a game after {patience} s: a guest is left seated"
                        )
                    time.sleep(2)  # the game ends by its own short timers
            except Failed as e:
                problems.append(str(e))
        if problems and sys.exc_info()[0] is None:
            raise Failed("; ".join(problems))


def run(api, app=None, commit=None, wait=900, app_commit=None, sockets=False):
    """Every step in order; returns the list of failures (empty when all hold)."""
    api, app = api.rstrip("/"), (app or "").rstrip("/") or None
    steps = []
    if commit:
        steps.append(
            (
                "the merged commit is live",
                lambda: wait_for_commit(api, app, commit, wait, app_commit=app_commit),
            )
        )
    steps.append(("the server's health", lambda: check_health(api)))
    arrived = {"commit": app_commit or commit}  # None once the wait has failed
    if app:
        steps.append(
            (
                "the app and its server",
                lambda: check_app(api, app, arrived["commit"]),
            )
        )
    steps.append(
        (
            "Start and Join",
            lambda: start_and_join(
                api,
                origin=app,
                on_table=(lambda code: check_join_link(app, code)) if app else None,
            ),
        )
    )
    if sockets:
        steps.append(
            (
                "a deal and a restart are heard on the socket",
                lambda: deal_is_heard(api, origin=app),
            )
        )
    failures = []
    for name, step in steps:
        try:
            step()
            print(f"ok    {name}")
        except Failed as e:
            print(f"FAIL  {name}: {e}")
            failures.append(f"{name}: {e}")
            if name == "the merged commit is live":
                # No deploy arrived (Vercel skipped it, or it failed): the rest
                # checks the builds that ARE serving, which players are on.
                arrived["commit"] = None
    return failures


def stop_like_ctrl_c(signum, frame):
    """A cancelled run (SIGTERM) leaves like an interrupted one: the guests still stand up."""
    raise KeyboardInterrupt


def main(argv=None):
    signal.signal(signal.SIGTERM, stop_like_ctrl_c)
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--api", required=True, help="the server's origin, https://<host>")
    p.add_argument(
        "--app", help="the web app's origin; without it the app steps are skipped"
    )
    p.add_argument("--commit", help="wait until the server serves this commit")
    p.add_argument(
        "--app-commit",
        help="wait until the app serves this one (default: the same as --commit)",
    )
    p.add_argument(
        "--wait", type=int, default=900, help="how long to wait for it, in seconds"
    )
    p.add_argument(
        "--sockets",
        action="store_true",
        help="also prove that a deal and a restart reach the other players' sockets",
    )
    args = p.parse_args(argv)
    failures = run(
        args.api,
        args.app,
        args.commit,
        args.wait,
        args.app_commit,
        sockets=args.sockets,
    )
    if failures:
        print(f"\nThe live game is NOT proven working: {len(failures)} step(s) failed.")
        return 1
    print("\nThe live server and the live app work together.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
