#!/usr/bin/env python3
"""
ONUW single-agent game driver — clean REST verbs over the real player API + the
DEBUG oracle, so one agent can drive an entire multiplayer game (every player)
and verify the emergent state against the rules.

This is a TEST/EXPLORATION tool, not app code. It talks to the booted harness
backend (DEBUG=True) on 127.0.0.1:8001 by default. It is intentionally
dependency-free (stdlib urllib) so it runs anywhere with `python3`.

The driver (a Claude agent or a human) calls primitives and reasons between
them; it never needs a WebSocket — it polls `me` and advances phases with the
host endpoints. Non-2xx responses are PRINTED, not raised: observing how the
server rejects a bad move (400 vs 500 vs leak) is the whole point.

Session: `setup` writes a session file mapping player name -> {user_id, token}
keyed by game_id, so later commands resolve a player by name. The first player
in the spec is the host (lobby creator) and holds the host-only endpoints.

Usage:
  python tools/game_driver.py setup --spec spec.json
  python tools/game_driver.py me --game <id> --player Alice
  python tools/game_driver.py act --game <id> --player Alice --action peek_player --targets '{"player_id": 12}'
  python tools/game_driver.py advance-wave --game <id>          # close the open night window
  python tools/game_driver.py vote --game <id> --player Alice --target 13
  python tools/game_driver.py end-discussion --game <id>
  python tools/game_driver.py reveal-votes --game <id>
  python tools/game_driver.py results --game <id>
  python tools/game_driver.py oracle --game <id>
  python tools/game_driver.py fire-timer --game <id> --key voting   # or wave:1 / wave:2 / current

spec.json:
  {
    "players": ["Alice", "Bob", "Carol", "Dave", "Eve"],
    "roles":   {"Alice": "Werewolf", "Bob": "Seer", "Carol": "Robber",
                "Dave": "Villager", "Eve": "Villager"},
    "center":  ["Werewolf", "Troublemaker", "Minion"]
  }
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Any

API_BASE = os.environ.get("DRIVER_API_BASE", "http://127.0.0.1:8001/api")
SESSION_DIR = Path(os.environ.get("DRIVER_SESSION_DIR", ".driver"))


# ---------------------------------------------------------------------------
# HTTP (stdlib; never raises on 4xx/5xx — the caller wants to SEE rejections)
# ---------------------------------------------------------------------------
def _req(
    method: str, path: str, token: str | None = None, body: dict | None = None
) -> tuple[int, Any]:
    url = f"{API_BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    # dart:io has no Origin; a non-browser HTTP client doesn't need one for REST
    # (only the channels WS OriginValidator cares), so REST works without it.
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            parsed = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            parsed = raw
        return e.code, parsed
    except urllib.error.URLError as e:
        return 0, {
            "error": f"connection failed: {e.reason}. Is the harness "
            f"backend up on {API_BASE}? (cd backend && just harness-serve)"
        }


# ---------------------------------------------------------------------------
# Session persistence
# ---------------------------------------------------------------------------
def _session_path(game_id: str) -> Path:
    return SESSION_DIR / f"session-{game_id}.json"


def _load_session(game_id: str) -> dict:
    path = _session_path(game_id)
    if not path.exists():
        _die(f"no session for game {game_id} at {path}; run `setup` first")
    return json.loads(path.read_text())


def _token_for(session: dict, player: str) -> str:
    players = session["players"]
    if player not in players:
        _die(f"unknown player '{player}'. known: {list(players)}")
    return players[player]["token"]


def _host_token(session: dict) -> str:
    return _token_for(session, session["host"])


def _die(msg: str) -> None:
    print(json.dumps({"status": "error", "detail": msg}, indent=2))
    sys.exit(1)


def _out(payload: Any) -> None:
    print(json.dumps(payload, indent=2, default=str))


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
def cmd_setup(args: argparse.Namespace) -> None:
    spec = json.loads(Path(args.spec).read_text())
    players: list[str] = spec["players"]
    roles: dict[str, str] = spec["roles"]
    center: list[str] = spec["center"]

    if set(players) != set(roles):
        _die("spec.players and spec.roles keys must match")
    if len(center) != 3:
        _die("spec.center must have exactly 3 cards")

    # Derive role counts from the assignment + center (this is what the lobby is
    # configured with; the backend re-validates the forced multiset against it).
    role_counts = dict(Counter(list(roles.values()) + list(center)))

    # Disable wall-clock auto-advance by default: a `*_seconds` of 0 makes the
    # backend skip scheduling that phase/window timer (services.py), so NOTHING
    # advances on its own and the (slow) driver controls every transition via
    # advance-wave / end-discussion / reveal-votes. Without this, the night
    # times out before an LLM agent can act. The night has two windows:
    #   night_wave_seconds                 maximum length of a window (0 = none)
    #   night_min_window_seconds           a window never closes sooner than this
    #                                      after it opens (0 = close as soon as
    #                                      every actor has submitted)
    #   night_doppelganger_window_seconds  fixed length of window 1 (0 = off:
    #                                      window 1 closes like window 2)
    # A spec may override any of these (e.g. a short night_wave_seconds to test
    # the timeout path, or the real 8s / 10s values to see the shared window).
    timers_cfg = {
        "night_wave_seconds": 0,
        "night_min_window_seconds": 0,
        "night_doppelganger_window_seconds": 0,
        "discussion_seconds": 0,
        "voting_seconds": 0,
    }
    timers_cfg.update(spec.get("timers", {}))

    # 1. Create a guest per player; first player is host.
    created: dict[str, dict] = {}
    for name in players:
        st, body = _req("POST", "/auth/guest/", body={"display_name": name})
        if st != 201:
            _die(f"guest create for {name} failed ({st}): {body}")
        created[name] = {"user_id": body["user"]["id"], "token": body["access"]}

    host = players[0]
    host_tok = created[host]["token"]

    # 2. Host creates the lobby.
    st, body = _req("POST", "/lobbies/", token=host_tok, body={"game_type": "onuw"})
    if st != 201:
        _die(f"lobby create failed ({st}): {body}")
    code = body["code"]

    # 3. Everyone else joins; everyone readies.
    for name in players[1:]:
        st, body = _req("POST", f"/lobbies/{code}/join/", token=created[name]["token"])
        if st not in (200, 201):
            _die(f"{name} join failed ({st}): {body}")
    for name in players:
        st, _ = _req("POST", f"/lobbies/{code}/ready/", token=created[name]["token"])
        if st not in (200, 201):
            _die(f"{name} ready failed ({st})")

    # 4. Host sets the role config + (driver-controlled) timers.
    st, body = _req(
        "PATCH",
        f"/lobbies/{code}/",
        token=host_tok,
        body={"settings": {"roles": role_counts, **timers_cfg}},
    )
    if st != 200:
        _die(f"role config PATCH failed ({st}): {body}")

    # 5. Host starts with the forced assignment (DEBUG-only).
    forced = {
        "player_roles": {str(created[n]["user_id"]): roles[n] for n in players},
        "center": center,
    }
    st, body = _req(
        "POST",
        f"/onuw/lobbies/{code}/start/",
        token=host_tok,
        body={"debug": {"forced_assignment": forced}},
    )
    if st != 201:
        _die(f"game start failed ({st}): {body}")
    game_id = body["game_id"]

    session = {
        "game_id": game_id,
        "lobby_code": code,
        "host": host,
        "players": created,
        "spec": spec,
    }
    SESSION_DIR.mkdir(parents=True, exist_ok=True)
    _session_path(game_id).write_text(json.dumps(session, indent=2))

    _out(
        {
            "status": "ok",
            "game_id": game_id,
            "host": host,
            "players": {n: created[n]["user_id"] for n in players},
            "phase": body.get("phase"),
        }
    )


def cmd_me(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    st, body = _req(
        "GET", f"/onuw/games/{args.game}/me/", token=_token_for(s, args.player)
    )
    _out({"status": st, "me": body})


def cmd_act(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    targets = json.loads(args.targets) if args.targets else {}
    st, body = _req(
        "POST",
        f"/onuw/games/{args.game}/action/",
        token=_token_for(s, args.player),
        body={"action_type": args.action, "targets": targets},
    )
    _out({"status": st, "response": body})


def cmd_advance_wave(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    st, body = _req(
        "POST", f"/onuw/games/{args.game}/advance-wave/", token=_host_token(s)
    )
    _out({"status": st, "response": body})


def cmd_vote(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    st, body = _req(
        "POST",
        f"/onuw/games/{args.game}/vote/",
        token=_token_for(s, args.player),
        body={"target_player_id": args.target},
    )
    _out({"status": st, "response": body})


def cmd_end_discussion(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    st, body = _req(
        "POST", f"/onuw/games/{args.game}/end-discussion/", token=_host_token(s)
    )
    _out({"status": st, "response": body})


def cmd_reveal_votes(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    st, body = _req(
        "POST", f"/onuw/games/{args.game}/reveal-votes/", token=_host_token(s)
    )
    _out({"status": st, "response": body})


def cmd_results(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    st, body = _req("GET", f"/onuw/games/{args.game}/results/", token=_host_token(s))
    _out({"status": st, "results": body})


def cmd_oracle(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    st, body = _req(
        "GET", f"/onuw/games/{args.game}/debug-state/", token=_host_token(s)
    )
    _out({"status": st, "oracle": body})


def cmd_fire_timer(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    st, body = _req(
        "POST",
        f"/onuw/games/{args.game}/debug-fire-timer/",
        token=_host_token(s),
        body={"key": args.key},
    )
    _out({"status": st, "response": body})


def main() -> None:
    p = argparse.ArgumentParser(description="ONUW single-agent game driver")
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("setup")
    sp.add_argument("--spec", required=True)
    sp.set_defaults(fn=cmd_setup)
    sp = sub.add_parser("me")
    sp.add_argument("--game", required=True)
    sp.add_argument("--player", required=True)
    sp.set_defaults(fn=cmd_me)
    sp = sub.add_parser("act")
    sp.add_argument("--game", required=True)
    sp.add_argument("--player", required=True)
    sp.add_argument("--action", required=True)
    sp.add_argument("--targets", default="")
    sp.set_defaults(fn=cmd_act)
    sp = sub.add_parser("advance-wave")
    sp.add_argument("--game", required=True)
    sp.set_defaults(fn=cmd_advance_wave)
    sp = sub.add_parser("vote")
    sp.add_argument("--game", required=True)
    sp.add_argument("--player", required=True)
    sp.add_argument("--target", type=int, required=True)
    sp.set_defaults(fn=cmd_vote)
    sp = sub.add_parser("end-discussion")
    sp.add_argument("--game", required=True)
    sp.set_defaults(fn=cmd_end_discussion)
    sp = sub.add_parser("reveal-votes")
    sp.add_argument("--game", required=True)
    sp.set_defaults(fn=cmd_reveal_votes)
    sp = sub.add_parser("results")
    sp.add_argument("--game", required=True)
    sp.set_defaults(fn=cmd_results)
    sp = sub.add_parser("oracle")
    sp.add_argument("--game", required=True)
    sp.set_defaults(fn=cmd_oracle)
    sp = sub.add_parser("fire-timer")
    sp.add_argument("--game", required=True)
    sp.add_argument("--key", required=True)
    sp.set_defaults(fn=cmd_fire_timer)

    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
