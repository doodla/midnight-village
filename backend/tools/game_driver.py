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
host endpoints. Every stage-scoped request (choose, ready, vote and the host's
advance-wave / end-discussion / reveal-votes) names the `stage` the player's
`GET /me/` carries now, and a choose answers the prompt's `chosen`: the driver
reads `/me/` first, so an agent only says WHAT to pick. Picks are
`{"player_id": n}`, `{"center_index": n}` or `{"self": true}`, 0 to 2 of them;
every phone chooses once per window (an empty list is "nothing"), and what the
picks mean for the role is the server's business. Non-2xx responses are PRINTED, not raised: observing how the
server rejects a bad move (400 vs 500 vs leak) is the whole point.

Session: `setup` writes a session file mapping player name -> {user_id, token}
keyed by game_id, so later commands resolve a player by name. The first player
in the spec is the host (lobby creator) and holds the host-only endpoints.

Usage:
  python tools/game_driver.py setup --spec spec.json
  python tools/game_driver.py me --game <id> --player Alice
  python tools/game_driver.py ready --game <id> --player Alice           # look stage / talk
  python tools/game_driver.py choose --game <id> --player Alice --picks '[{"player_id": 12}]'
  python tools/game_driver.py advance-wave --game <id>          # close the open night window
  python tools/game_driver.py vote --game <id> --player Alice --target 13      # pick and lock
  python tools/game_driver.py vote --game <id> --player Alice --target 13 --pick  # pick only
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
    # The look stage (card_look_seconds) is off by default for the same reason:
    # the deal opens the first window at once. A spec may turn it on ("timers":
    # {"card_look_seconds": 30}); then every player taps `ready` first.
    timers_cfg = {
        "card_look_seconds": 0,
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
    st, body = _req(
        "POST",
        "/lobbies/",
        token=host_tok,
        body={"game_type": "onuw", "defaults": "v2"},
    )
    if st != 201:
        _die(f"lobby create failed ({st}): {body}")
    code = body["code"]

    # 3. Everyone else joins (the deal has no ready check).
    for name in players[1:]:
        st, body = _req("POST", f"/lobbies/{code}/join/", token=created[name]["token"])
        if st not in (200, 201):
            _die(f"{name} join failed ({st}): {body}")

    # 4. Host sets the role config + (driver-controlled) timers.
    st, body = _req(
        "PATCH",
        f"/lobbies/{code}/",
        token=host_tok,
        # A custom deck: the forced deal must match it (an automatic deck is
        # built at the deal).
        body={"settings": {"deck": "custom", "roles": role_counts, **timers_cfg}},
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


def _me(s: dict, game: str, player: str) -> dict:
    st, body = _req("GET", f"/onuw/games/{game}/me/", token=_token_for(s, player))
    if st != 200:
        _die(f"me for {player} failed ({st}): {body}")
    return body


def _staged(s: dict, game: str, player: str, tail: str, body: dict) -> None:
    """POST a stage-scoped request as ``player``, naming the stage their /me/
    shows now (a stage that is over answers 409 wrong_stage)."""
    me = _me(s, game, player)
    st, resp = _req(
        "POST",
        f"/onuw/games/{game}/{tail}/",
        token=_token_for(s, player),
        body={**body, "stage": me.get("stage")},
    )
    _out({"status": st, "response": resp})


def cmd_choose(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    picks = json.loads(args.picks) if args.picks else []
    prompt = _me(s, args.game, args.player).get("action_prompt") or {}
    _staged(
        s,
        args.game,
        args.player,
        "action",
        {"action_type": "choose", "picks": picks, "chosen": prompt.get("chosen", 0)},
    )


def cmd_ready(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    _staged(s, args.game, args.player, "ready", {"ready": not args.not_ready})


def cmd_advance_wave(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    _staged(s, args.game, s["host"], "advance-wave", {})


def cmd_vote(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    _staged(
        s,
        args.game,
        args.player,
        "vote",
        {"target_player_id": args.target, "lock": not args.pick},
    )


def cmd_end_discussion(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    _staged(s, args.game, s["host"], "end-discussion", {})


def cmd_reveal_votes(args: argparse.Namespace) -> None:
    s = _load_session(args.game)
    _staged(s, args.game, s["host"], "reveal-votes", {})


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
    sp = sub.add_parser("choose")
    sp.add_argument("--game", required=True)
    sp.add_argument("--player", required=True)
    sp.add_argument("--picks", default="")
    sp.set_defaults(fn=cmd_choose)
    sp = sub.add_parser("ready")
    sp.add_argument("--game", required=True)
    sp.add_argument("--player", required=True)
    sp.add_argument("--not", dest="not_ready", action="store_true")
    sp.set_defaults(fn=cmd_ready)
    sp = sub.add_parser("advance-wave")
    sp.add_argument("--game", required=True)
    sp.set_defaults(fn=cmd_advance_wave)
    sp = sub.add_parser("vote")
    sp.add_argument("--game", required=True)
    sp.add_argument("--player", required=True)
    sp.add_argument("--target", type=int, required=True)
    sp.add_argument("--pick", action="store_true", help="pick without locking")
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
