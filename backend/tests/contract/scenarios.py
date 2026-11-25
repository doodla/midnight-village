"""The games whose payloads become the contract samples.

Tables played through the real API (see recorder.py):

- ``classic_table``: six players, no Doppelganger (so the night is window 2
  only), no look stage, the default timers. Sign-in, lobby set-up and every
  lobby event, the night closed by the harness's timer hook, the talk, the vote
  with a Hunter chain, the results, play again and the owner leaving; "where am
  I" in every state, online stats, the night results ack, recent games. Most
  error bodies.
- ``doppelganger_table``: eight players, every timer 0 (as the harness plays),
  so deadlines are null. Window 1 (her look and follow-up), the host closing
  window 2, host handover and return, the host revealing votes with
  abstentions, the results with the night timeline, the debug oracle. Then a
  second game there (play again): she copies a Werewolf and a dealt Tanner dies.
  Calls from someone who does not play in the game.
- ``full_table``: ten players fill a table; the join refusals and the ack from
  someone who does not play in the game.
- ``choose_tables`` and ``results_tables``: tables made the way the app makes
  them (``defaults: "v2"``): the look stage, every prompt of the choose night,
  ready to vote, lock-in voting, the automatic deck; then every way a vote ends,
  three and ten seats, an untimed talk and vote.

Adding a situation: drive it here with ``table.record`` / ``table.record_event``,
run ``just samples`` and review the new files.
"""

from __future__ import annotations

from unittest.mock import patch

from rest_framework.throttling import SimpleRateThrottle
from rest_framework_simplejwt.tokens import AccessToken

from apps.core.models import Lobby

from .recorder import Recording, Table

LOBBY = "/lobbies/{code}/"
START = "/onuw/lobbies/{code}/start/"
CURRENT_GAME = "/onuw/me/current-game/"
ME = "/onuw/games/{game_id}/me/"
PLAYERS = "/onuw/games/{game_id}/players/"
ACTION = "/onuw/games/{game_id}/action/"
ADVANCE = "/onuw/games/{game_id}/advance-wave/"
END_DISCUSSION = "/onuw/games/{game_id}/end-discussion/"
VOTE = "/onuw/games/{game_id}/vote/"
REVEAL = "/onuw/games/{game_id}/reveal-votes/"
RESULTS = "/onuw/games/{game_id}/results/"
PLAY_AGAIN = "/lobbies/{code}/play-again/"
JOIN = "/lobbies/{code}/join/"
MY_TABLE = "/me/table/"
# A game id no game has (the account that is gone reads it before any check).
GONE_GAME_ID = "00000000-0000-4000-a000-000000000999"
RECENT_GAMES = "/onuw/me/recent-games/"
ONLINE = "/stats/online/"
RESULTS_SEEN = "/onuw/games/{game_id}/night-results/seen/"
UNKNOWN_GAME = "00000000-0000-4000-8000-000000000000"
DEBUG_STATE = "/onuw/games/{game_id}/debug-state/"
# Signed in at the Doppelganger table but not playing there.
OUTSIDER = "Zoe"
DEBUG_FIRE = "/onuw/games/{game_id}/debug-fire-timer/"

UNTIMED = {
    "night_wave_seconds": 0,
    "night_min_window_seconds": 0,
    "night_doppelganger_window_seconds": 0,
    "discussion_seconds": 0,
    "voting_seconds": 0,
    "host_handover_seconds": 30,
}


def _sign_in(table: Table, names: list[str]) -> None:
    for name in names:
        table.guest(name)


def _join(table: Table, names: list[str]) -> None:
    for name in names:
        table.clock.advance(60)
        table.call("POST", name, "/lobbies/{code}/join/")


def _vote(table: Table, who: str, target: str) -> None:
    table.call("POST", who, VOTE, {"target_player_id": table.pid(target), "lock": True})


def _record_my_table(t: Table, who: str, state: str, about: str) -> None:
    """``GET /me/table/`` ("where am I") as ``http/lobby/my_table_<state>``."""
    t.record(f"lobby/my_table_{state}", "GET", who, MY_TABLE, status=200, about=about)


def classic_table(run: Recording) -> None:
    t = run.table()
    deck = {
        "Werewolf": 2,
        "Seer": 1,
        "Robber": 1,
        "Troublemaker": 1,
        "Insomniac": 1,
        "Villager": 2,
        "Hunter": 1,
    }
    dealt = {
        "Ana": "Seer",
        "Ben": "Robber",
        "Cleo": "Werewolf",
        "Dev": "Troublemaker",
        "Esme": "Werewolf",
        "Fin": "Hunter",
    }

    # -- signing in ------------------------------------------------------
    t.guest("Ana", sample="auth/guest_created")
    _sign_in(t, ["Ben", "Cleo", "Dev", "Esme", "Fin"])
    t.record(
        "auth/guest_invalid_name",
        "POST",
        "",
        "/auth/guest/",
        {"display_name": "Ana!!"},
        status=400,
        about="A display name with characters the server refuses.",
    )
    refreshed = t.record(
        "auth/token_refreshed",
        "POST",
        "",
        "/auth/token/refresh/",
        {"refresh": t.players["Ana"].refresh_token},
        status=200,
        about="A refresh token is exchanged (and rotated).",
    )
    t.recorder.stable(refreshed["access"], "access-token-1-refreshed")
    t.recorder.stable(refreshed["refresh"], "refresh-token-1-refreshed")
    t.record(
        "auth/token_refresh_refused",
        "POST",
        "",
        "/auth/token/refresh/",
        {"refresh": "not-a-token"},
        status=401,
        about="A refresh token the server does not accept.",
    )

    t.record(
        "auth/token_expired",
        "GET",
        "Ana",
        CURRENT_GAME,
        status=401,
        about="An authenticated call with an access token that has expired.",
        bearer=t.expired_access_token("Ana"),
    )
    with (
        patch.object(SimpleRateThrottle, "allow_request", return_value=False),
        patch.object(SimpleRateThrottle, "wait", return_value=60.0),
    ):
        t.record(
            "auth/guest_throttled",
            "POST",
            "",
            "/auth/guest/",
            {"display_name": "Zed"},
            status=429,
            about="Too many sign-ins from this address (rate limited).",
        )
    _record_my_table(t, "Ana", "none", "Where am I: at no table.")
    t.record(
        "game/recent_games_none",
        "GET",
        "Ana",
        RECENT_GAMES,
        status=200,
        about="No finished games yet.",
    )

    # -- the lobby -------------------------------------------------------
    t.clock.advance(60)
    t.record(
        "lobby/created",
        "POST",
        "Ana",
        "/lobbies/",
        {"game_type": "onuw"},
        status=201,
        about="The host opens a table.",
    )
    t.clock.advance(60)
    t.record(
        "lobby/joined",
        "POST",
        "Ben",
        "/lobbies/{code}/join/",
        status=200,
        about="A player joins the table.",
    )
    t.record_event(
        "lobby/player_joined", "Ana", "lobby", "player_joined", about="Someone joined."
    )
    t.record(
        "lobby/join_already_member",
        "POST",
        "Ben",
        "/lobbies/{code}/join/",
        status=400,
        about="Joining a table you are already at.",
    )
    t.record(
        "lobby/join_not_found",
        "POST",
        "Ben",
        JOIN,
        status=404,
        about="Joining a table code that does not exist.",
        code="ZZZZZZ",
    )
    _record_my_table(t, "Ben", "waiting", "Where am I: at a table before the deal.")
    t.record(
        "lobby/not_found",
        "GET",
        "Ben",
        LOBBY,
        status=404,
        about="A table code that does not exist (or was closed).",
        code="ZZZZZZ",
    )
    for action, path in [
        ("leave", "/lobbies/{code}/leave/"),
        ("play_again", PLAY_AGAIN),
    ]:
        t.record(
            f"lobby/{action}_not_found",
            "POST",
            "Ben",
            path,
            status=404,
            about=f"{action.replace('_', ' ').capitalize()} at a table that is gone.",
            code="ZZZZZZ",
        )
    _join(t, ["Cleo", "Dev", "Esme", "Fin"])
    t.record(
        "lobby/settings_not_host",
        "PATCH",
        "Ben",
        LOBBY,
        {"settings": {"roles": deck}},
        status=403,
        about="Someone other than the host changes the deck.",
    )
    t.record(
        "lobby/settings_invalid",
        "PATCH",
        "Ana",
        LOBBY,
        {"settings": {"deck": "custom", "roles": {"Werewolf": 2, "Seer": 2}}},
        status=400,
        about="A deck with a role past its own limit (a short or long deck is "
        "stored and reported by `deal`; only each role's limits are refused).",
    )
    t.record(
        "lobby/settings_updated",
        "PATCH",
        "Ana",
        LOBBY,
        {"settings": {"roles": deck}},
        status=200,
        about="The host sets the deck.",
    )
    t.record_event(
        "lobby/lobby_update", "Ben", "lobby", "lobby_update", about="Deck changed."
    )
    t.record(
        "lobby/detail_waiting",
        "GET",
        "Ben",
        LOBBY,
        status=200,
        about="The table before the deal.",
    )
    t.record(
        "game/start_not_host",
        "POST",
        "Ben",
        START,
        status=403,
        about="Someone other than the host deals.",
    )
    t.record(
        "game/start_bad_seed",
        "POST",
        "Ana",
        START,
        {"debug": {"seed": "x"}},
        status=400,
        about="A deal refused for a reason no screen names (here the DEBUG-only "
        "seeded deal with a seed that is not a number).",
        debug=True,
    )

    # -- the deal and the night (window 2 only) --------------------------
    t.clock.advance(60)
    t.start(dealt, ["Villager", "Insomniac", "Villager"], sample="game/started")
    t.record_event(
        "lobby/game_started", "Ben", "lobby", "game_started", about="The deal."
    )
    t.record(
        "lobby/detail_in_game",
        "GET",
        "Ben",
        LOBBY,
        status=200,
        about="The table while its game runs.",
    )
    t.record(
        "game/start_not_waiting",
        "POST",
        "Ana",
        START,
        status=400,
        about="A second deal while the game runs (the table is not waiting).",
    )
    t.record(
        "game/current_game_active",
        "GET",
        "Ben",
        CURRENT_GAME,
        status=200,
        about="The player's running game.",
    )
    _record_my_table(t, "Ben", "night", "Where am I: in a game, at night.")
    t.record(
        "lobby/settings_in_game",
        "PATCH",
        "Ana",
        LOBBY,
        {"settings": {"roles": deck}},
        status=409,
        about="The host changes the deck while a game runs.",
    )
    for name in dealt:
        t.connect(name)
    t.record_event(
        "game/player_presence_connected",
        "Ana",
        "game",
        "player_presence",
        about="A phone joined the game.",
    )
    t.record(
        "core/online_stats",
        "GET",
        "",
        ONLINE,
        status=200,
        about="Players at tables right now (no login).",
    )
    t.disconnect("Esme")
    t.record_event(
        "game/player_presence_disconnected",
        "Ana",
        "game",
        "player_presence",
        about="A phone dropped.",
    )
    t.record(
        "game/players_night",
        "GET",
        "Ana",
        PLAYERS,
        status=200,
        about="Who is at the table and connected (one phone away).",
    )
    t.connect("Esme")
    t.record(
        "lobby/leave_owner_in_game",
        "POST",
        "Ana",
        "/lobbies/{code}/leave/",
        status=409,
        about="The owner leaves while the game runs.",
    )
    t.record(
        "game/advance_wave_not_host",
        "POST",
        "Ben",
        ADVANCE,
        status=403,
        about="Someone other than the host closes the window.",
    )
    _choose(t, "Ana", [_player(t, "Cleo")])
    t.record(
        "debug/state_night",
        "GET",
        "Ana",
        DEBUG_STATE,
        status=200,
        about="The DEBUG-only oracle at night, a window open and its timer armed.",
        debug=True,
    )
    _choose(t, "Ben", [_player(t, "Dev")])
    _choose(t, "Dev", [_player(t, "Ana"), _player(t, "Ben")])
    _rest_choose(t, ["Cleo", "Esme", "Fin"])
    # Every phone with a choice has chosen; the window would close at its minimum
    # length. The harness's hook closes it now instead.
    t.clock.advance(8)
    t.record(
        "debug/fire_timer",
        "POST",
        "Ana",
        DEBUG_FIRE,
        {"key": "wave:2"},
        status=200,
        about="The DEBUG-only timer hook fires a pending timer (window 2 closes).",
        debug=True,
    )
    t.record_event(
        "game/phase_change_discussion",
        "Ana",
        "game",
        "phase_change",
        about="The night ends; the talk starts (timed).",
    )

    # -- the talk ---------------------------------------------------------
    _record_my_table(t, "Ben", "discussion", "Where am I: in a game, in the talk.")
    t.record(
        "game/players_discussion",
        "GET",
        "Ana",
        PLAYERS,
        status=200,
        about="The player list in the talk.",
    )
    t.record(
        "game/night_results_seen",
        "POST",
        "Ana",
        RESULTS_SEEN,
        {"seen": 1},
        status=200,
        about="The phone showed the night's results (acknowledged).",
    )
    t.record(
        "game/night_results_seen_invalid",
        "POST",
        "Ana",
        RESULTS_SEEN,
        {"seen": -1},
        status=400,
        about="An acknowledgement that is not a count from 0 to 10.",
    )
    t.record(
        "game/night_results_seen_not_found",
        "POST",
        "Ana",
        RESULTS_SEEN,
        {"seen": 1},
        status=404,
        about="Acknowledging results of a game that does not exist.",
        game_id=UNKNOWN_GAME,
    )
    t.record(
        "game/end_discussion_not_host",
        "POST",
        "Ben",
        END_DISCUSSION,
        status=403,
        about="Someone other than the host ends the talk.",
    )
    t.clock.advance(120)
    t.record(
        "game/end_discussion",
        "POST",
        "Ana",
        END_DISCUSSION,
        status=200,
        about="The host ends the talk.",
    )
    t.record_event(
        "game/phase_change_voting",
        "Ana",
        "game",
        "phase_change",
        about="The vote starts (timed).",
    )

    # -- the vote ---------------------------------------------------------
    _record_my_table(t, "Ben", "voting", "Where am I: in a game, in the vote.")
    t.record(
        "lobby/play_again_not_finished",
        "POST",
        "Ana",
        PLAY_AGAIN,
        status=409,
        about="Play again while the game is still running.",
    )
    t.record(
        "game/results_not_ready",
        "GET",
        "Ana",
        RESULTS,
        status=403,
        about="Results asked for before the game ends.",
    )
    _vote(t, "Ana", "Fin")
    t.record(
        "game/players_voting",
        "GET",
        "Ben",
        PLAYERS,
        status=200,
        about="The player list during the vote.",
    )
    t.record(
        "game/vote_invalid_target",
        "POST",
        "Ben",
        VOTE,
        {"target_player_id": t.pid("Ben"), "lock": True},
        status=400,
        about="A vote the server refuses (here: for yourself).",
    )
    t.record(
        "game/reveal_votes_not_host",
        "POST",
        "Ben",
        REVEAL,
        status=403,
        about="Someone other than the host reveals the votes.",
    )
    for voter, target in [
        ("Ben", "Fin"),
        ("Cleo", "Fin"),
        ("Dev", "Cleo"),
        ("Esme", "Fin"),
        ("Fin", "Esme"),
    ]:
        _vote(t, voter, target)
    t.record_event(
        "game/vote_reveal", "Ana", "game", "vote_reveal", about="Everyone voted."
    )
    t.record_event(
        "game/game_results",
        "Ana",
        "game",
        "game_results",
        about="The game is over (Hunter chain).",
    )

    # -- results and after ------------------------------------------------
    t.record(
        "game/results",
        "GET",
        "Ana",
        RESULTS,
        status=200,
        about="The full results: a Hunter dies and takes a Werewolf.",
    )
    t.record(
        "game/current_game_none",
        "GET",
        "Ana",
        CURRENT_GAME,
        status=200,
        about="No running game (a finished one does not count).",
    )
    _record_my_table(t, "Ben", "results", "Where am I: the game is over.")
    t.record(
        "game/players_results",
        "GET",
        "Ana",
        PLAYERS,
        status=200,
        about="The player list once the game is over.",
    )
    t.record(
        "game/recent_games",
        "GET",
        "Ana",
        RECENT_GAMES,
        status=200,
        about="The player's finished games, newest first.",
    )
    t.record(
        "game/me_not_found",
        "GET",
        "Ana",
        ME,
        status=404,
        about="A game that does not exist.",
        game_id=UNKNOWN_GAME,
    )
    t.record(
        "lobby/play_again_not_host",
        "POST",
        "Ben",
        PLAY_AGAIN,
        status=403,
        about="Someone other than the host starts another game.",
    )
    t.record(
        "lobby/play_again",
        "POST",
        "Ana",
        PLAY_AGAIN,
        status=200,
        about="The host takes the table back to the lobby.",
    )
    t.record_event(
        "game/play_again", "Ben", "game", "play_again", about="Back to the lobby."
    )
    _record_my_table(
        t,
        "Ben",
        "after_play_again",
        "Where am I: back at the table; the last game is still the results.",
    )
    t.record(
        "lobby/left",
        "POST",
        "Fin",
        "/lobbies/{code}/leave/",
        status=200,
        about="A player leaves the table.",
    )
    t.record_event(
        "lobby/player_left", "Ben", "lobby", "player_left", about="Someone left."
    )
    t.record(
        "lobby/leave_not_member",
        "POST",
        "Fin",
        "/lobbies/{code}/leave/",
        status=400,
        about="A leave that reaches a table this player already left (a second "
        "tap, or a retry after a slow answer): the app counts it as left.",
    )
    t.record(
        "lobby/left_owner",
        "POST",
        "Ana",
        "/lobbies/{code}/leave/",
        status=200,
        about="The owner leaves with others still there: the table passes on.",
    )
    t.record_event(
        "lobby/host_changed_transferred",
        "Ben",
        "lobby",
        "host_changed",
        about="The owner left between games; the table is someone else's now.",
    )
    for name in ["Cleo", "Dev", "Esme"]:
        t.call("POST", name, "/lobbies/{code}/leave/")
    t.record(
        "lobby/left_last_member",
        "POST",
        "Ben",
        "/lobbies/{code}/leave/",
        status=200,
        about="The last member leaves: the table is closed.",
    )


def doppelganger_table(run: Recording) -> Table:
    t = run.table()
    deck = {
        "Doppelganger": 1,
        "Seer": 1,
        "Werewolf": 2,
        "Minion": 1,
        "Mason": 2,
        "Drunk": 1,
        "Insomniac": 1,
        "Villager": 1,
        "Tanner": 1,
    }
    dealt = {
        "Ana": "Doppelganger",
        "Ben": "Seer",
        "Cleo": "Werewolf",
        "Dev": "Minion",
        "Esme": "Mason",
        "Fin": "Mason",
        "Gus": "Drunk",
        "Hana": "Insomniac",
    }
    _sign_in(t, [*dealt, OUTSIDER])
    t.clock.advance(60)
    t.call("POST", "Ana", "/lobbies/", {"game_type": "onuw"})
    _join(t, list(dealt)[1:])
    t.call("PATCH", "Ana", LOBBY, {"settings": {"roles": deck, **UNTIMED}})
    t.clock.advance(60)
    t.start(dealt, ["Werewolf", "Villager", "Tanner"])
    for name in dealt:
        t.connect(name)

    # -- window 1: the Doppelganger looks, then acts as the copied Seer ----
    t.record(
        "game/choose_not_a_player",
        "POST",
        OUTSIDER,
        ACTION,
        {"action_type": "choose", "picks": []},
        status=403,
        about="A choose from someone who does not play in the game.",
    )
    # Her follow-up is the last choice of window 1 (untimed here): it closes,
    # and nobody else had anything to choose in it.
    _choose(t, "Ana", [_player(t, "Ben")])
    _choose(t, "Ana", [{"center_index": 0}, {"center_index": 2}])

    # -- window 2: everyone else ------------------------------------------
    _choose(t, "Cleo", [{"center_index": 1}])
    _choose(t, "Gus", [{"center_index": 0}])
    # Ben (the Seer) has not tapped: the host closes the window; he skips, and
    # the automatic looks (the Minion, the Masons, the Insomniac) still happen.
    t.record(
        "game/advance_wave",
        "POST",
        "Ana",
        ADVANCE,
        status=200,
        about="The host closes the night window now.",
    )
    t.record_event(
        "game/phase_change_discussion_untimed",
        "Ben",
        "game",
        "phase_change",
        about="The talk starts, with no deadline.",
    )

    # -- host handover while the owner's phone is away ---------------------
    lobby = Lobby.objects.get(code=t.code)
    t.disconnect("Ana")
    t.clock.advance(30)
    t.fire(f"lobby:{lobby.pk}:host")
    t.record_event(
        "game/host_changed_handover",
        "Ben",
        "game",
        "host_changed",
        about="The owner's phone is away; someone else hosts.",
    )
    t.record_event(
        "lobby/host_changed_handover",
        "Ben",
        "lobby",
        "host_changed",
        about="The same, on the lobby socket.",
    )
    t.record(
        "lobby/detail_acting_host",
        "GET",
        "Ben",
        LOBBY,
        status=200,
        about="The table while someone stands in for the owner.",
    )
    t.record(
        "game/me_discussion_acting_host",
        "GET",
        "Ben",
        ME,
        status=200,
        about="/me/ for the player standing in as host.",
    )
    t.record(
        "game/end_discussion_not_a_player",
        "POST",
        OUTSIDER,
        END_DISCUSSION,
        status=403,
        about="Someone who does not play in the game ends the talk.",
    )
    t.connect("Ana")
    t.record_event(
        "game/host_changed_returned",
        "Ben",
        "game",
        "host_changed",
        about="The owner is back and hosts again.",
    )

    # -- an untimed vote the host reveals ---------------------------------
    t.call("POST", "Ana", END_DISCUSSION)
    t.record_event(
        "game/phase_change_voting_untimed",
        "Ben",
        "game",
        "phase_change",
        about="The vote starts, with no deadline.",
    )
    t.record(
        "game/vote_not_a_player",
        "POST",
        OUTSIDER,
        VOTE,
        {"target_player_id": t.pid("Cleo"), "lock": True},
        status=403,
        about="A vote from someone who does not play in the game.",
    )
    _vote(t, "Ana", "Cleo")
    _vote(t, "Ben", "Cleo")
    t.record(
        "game/reveal_votes",
        "POST",
        "Ana",
        REVEAL,
        status=200,
        about="The host reveals the votes; who has not voted abstains.",
    )
    t.record_event(
        "game/vote_reveal_with_abstentions",
        "Ben",
        "game",
        "vote_reveal",
        about="Votes revealed; null = did not vote.",
    )
    t.record(
        "game/results_doppelganger",
        "GET",
        "Ana",
        RESULTS,
        status=200,
        about="Results of a game with a Doppelganger, a Drunk and a Tanner.",
    )
    t.record(
        "game/results_not_a_player",
        "GET",
        OUTSIDER,
        RESULTS,
        status=403,
        about="Results asked for by someone who did not play.",
    )
    t.record(
        "game/me_not_a_player",
        "GET",
        OUTSIDER,
        ME,
        status=403,
        about="/me/ asked for by someone who does not play in the game.",
    )
    t.record(
        "debug/state",
        "GET",
        "Ana",
        DEBUG_STATE,
        status=200,
        about="The DEBUG-only oracle (dev toolbar and harness).",
        debug=True,
    )
    t.record(
        "debug/fire_timer_none",
        "POST",
        "Ana",
        DEBUG_FIRE,
        {"key": "wave:2"},
        status=200,
        about="The DEBUG-only timer hook when no such timer is pending.",
        debug=True,
    )
    _doppelganger_copies(t)
    return t


def _close_the_night(t: Table) -> None:
    """Untimed: the host closes every window still open."""
    while t.request("GET", "Ana", ME)[1]["phase"] == "night":
        t.call("POST", "Ana", ADVANCE)


def _deal_again(t: Table, dealt: dict[str, str], center: list[str]) -> None:
    t.call("POST", "Ana", PLAY_AGAIN)
    t.clock.advance(60)
    t.start(dealt, center)


def _doppelganger_copies(t: Table) -> None:
    """Another game at the Doppelganger table (play again): she copies a Werewolf
    (and wakes with them in window 2); Dev is dealt the Tanner and the table votes
    him out."""
    usual = {
        "Ana": "Doppelganger",
        "Ben": "Seer",
        "Cleo": "Werewolf",
        "Dev": "Tanner",
        "Esme": "Mason",
        "Fin": "Mason",
        "Gus": "Drunk",
        "Hana": "Insomniac",
    }
    _deal_again(t, usual, ["Werewolf", "Villager", "Minion"])
    _choose(t, "Ana", [_player(t, "Cleo")])
    _close_the_night(t)
    t.call("POST", "Ana", END_DISCUSSION)
    for name in usual:
        _vote(t, name, "Cleo" if name == "Dev" else "Dev")
    t.record_event(
        "game/game_results_tanner",
        "Ben",
        "game",
        "game_results",
        about="The dealt Tanner is voted out and wins.",
    )
    t.record(
        "game/results_tanner",
        "GET",
        "Ana",
        RESULTS,
        status=200,
        about="Results where the dealt Tanner died (team neutral).",
    )


def full_table(run: Recording, finished: Table) -> None:
    """Ten players fill a table; an eleventh is refused here, at a finished
    table, and by a game she does not play in."""
    t = run.table()
    names = ["Ida", "Jon", "Kit", "Lev", "Mia", "Ned", "Ola", "Pim", "Quin", "Rae"]
    _sign_in(t, [*names, "Sol"])
    t.call("POST", "Ida", "/lobbies/", {"game_type": "onuw"})
    for name in names[1:]:
        t.call("POST", name, JOIN)
    t.record(
        "lobby/join_full",
        "POST",
        "Sol",
        JOIN,
        status=400,
        about="Joining a table with every seat taken.",
    )
    t.record(
        "lobby/join_closed",
        "POST",
        "Sol",
        JOIN,
        status=400,
        about="Joining a table that is not taking players (its game is over).",
        code=finished.code,
    )
    t.record(
        "game/night_results_seen_not_a_player",
        "POST",
        "Sol",
        RESULTS_SEEN,
        {"seen": 1},
        status=403,
        about="Acknowledging results of a game you do not play in.",
        game_id=finished.game_id,
    )


GAME_READY = "/onuw/games/{game_id}/ready/"
CREATE = "/lobbies/"


def _app_lobby(t: Table, names: list[str], *, sample: str | None = None) -> None:
    """A table the way the app makes it: ``defaults: "v2"`` (the card look and
    the automatic Simple deck)."""
    _sign_in(t, names)
    body = {"game_type": "onuw", "defaults": "v2"}
    if sample:
        t.clock.advance(60)
        t.record(
            sample,
            "POST",
            names[0],
            CREATE,
            body,
            status=201,
            about="The host opens a table with the defaults of the new screens.",
        )
    else:
        t.call("POST", names[0], CREATE, body)
    _join(t, names[1:])


def _everyone(t: Table, names: list[str], path: str, body: dict) -> None:
    for name in names:
        t.call("POST", name, path, body)


def _choose(t: Table, who: str, picks: list[dict]) -> None:
    t.call("POST", who, ACTION, {"action_type": "choose", "picks": picks})


def _turn_open(t: Table, who: str) -> bool:
    """``who``'s phone still has a choose to send (its prompt's ``chooses_left``).
    A phone with nothing to choose sends nothing, as the app's does."""
    prompt = t.request("GET", who, ME)[1].get("action_prompt")
    return bool(prompt) and prompt["chooses_left"] > 0


def _rest_choose(t: Table, names: list[str]) -> None:
    """Each of ``names`` whose turn is still open chooses nothing; the others (a
    phone with nothing to choose) send nothing."""
    for name in names:
        if _turn_open(t, name):
            _choose(t, name, [])


def _player(t: Table, name: str) -> dict:
    return {"player_id": t.pid(name)}


def choose_tables(run: Recording) -> None:
    """The look stage, the choose night (a plain table, then a Doppelganger
    table with window 1), lock-in voting, ready to vote, the automatic deck and
    the create defaults."""
    _plain_choose_table(run)
    _doppelganger_choose_table(run)
    _auto_deck_table(run, ["Ana", "Ben", "Cleo", "Dev", "Esme"], "classic", 5)
    _auto_deck_table(
        run,
        ["Ana", "Ben", "Cleo", "Dev", "Esme", "Fin", "Gus", "Hana", "Ida"],
        "chaos",
        9,
    )


def _plain_choose_table(run: Recording) -> None:
    """Five players, a lone Werewolf: look stage, window 2 (all five phones choose (the
    Villager's choose is recorded too, taken alike)
    once), the talk (ready to vote) and the lock-in vote."""
    t = run.table()
    names = ["Ana", "Ben", "Cleo", "Dev", "Esme"]
    dealt = {
        "Ana": "Seer",
        "Ben": "Robber",
        "Cleo": "Werewolf",
        "Dev": "Troublemaker",
        "Esme": "Villager",
    }
    _sign_in(t, names)
    t.record(
        "lobby/create_unknown_defaults",
        "POST",
        "Ana",
        CREATE,
        {"game_type": "onuw", "defaults": "v9"},
        status=400,
        about="A create that asks for a set of defaults the game does not have.",
    )
    t.clock.advance(60)
    t.record(
        "lobby/created_with_defaults",
        "POST",
        "Ana",
        CREATE,
        {"game_type": "onuw", "defaults": "v2"},
        status=201,
        about=(
            "The host opens a table with `defaults: v2`: a 30 s look at the cards "
            "and the automatic Simple deck, and nothing else (no timer length is "
            "written)."
        ),
    )
    _join(t, names[1:])
    t.record(
        "lobby/settings_deck_chip_invalid",
        "PATCH",
        "Ana",
        LOBBY,
        {"settings": {"deck_chip": "wild"}},
        status=400,
        about="A deck chip the server does not have.",
    )
    t.record(
        "lobby/settings_deck_chip",
        "PATCH",
        "Ana",
        LOBBY,
        {"settings": {"deck": "auto", "deck_chip": "simple"}},
        status=200,
        about="The host picks a deck chip; the server builds the deck at the deal.",
    )

    # -- the deal and the look stage -------------------------------------
    t.clock.advance(60)
    t.start(
        dealt, ["Werewolf", "Villager", "Villager"], sample="game/started_with_look"
    )
    for name in names:
        t.connect(name)
    since_deal = t.mark()
    t.record_event(
        "game/progress_look_open",
        "Ana",
        "game",
        "progress",
        about="The look stage opens: how many have looked, out of how many.",
    )
    t.record(
        "game/me_look_stage",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the look stage: night, window 0, the look deadline.",
    )
    t.record(
        "game/ready_look_false_refused",
        "POST",
        "Ana",
        GAME_READY,
        {"ready": False},
        status=400,
        about="Looking at your card cannot be undone.",
    )
    t.record(
        "game/ready_bad_body",
        "POST",
        "Ana",
        GAME_READY,
        {"ready": "yes"},
        status=400,
        about="A ready flag that is not true or false.",
    )
    t.record(
        "game/ready_look",
        "POST",
        "Ana",
        GAME_READY,
        {"ready": True},
        status=200,
        about="A player has looked at their card.",
    )
    t.record_event(
        "game/progress_look",
        "Ben",
        "game",
        "progress",
        about="Counts only: how many have looked, never who.",
    )
    t.record(
        "game/me_look_ready",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the look stage after tapping ready.",
    )
    t.record(
        "game/pack_look_robber",
        "GET",
        "Ben",
        ME,
        status=200,
        about="The playtest pack's guest (game 7): Ben's /me/ in the look stage, "
        "before he has looked (Ana has).",
    )
    _everyone(t, names[1:4], GAME_READY, {"ready": True})
    t.record(
        "game/pack_look_villager",
        "GET",
        "Esme",
        ME,
        status=200,
        about="The playtest pack's sleeper (game 7): Esme's /me/ in the look "
        "stage, the last to look.",
    )
    since_night = t.mark()
    t.call("POST", "Esme", GAME_READY, {"ready": True})
    t.record_sequence(
        "look_stage",
        since_deal,
        about="What every seat's socket heard from the deal until the last look.",
    )

    # -- window 2: every phone with a choice chooses once ----------------
    t.record_event(
        "game/night_window_2",
        "Ana",
        "game",
        "night_window",
        about="A night window opened: the same event for every phone.",
    )
    t.record(
        "game/ready_wrong_stage",
        "POST",
        "Ana",
        GAME_READY,
        {"ready": True},
        status=409,
        about="Ready while a night window is open: the request names the window's "
        "stage, which does not take ready.",
    )
    for name, kind in [
        ("Ana", "seer"),
        ("Ben", "robber"),
        ("Dev", "troublemaker"),
        ("Esme", "villager"),
        ("Cleo", "werewolf_lone"),
    ]:
        t.record(
            f"game/me_choose_prompt_{kind}",
            "GET",
            name,
            ME,
            status=200,
            about=f"/me/ in window 2, the {kind.replace('_', ' ')}'s prompt.",
        )
    t.record(
        "game/choose_submitted_seer",
        "POST",
        "Ana",
        ACTION,
        {"action_type": "choose", "picks": [_player(t, "Cleo")]},
        status=200,
        about="The Seer's choose: her look is settled the moment she chooses, so "
        "the answer carries it (`night_results`, as /me/ lists it now) and "
        "`chooses_left` 0.",
    )
    t.record(
        "game/choose_submitted_villager",
        "POST",
        "Esme",
        ACTION,
        {"action_type": "choose", "picks": [{"self": True}]},
        status=200,
        about="A player with nothing to choose: the same keys, nothing learned.",
    )
    t.record(
        "game/choose_resent",
        "POST",
        "Ana",
        ACTION,
        {"action_type": "choose", "picks": [_player(t, "Cleo")], "chosen": 0},
        status=200,
        about="The same choose sent again (its answer was lost): it names the prompt "
        "it answered (`chosen` 0), the server has already taken that one, so the "
        "answer is the original's and nothing is stored.",
    )
    t.record(
        "game/choose_already_chosen",
        "POST",
        "Ana",
        ACTION,
        {"action_type": "choose", "picks": []},
        status=409,
        about="A choose answering a prompt that is used up (`chosen` 1 of "
        "`max_chooses` 1 in window 2).",
    )
    t.record(
        "game/choose_chosen_missing",
        "POST",
        "Ben",
        ACTION,
        {"action_type": "choose", "picks": [], "chosen": None},
        status=400,
        about="A choose that does not say which prompt it answers (`chosen`).",
    )
    t.record(
        "game/choose_bad_request",
        "POST",
        "Ben",
        ACTION,
        {"action_type": "choose", "picks": "x"},
        status=400,
        about="Picks that are not a list of at most two cards.",
    )
    t.record(
        "game/choose_not_a_choose",
        "POST",
        "Ben",
        ACTION,
        {"action_type": "skip", "targets": {}},
        status=400,
        about="Any other action_type (only `choose` is a night action).",
    )
    t.record(
        "game/me_choose_chosen",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ after choosing: the prompt says how many chooses were sent, "
        "and the Seer's look is listed while the window is still open.",
    )
    t.record(
        "game/choose_submitted_robber",
        "POST",
        "Ben",
        ACTION,
        {"action_type": "choose", "picks": [_player(t, "Ana")]},
        status=200,
        about="The Robber's choose: the card she takes is settled at once (only "
        "the Seer, who moves nothing, resolves before her).",
    )
    t.record(
        "game/choose_submitted_troublemaker",
        "POST",
        "Dev",
        ACTION,
        {"action_type": "choose", "picks": [_player(t, "Ana"), _player(t, "Ben")]},
        status=200,
        about="The Troublemaker's choose: her swap names only her own picks, so it "
        "is settled at once.",
    )
    _choose(t, "Cleo", [{"center_index": 0}])
    window_stage = t.stage_now()
    t.fire("{game_id}:wave:2")  # every phone with a choice has: the minimum's close
    t.record_sequence(
        "window_2",
        since_night,
        about="What every seat's socket heard while window 2 was open.",
    )
    t.record(
        "game/choose_wrong_stage",
        "POST",
        "Ana",
        ACTION,
        {"action_type": "choose", "picks": [], "stage": window_stage},
        status=409,
        about="A late choose for a window that is over: the same answer for every "
        "role, nothing stored, and it can never land in the next stage.",
    )
    t.record(
        "game/advance_wave_wrong_stage",
        "POST",
        "Ana",
        ADVANCE,
        {"stage": window_stage},
        status=409,
        about="The host's advance for a window that is over: nothing happens to "
        "the stage the game is in now.",
    )
    t.record(
        "game/choose_stage_missing",
        "POST",
        "Ana",
        ACTION,
        {"action_type": "choose", "picks": [], "stage": None},
        status=400,
        about="A choose that does not name its stage.",
    )
    for name, kind in [
        ("Ana", "seer"),
        ("Ben", "robber"),
        ("Cleo", "werewolf_lone"),
        ("Dev", "troublemaker"),
        ("Esme", "villager"),
    ]:
        t.record(
            f"game/me_discussion_choose_{kind}",
            "GET",
            name,
            ME,
            status=200,
            about=f"/me/ in the talk: the {kind.replace('_', ' ')}'s night results.",
        )

    # -- the talk: ready to vote -----------------------------------------
    t.record_event(
        "game/progress_talk_open",
        "Ana",
        "game",
        "progress",
        about="The talk opens: nobody is ready to vote yet.",
    )
    t.record(
        "game/ready_talk",
        "POST",
        "Ana",
        GAME_READY,
        {"ready": True},
        status=200,
        about="A player is ready to vote.",
    )
    t.record(
        "game/ready_talk_off",
        "POST",
        "Ben",
        GAME_READY,
        {"ready": False},
        status=200,
        about="In the talk a player may take their ready back.",
    )
    t.record_event(
        "game/progress_talk",
        "Ben",
        "game",
        "progress",
        about="Counts only, in the talk.",
    )
    t.record(
        "game/me_talk_ready",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the talk after tapping ready.",
    )
    talk_stage = t.stage_now()
    since_vote = t.mark()
    _everyone(t, names[1:], GAME_READY, {"ready": True})
    t.record_event(
        "game/progress_vote_open",
        "Ana",
        "game",
        "progress",
        about="Everyone present was ready: the vote opens, nobody has locked in.",
    )
    t.record(
        "game/me_voting_unpicked",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the vote before the caller has picked anyone (`my_vote` "
        "is null).",
    )
    for name, kind in [("Ben", "robber"), ("Esme", "villager")]:
        t.record(
            f"game/pack_vote_{kind}",
            "GET",
            name,
            ME,
            status=200,
            about=f"The playtest pack (game 7): {name}'s /me/ as the vote opens.",
        )
    t.record(
        "game/end_discussion_wrong_stage",
        "POST",
        "Ana",
        END_DISCUSSION,
        {"stage": talk_stage},
        status=409,
        about="The host's end-discussion after the talk already ended (everyone "
        "was ready): nothing happens to the vote.",
    )

    # -- the vote: pick, re-pick, lock -----------------------------------
    t.record(
        "game/vote_picked",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Dev"), "lock": False},
        status=200,
        about="A pick: nothing is sent to anyone else; the answer echoes the pick.",
    )
    # Ana is the Seer who saw Cleo's card: she settles on Cleo (the playtest
    # pack's host journey, so its vote follows its night).
    t.record(
        "game/vote_repicked",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Cleo"), "lock": False},
        status=200,
        about="A pick can change until it is locked.",
    )
    t.record(
        "game/me_voting_picked",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ with a pick that is not locked yet (`my_vote`, own only).",
    )
    t.record(
        "game/vote_bad_target_type",
        "POST",
        "Ben",
        VOTE,
        {"target_player_id": "Cleo"},
        status=400,
        about="A target that is not a JSON integer.",
    )
    t.record(
        "game/vote_self",
        "POST",
        "Ben",
        VOTE,
        {"target_player_id": t.pid("Ben"), "lock": False},
        status=400,
        about="A vote for yourself, with its code.",
    )
    t.record(
        "game/vote_lock_bad_flag",
        "POST",
        "Ben",
        VOTE,
        {"target_player_id": t.pid("Cleo"), "lock": "yes"},
        status=400,
        about="A lock flag that is not true or false.",
    )
    t.record(
        "game/vote_locked",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Cleo"), "lock": True},
        status=200,
        about="Locking in: final.",
    )
    t.record_event(
        "game/progress_vote",
        "Ben",
        "game",
        "progress",
        about="Counts only, in the vote.",
    )
    t.record(
        "game/vote_lock_resent",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Cleo"), "lock": True},
        status=200,
        about="The same lock sent again (its answer was lost): the original's answer, "
        "nothing stored or sent.",
    )
    t.record(
        "game/vote_already_locked",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Dev"), "lock": False},
        status=409,
        about="A pick or lock after locking in.",
    )
    t.record(
        "game/me_voting_locked",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ after locking in.",
    )
    t.record(
        "debug/state_talk_vote",
        "GET",
        "Ana",
        DEBUG_STATE,
        status=200,
        about="The oracle with per-player ready and vote_locked.",
        debug=True,
    )
    vote_stage = t.stage_now()
    for name in names[1:]:
        target = "Dev" if name == "Cleo" else "Cleo"
        _vote(t, name, target)
    t.record_sequence(
        "talk_and_vote",
        since_vote,
        about="What every seat's socket heard from the vote opening to the results.",
    )
    t.record(
        "game/vote_after_reveal",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Cleo"), "lock": True, "stage": vote_stage},
        status=409,
        about="A vote that was on its way when the vote was revealed: the stage is "
        "over, nothing is stored.",
    )
    t.record(
        "game/reveal_votes_wrong_stage",
        "POST",
        "Ana",
        REVEAL,
        {"stage": vote_stage},
        status=409,
        about="The host's reveal after the last lock already revealed the vote.",
    )
    t.record(
        "game/me_results",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the results phase.",
    )
    t.record(
        "game/results_five",
        "GET",
        "Ana",
        RESULTS,
        status=200,
        about="The results of the five-player game the playtest pack plays (game 7), "
        "so one journey runs from the deal to the results on recorded payloads.",
    )


def _doppelganger_choose_table(run: Recording) -> None:
    """Nine players with a Doppelganger and a Werewolf pack: window 1 takes a choose
    from every phone, and a second from the Doppelganger (her follow-up as the
    copied Seer); window 2 one."""
    t = run.table()
    names = ["Ana", "Ben", "Cleo", "Dev", "Esme", "Fin", "Gus", "Hana", "Ida"]
    dealt = {
        "Ana": "Doppelganger",
        "Ben": "Seer",
        "Cleo": "Werewolf",
        "Dev": "Minion",
        "Esme": "Mason",
        "Fin": "Mason",
        "Gus": "Drunk",
        "Hana": "Insomniac",
        "Ida": "Werewolf",
    }
    _app_lobby(t, names)
    deck: dict[str, int] = {}
    for role in [*dealt.values(), "Villager", "Villager", "Tanner"]:
        deck[role] = deck.get(role, 0) + 1
    t.call(
        "PATCH",
        "Ana",
        LOBBY,
        {"settings": {"deck": "custom", "roles": deck}},
    )
    t.record_event(
        "lobby/lobby_update_custom_deck",
        "Ben",
        "lobby",
        "lobby_update",
        about="A table whose host picked the cards (`deck: custom`).",
    )
    t.record(
        "lobby/detail_custom_deck",
        "GET",
        "Ben",
        LOBBY,
        status=200,
        about="A table with a custom deck, before the deal.",
    )
    t.clock.advance(60)
    t.start(dealt, ["Villager", "Villager", "Tanner"])
    for name in names:
        t.connect(name)
    _everyone(t, names[:-1], GAME_READY, {"ready": True})

    # -- window 1 ---------------------------------------------------------
    since_w1 = t.mark()  # the last look opens the night
    t.call("POST", names[-1], GAME_READY, {"ready": True})
    t.record_event(
        "game/night_window_1",
        "Ana",
        "game",
        "night_window",
        about="Window 1 (the Doppelganger's) opens: the same event for everyone.",
    )
    t.record(
        "game/me_choose_prompt_doppelganger_look",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in window 1: the Doppelganger's look prompt.",
    )
    t.record(
        "game/me_choose_prompt_window1_sleeper",
        "GET",
        "Cleo",
        ME,
        status=200,
        about="/me/ in window 1 for everyone else: nothing to choose, same shape.",
    )
    t.record(
        "game/choose_submitted_doppelganger_look",
        "POST",
        "Ana",
        ACTION,
        {"action_type": "choose", "picks": [_player(t, "Ben")]},
        status=200,
        about="Her first choose is the look; the answer is the same as anyone's.",
    )
    t.record(
        "game/choose_resent_doppelganger_look",
        "POST",
        "Ana",
        ACTION,
        {"action_type": "choose", "picks": [_player(t, "Ben")], "chosen": 0},
        status=200,
        about="Her look sent again (its answer was lost): taken already, so it is "
        "not read as her follow-up; the same answer as anyone's.",
    )
    t.record(
        "game/me_choose_doppelganger_followup",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in window 1 after her look: it is listed at once, and her "
        "follow-up prompt (as the copied Seer) is open.",
    )
    _choose(t, "Ana", [{"center_index": 0}, {"center_index": 1}])
    # The others have nothing to choose in window 1 and send nothing; a choose
    # from one of them is still taken, a second too.
    _choose(t, "Ben", [])
    t.record(
        "game/choose_submitted_window1_second",
        "POST",
        "Ben",
        ACTION,
        {"action_type": "choose", "picks": [{"self": True}]},
        status=200,
        about="The server accepts a second choose in window 1 from anyone (only "
        "the Doppelganger's is read): the same answer as hers.",
    )
    t.record(
        "game/choose_window1_third_refused",
        "POST",
        "Ben",
        ACTION,
        {"action_type": "choose", "picks": []},
        status=409,
        about="A third choose in window 1.",
    )
    t.fire("{game_id}:wave:1")  # window 1 has a fixed length: it ends on its timer
    t.record_sequence(
        "window_1",
        since_w1,
        about="What every seat's socket heard from the last look until window 1 "
        "ended and window 2 opened.",
    )

    # -- window 2 ---------------------------------------------------------
    since_w2 = t.mark()
    t.record_event(
        "game/night_window_2_doppelganger",
        "Ana",
        "game",
        "night_window",
        about="Window 2 opens after window 1.",
    )
    for name, kind in [
        ("Cleo", "werewolf_pack"),
        ("Dev", "minion"),
        ("Esme", "mason"),
        ("Gus", "drunk"),
        ("Hana", "insomniac"),
    ]:
        t.record(
            f"game/me_choose_prompt_{kind}",
            "GET",
            name,
            ME,
            status=200,
            about=f"/me/ in window 2, the {kind.replace('_', ' ')}'s prompt.",
        )
    _choose(t, "Gus", [{"center_index": 1}])
    _rest_choose(t, [name for name in names if name != "Gus"])
    t.fire("{game_id}:wave:2")
    t.record_sequence(
        "window_2_doppelganger",
        since_w2,
        about="What every seat's socket heard while window 2 was open.",
    )
    for name, kind in [
        ("Ana", "doppelganger"),
        ("Cleo", "werewolf_pack"),
        ("Dev", "minion"),
        ("Esme", "mason"),
        ("Hana", "insomniac"),
        ("Gus", "drunk"),
    ]:
        t.record(
            f"game/me_discussion_choose_{kind}",
            "GET",
            name,
            ME,
            status=200,
            about=f"/me/ in the talk: the {kind}'s night results, canonical names.",
        )
    t.record(
        "game/me_discussion_choose_seer_nothing_chosen",
        "GET",
        "Ben",
        ME,
        status=200,
        about="/me/ in the talk: a Seer whose choose held nothing valid is told so "
        "(a `skip` result with `nothing_chosen`), only on their own phone.",
    )
    t.call("POST", "Ana", END_DISCUSSION)
    t.call("POST", "Ana", REVEAL)


def _auto_deck_table(run: Recording, names: list[str], chip: str, players: int) -> None:
    """The server builds the deck at the deal for the players at the table."""
    t = run.table()
    _app_lobby(t, names)
    t.call("PATCH", "Ana", LOBBY, {"settings": {"deck": "auto", "deck_chip": chip}})
    t.record_event(
        f"lobby/lobby_update_auto_deck_{players}",
        "Ben",
        "lobby",
        "lobby_update",
        about=f"A table with the automatic deck ({chip} chip).",
    )
    t.record(
        f"lobby/detail_auto_deck_{players}",
        "GET",
        "Ben",
        LOBBY,
        status=200,
        about=f"A table with the automatic deck ({chip} chip), "
        "before the deal: the server builds the cards at the deal.",
    )
    t.clock.advance(60)
    t.start_random(7, sample=f"game/started_auto_deck_{players}")
    t.record(
        f"game/me_auto_deck_{players}",
        "GET",
        "Ana",
        ME,
        status=200,
        about=f"/me/ at a {players}-player table with the {chip} chip: the deck the "
        "server built is `roles_in_game`.",
    )


# -- the results tables --------------------------------------------------------


def _deal_table(
    t: Table,
    dealt: dict[str, str],
    center: list[str],
    *,
    again: bool = True,
    settings: dict | None = None,
) -> None:
    """Deal the given cards at a table (play again first unless it is
    the table's first game), open the sockets and let everyone look at their card:
    the night opens."""
    if again:
        t.call("POST", "Ana", PLAY_AGAIN)
    deck: dict[str, int] = {}
    for role in [*dealt.values(), *center]:
        deck[role] = deck.get(role, 0) + 1
    t.call(
        "PATCH",
        "Ana",
        LOBBY,
        {"settings": {"deck": "custom", "roles": deck, **(settings or {})}},
    )
    t.clock.advance(60)
    t.start(dealt, center)
    for name in dealt:
        t.connect(name)
    _everyone(t, list(dealt), GAME_READY, {"ready": True})


def _choose_night(t: Table, names: list[str], picks: dict[str, list[dict]]) -> None:
    """Window 2 only: the phones in ``picks`` choose them, every other phone with a
    choice chooses nothing (a phone with nothing to choose sends nothing), and the
    window closes at its minimum."""
    t.clock.advance(5)
    for name, chosen in picks.items():
        _choose(t, name, chosen)
    _rest_choose(t, [name for name in names if name not in picks])
    t.clock.advance(5)
    t.fire("{game_id}:wave:2")


def _to_vote(t: Table, names: list[str]) -> None:
    """Everyone is ready to vote 60 s into the talk."""
    t.clock.advance(60)
    _everyone(t, names, GAME_READY, {"ready": True})


def _lock_votes(t: Table, votes: dict[str, str]) -> None:
    """Every phone locks its vote 30 s into the vote; the last lock reveals."""
    t.clock.advance(30)
    for voter, target in votes.items():
        t.call("POST", voter, VOTE, {"target_player_id": t.pid(target), "lock": True})


def _record_results(t: Table, name: str, about: str) -> None:
    t.record(f"game/{name}", "GET", "Ana", RESULTS, status=200, about=about)


SIX = ["Ana", "Ben", "Cleo", "Dev", "Esme", "Fin"]
SIX_DEALT = {
    "Ana": "Seer",
    "Ben": "Robber",
    "Cleo": "Werewolf",
    "Dev": "Villager",
    "Esme": "Werewolf",
    "Fin": "Villager",
}
SIX_CENTER = ["Villager", "Troublemaker", "Insomniac"]


def results_tables(run: Recording) -> None:
    """More games played to the results: every way a vote can end
    (after the tables above, so their samples never move)."""
    _six_results_table(run)
    _three_player_table(run)
    _ten_player_table(run)
    _lobby_table(run)
    _seats_table(run)


def _six_results_table(run: Recording) -> None:
    """Six players, one game per way the vote can end (play again between them),
    and a Doppelganger who copies the Minion."""
    t = run.table()
    _app_lobby(t, SIX)

    # -- the Werewolves win: the table votes out a Villager --------------
    _deal_table(t, SIX_DEALT, SIX_CENTER, again=False)
    _choose_night(t, SIX, {"Ana": [_player(t, "Cleo")]})
    t.record(
        "game/night_results_seen_in_talk",
        "POST",
        "Ana",
        RESULTS_SEEN,
        {"seen": 1},
        status=200,
        about="The Seer has seen her night result (after the dawn screen).",
    )
    t.record(
        "game/me_talk_results_seen",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the talk after the night results were acknowledged "
        "(`night_results_seen` equals the results listed).",
    )
    _to_vote(t, SIX)
    _lock_votes(t, {n: ("Ana" if n == "Fin" else "Fin") for n in SIX})
    _record_results(
        t,
        "results_werewolves_win",
        "The table votes out a Villager: no Werewolf dies, the Werewolves win.",
    )

    # -- nobody dies: one vote each ---------------------------------------
    _deal_table(t, SIX_DEALT, SIX_CENTER)
    _choose_night(t, SIX, {})
    _to_vote(t, SIX)
    _lock_votes(t, {n: SIX[(i + 1) % len(SIX)] for i, n in enumerate(SIX)})
    _record_results(
        t,
        "results_nobody_dies",
        "Every player gets one vote: nobody dies (a Werewolf is at the table, "
        "so the Werewolves win).",
    )

    # -- a tie that kills two ---------------------------------------------
    _deal_table(t, SIX_DEALT, SIX_CENTER)
    _choose_night(t, SIX, {})
    _to_vote(t, SIX)
    _lock_votes(
        t,
        {
            "Ana": "Cleo",
            "Ben": "Cleo",
            "Cleo": "Dev",
            "Dev": "Fin",
            "Esme": "Dev",
            "Fin": "Ana",
        },
    )
    _record_results(
        t,
        "results_tie",
        "Two players tie on the most votes (two each): both die; one held a "
        "Werewolf, so the village wins.",
    )

    # -- the Hunter chain ---------------------------------------------------
    _deal_table(t, {**SIX_DEALT, "Fin": "Hunter"}, SIX_CENTER)
    _choose_night(t, SIX, {})
    _to_vote(t, SIX)
    _lock_votes(t, {n: ("Cleo" if n == "Fin" else "Fin") for n in SIX})
    _record_results(
        t,
        "results_hunter_chain",
        "The Hunter is voted out and takes the player he voted for (a Werewolf) "
        "with him.",
    )

    # -- the Tanner dies ----------------------------------------------------
    _deal_table(t, {**SIX_DEALT, "Dev": "Tanner"}, SIX_CENTER)
    _choose_night(t, SIX, {})
    _to_vote(t, SIX)
    _lock_votes(t, {n: ("Ana" if n == "Dev" else "Dev") for n in SIX})
    _record_results(
        t,
        "results_tanner_alone",
        "The Tanner is voted out: the Tanner wins.",
    )

    # -- a dead player whose card had moved -------------------------------
    _deal_table(t, SIX_DEALT, SIX_CENTER)
    _choose_night(t, SIX, {"Ben": [_player(t, "Cleo")]})
    _to_vote(t, SIX)
    _lock_votes(t, {n: ("Ana" if n == "Ben" else "Ben") for n in SIX})
    _record_results(
        t,
        "results_moved_dead_card",
        "The Robber took a Werewolf's card and is voted out holding it: the dead "
        "player's dealt card (Robber) is not their final card (Werewolf); the "
        "village wins.",
    )

    # -- a Doppelganger who copies the Minion -----------------------------
    dealt = {**SIX_DEALT, "Ana": "Doppelganger", "Dev": "Minion"}
    _deal_table(t, dealt, ["Villager", "Seer", "Insomniac"])
    t.clock.advance(3)
    _choose(t, "Ana", [_player(t, "Dev")])
    t.record(
        "game/me_choose_doppelganger_minion_followup",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in window 1 after she looked at the Minion: as the copied "
        "Minion she has nothing to choose (`kind: none`, `chooses_left: 0`), sends "
        "nothing more and learns the Werewolves when the window closes.",
    )
    _rest_choose(t, SIX)
    t.clock.advance(7)
    t.fire("{game_id}:wave:1")
    _choose_night(t, SIX, {})
    t.record(
        "game/me_discussion_choose_doppelganger_minion",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the talk: the Doppelganger-Minion's night results (her look, "
        "then the Werewolves she saw).",
    )


def _three_player_table(run: Recording) -> None:
    """Three players, the smallest table; the talk and the vote are untimed."""
    t = run.table()
    names = ["Ana", "Ben", "Cleo"]
    _app_lobby(t, names)
    _deal_table(
        t,
        {"Ana": "Werewolf", "Ben": "Seer", "Cleo": "Villager"},
        ["Robber", "Troublemaker", "Villager"],
        again=False,
        settings={"discussion_seconds": 0, "voting_seconds": 0},
    )
    _choose_night(t, names, {"Ben": [_player(t, "Ana")]})
    t.record(
        "game/me_talk_untimed",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in an untimed talk (`discussion_seconds` 0): no deadline and "
        "no stage start.",
    )
    _to_vote(t, names)
    t.record(
        "game/me_voting_untimed",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in an untimed vote (`voting_seconds` 0): no deadline and no "
        "stage start; the vote ends when everyone has locked in (or the host).",
    )
    _lock_votes(t, {"Ana": "Cleo", "Ben": "Ana", "Cleo": "Ana"})
    _record_results(
        t,
        "results_three_players",
        "The results of a three-player game: the Seer found the Werewolf.",
    )


def _ten_player_table(run: Recording) -> Table:
    """Ten players, the largest table: the talk and the vote."""
    t = run.table()
    names = ["Ana", "Ben", "Cleo", "Dev", "Esme", "Fin", "Gus", "Hana", "Ida", "Jon"]
    _app_lobby(t, names)
    roles = [
        "Seer",
        "Werewolf",
        "Robber",
        "Mason",
        "Troublemaker",
        "Mason",
        "Drunk",
        "Werewolf",
        "Insomniac",
        "Minion",
    ]
    dealt = dict(zip(names, roles, strict=True))
    _deal_table(t, dealt, ["Villager", "Hunter", "Tanner"], again=False)
    _choose_night(t, names, {})
    t.record(
        "game/me_talk_ten",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the talk at a full table (ten seats).",
    )
    _to_vote(t, names)
    t.record(
        "game/me_voting_ten",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the vote at a full table: `vote_targets` lists the nine "
        "other seats.",
    )
    return t


def _record_lobby(t: Table, name: str, about: str) -> None:
    t.record(f"lobby/{name}", "GET", "Kai", LOBBY, status=200, about=about)


def _lobby_table(run: Recording) -> None:
    """A table before its deal: who is connected (one phone drops and
    comes back), the automatic deck it would deal for each chip at two player
    counts, whether it can be dealt (`deal`), a custom deck one card short, a join
    by someone seated here to another table, and a deal with a member
    who never tapped ready."""
    t = run.table()
    first = ["Kai", "Lia", "Max", "Noa"]
    later = ["Oli", "Pia", "Rex"]
    _sign_in(t, [*first, *later])
    t.clock.advance(60)
    t.call("POST", "Kai", CREATE, {"game_type": "onuw", "defaults": "v2"})
    for name in first[1:]:
        t.clock.advance(60)
        t.call("POST", name, JOIN)
    for name in first:
        t.connect_lobby(name)

    # -- a phone drops, then comes back --------------------------------------
    t.disconnect_lobby("Noa")
    t.record(
        "lobby/detail_member_in_grace",
        "GET",
        "Kai",
        LOBBY,
        status=200,
        about="Noa's phone closed a moment ago: still `connected` during the "
        "table's grace period (`disconnect_grace_seconds`), so a blip shows "
        "nothing.",
    )
    t.clock.advance(30)
    t.fire(t.lobby_presence_key("Noa"))
    t.record_event(
        "lobby/lobby_update_member_dropped",
        "Kai",
        "lobby",
        "lobby_update",
        about="Noa's phone has been away past the grace period: the table is told "
        "(`connected` false), calmly, by a lobby_update.",
    )
    _record_lobby(t, "detail_member_dropped", "A table with one member dropped.")
    t.connect_lobby("Noa")
    t.record_event(
        "lobby/lobby_update_member_back",
        "Kai",
        "lobby",
        "lobby_update",
        about="Noa's phone is back: `connected` true again.",
    )

    # -- the automatic deck at 4 and 7 players, each chip ----------------------
    for count, joining in ((4, []), (7, later)):
        for name in joining:
            t.clock.advance(60)
            t.call("POST", name, JOIN)
        for chip in ("simple", "classic", "chaos"):
            t.call(
                "PATCH", "Kai", LOBBY, {"settings": {"deck": "auto", "deck_chip": chip}}
            )
            _record_lobby(
                t,
                f"detail_deck_{chip}_{count}",
                f"The {chip} automatic deck the deal would build for {count} players "
                "(`deck_preview`), and `deal` ok.",
            )
    t.record_event(
        "lobby/lobby_update_deck_preview",
        "Lia",
        "lobby",
        "lobby_update",
        about="Every lobby_update carries `deck_preview` and `deal` (here after a "
        "chip change at seven players).",
    )

    # -- a custom deck, then one more player: one card short ----------------
    deck = {
        "Werewolf": 2,
        "Seer": 1,
        "Robber": 1,
        "Troublemaker": 1,
        "Drunk": 1,
        "Insomniac": 1,
        "Villager": 3,
    }
    t.call("PATCH", "Kai", LOBBY, {"settings": {"deck": "custom", "roles": deck}})
    _record_lobby(
        t,
        "detail_custom_deck_ok",
        "A custom deck of ten cards at seven players: no preview (its roles are in "
        "`settings`), `deal` ok.",
    )
    t.guest("Sam")
    t.clock.advance(60)
    t.call("POST", "Sam", JOIN)
    t.record_event(
        "lobby/lobby_update_joined",
        "Kai",
        "lobby",
        "lobby_update",
        about="A player joined: the table is sent the whole body (`deal` changes "
        "with the player count).",
    )
    _record_lobby(
        t,
        "detail_custom_deck_short",
        "The same custom deck after an eighth player joined: one card short "
        "(`deal`: ok false, need 11, have 10).",
    )

    # -- someone seated here tries to sit at another table -------------------
    other = run.table()
    other.guest("Uma")
    other.call("POST", "Uma", CREATE, {"game_type": "onuw", "defaults": "v2"})
    other.players["Rex"] = t.players["Rex"]
    other.record(
        "lobby/join_already_at_table",
        "POST",
        "Rex",
        JOIN,
        status=409,
        about="Joining a table while seated at another table that is "
        "waiting: refused, with that table's code (`lobby_code`) so the phone can "
        "offer to go there (leaving a waiting table always works).",
    )

    # -- nobody tapped ready, and the table is dealt --------------------------
    t.call("PATCH", "Kai", LOBBY, {"settings": {"deck": "auto"}})
    t.clock.advance(60)
    t.start_random(11, sample="game/started_nobody_ready")


def _seats_table(run: Recording) -> None:
    """A table set for eight before anyone joins (`seats`): the host alone builds
    a custom deck card by card for eight, people arrive one by one (`deal.need`
    never moves), only seven come, the host lowers the number (the custom deck no
    longer fits; one tap back to the automatic deck), deals; a ninth is refused."""
    t = run.table()
    names = ["Tia", "Ugo", "Vic", "Wes", "Xan", "Yan", "Zoe", "Abe"]
    _sign_in(t, names)
    t.clock.advance(60)
    t.call("POST", "Tia", CREATE, {"game_type": "onuw", "defaults": "v2"})
    t.connect_lobby("Tia")
    t.record(
        "lobby/settings_seats",
        "PATCH",
        "Tia",
        LOBBY,
        {"settings": {"seats": 8, "deck_chip": "classic"}},
        status=200,
        about="The host alone sets the table for eight: `deal.need` and "
        "`deck_preview` are for eight (`deal.seats`), `deal.ok` false until eight "
        "are here.",
    )
    t.record(
        "lobby/settings_custom_deck_building",
        "PATCH",
        "Tia",
        LOBBY,
        {
            "settings": {
                "deck": "custom",
                "roles": {"Werewolf": 2, "Seer": 1, "Robber": 1, "Villager": 1},
            }
        },
        status=200,
        about="A custom deck being built, stored card by card: five of the eleven "
        "cards eight players need (`deal.have` 5).",
    )
    deck = {
        "Werewolf": 2,
        "Minion": 1,
        "Seer": 1,
        "Robber": 1,
        "Troublemaker": 1,
        "Drunk": 1,
        "Insomniac": 1,
        "Villager": 3,
    }
    t.call("PATCH", "Tia", LOBBY, {"settings": {"roles": deck}})
    _record_seats(
        t,
        "detail_seats_8_custom_alone",
        "The host alone, with a custom "
        "deck of eleven cards for eight: the deck fits, the table waits.",
    )
    for name in names[1:4]:
        t.clock.advance(60)
        t.call("POST", name, JOIN)
    t.record_event(
        "lobby/lobby_update_seats_joined",
        "Tia",
        "lobby",
        "lobby_update",
        about="A fourth player joined a table set for eight: `deal.need` stays 11.",
    )
    _record_seats(t, "detail_seats_8_four_here", "Four of eight here, custom deck.")
    for name in names[4:7]:
        t.clock.advance(60)
        t.call("POST", name, JOIN)
    _record_seats(t, "detail_seats_8_seven_here", "Seven of eight here.")
    t.record(
        "lobby/settings_seats_below_present",
        "PATCH",
        "Tia",
        LOBBY,
        {"settings": {"seats": 6}},
        status=400,
        about="The number lowered below the players already here: refused.",
    )
    t.record(
        "lobby/settings_seats_lowered",
        "PATCH",
        "Tia",
        LOBBY,
        {"settings": {"seats": 7}},
        status=200,
        about="Only seven came: the host lowers the number. The custom deck for "
        "eight no longer fits (`deal`: need 10, have 11) and is kept, not changed.",
    )
    t.record(
        "lobby/settings_back_to_auto",
        "PATCH",
        "Tia",
        LOBBY,
        {"settings": {"deck": "auto"}},
        status=200,
        about="One tap back to the automatic deck (the chip the table had): it "
        "fits seven, `deal.ok`.",
    )
    t.record(
        "lobby/join_full_seats",
        "POST",
        "Abe",
        JOIN,
        status=400,
        about="Joining a table with every seat it is set for taken.",
    )
    t.call("PATCH", "Tia", LOBBY, {"settings": {"seats": 8}})
    t.clock.advance(60)
    t.call("POST", "Abe", JOIN)
    _record_seats(
        t,
        "detail_seats_8_full",
        "Eight of eight here, the automatic deck: ready to deal.",
    )
    t.record(
        "lobby/settings_lengths",
        "PATCH",
        "Tia",
        LOBBY,
        {
            "settings": {
                "discussion_seconds": 360,
                "voting_seconds": 90,
                "night_wave_seconds": 25,
                "night_min_window_seconds": 6,
                "night_doppelganger_window_seconds": 12,
                "card_look_seconds": 20,
                "disconnect_grace_seconds": 30,
                "host_handover_seconds": 120,
            }
        },
        status=200,
        about="The host sets every length on the set-up page (each its own "
        "value): stored in `settings`, reported in `lengths`.",
    )
    t.clock.advance(60)
    t.start_random(13)


def _record_seats(t: Table, name: str, about: str) -> None:
    t.record(f"lobby/{name}", "GET", "Tia", LOBBY, status=200, about=about)


def gone_account(run: Recording) -> None:
    """An account that is gone (deleted): 401 on the refresh and on a read, the
    one answer the app takes for "start afresh" (anything else: ask again).
    Recorded last, so no other sample's ids move."""
    t = run.table()
    player = t.guest("Gone")
    access = str(AccessToken.for_user(player.user))
    player.user.delete()
    t.record(
        "auth/token_refresh_user_gone",
        "POST",
        "",
        "/auth/token/refresh/",
        {"refresh": player.refresh_token},
        status=401,
        about="The refresh of an account that is gone (deleted): 401.",
    )
    t.record(
        "auth/user_gone",
        "GET",
        "",
        MY_TABLE,
        status=401,
        about="An authenticated read by an account that is gone (deleted): 401.",
        bearer=access,
    )
    t.record(
        "auth/user_gone_game_me",
        "GET",
        "",
        "/onuw/games/{game_id}/me/",
        status=401,
        about="A game's /me/ read by an account that is gone (deleted): 401.",
        bearer=access,
        game_id=GONE_GAME_ID,
    )


PRACTICE = "/lobbies/{code}/practice/"


def practice_table(run: Recording) -> None:
    """Practice players (``apps.core.practice``): the host switches them on and
    seats village things; a guest sees them tagged; the server plays them through
    the whole game while the two people play theirs; a person joining a full table
    takes a practice seat. Recorded after every other table, so no other sample's
    ids or codes move."""
    t = run.table()
    _sign_in(t, ["Pia", "Quin", "Rue"])
    t.clock.advance(60)
    created = t.call("POST", "Pia", CREATE, {"game_type": "onuw", "defaults": "v2"})
    t.code = created["code"]
    t.connect_lobby("Pia")
    t.record(
        "lobby/practice_on",
        "POST",
        "Pia",
        PRACTICE,
        {"on": True},
        status=200,
        about="The host switches practice players on (the app's hidden long "
        "press): `settings.practice` and `practice.most`, the seats they may take; "
        "nobody is seated yet.",
    )
    t.record(
        "lobby/practice_three",
        "POST",
        "Pia",
        PRACTICE,
        {"count": 3},
        status=200,
        about="Three practice players sit down: `players[].practice` true, always "
        "`connected`, named for village things, with seat tokens like anyone.",
    )
    t.seat_practice()
    t.record_event(
        "lobby/lobby_update_practice",
        "Pia",
        "lobby",
        "lobby_update",
        about="The table hears the practice players arrive (the whole lobby body).",
    )
    t.record(
        "lobby/practice_full",
        "POST",
        "Pia",
        PRACTICE,
        {"count": 10},
        status=400,
        about="More practice players than the free seats: `lobby_full`, nothing "
        "changes.",
    )
    t.record(
        "lobby/practice_bad_request",
        "POST",
        "Pia",
        PRACTICE,
        {"count": "2"},
        status=400,
        about="A practice change that is not `on` (true or false) or a whole "
        "`count`: `bad_request`.",
    )
    t.record(
        "lobby/practice_two",
        "POST",
        "Pia",
        PRACTICE,
        {"count": 2},
        status=200,
        about="The count lowered: the newest practice player gets up.",
    )
    t.clock.advance(60)
    t.call("POST", "Quin", JOIN)
    t.record(
        "lobby/practice_not_host",
        "POST",
        "Quin",
        PRACTICE,
        {"count": 3},
        status=403,
        about="A guest cannot seat practice players.",
    )
    t.record(
        "lobby/detail_practice_guest",
        "GET",
        "Quin",
        LOBBY,
        status=200,
        about="A guest's view of a table with two people and two practice players.",
    )
    t.call("PATCH", "Pia", LOBBY, {"settings": {"seats": 6}})
    t.record(
        "lobby/detail_practice_short",
        "GET",
        "Pia",
        LOBBY,
        status=200,
        about="The host's table set for six, two people and two practice players "
        "here: four of six, 'Play with 4' beside the practice players.",
    )
    t.call("PATCH", "Pia", LOBBY, {"settings": {"seats": None}})
    t.seat_practice()
    deck = {
        "Werewolf": 1,
        "Seer": 1,
        "Robber": 1,
        "Troublemaker": 1,
        "Insomniac": 1,
        "Villager": 2,
    }
    t.call(
        "PATCH",
        "Pia",
        LOBBY,
        {"settings": {"seats": 4, "deck": "custom", "roles": deck}},
    )
    t.clock.advance(60)
    t.start(
        {
            "Pia": "Seer",
            "Quin": "Villager",
            "Scarecrow": "Werewolf",
            "Teapot": "Robber",
        },
        ["Troublemaker", "Villager", "Insomniac"],
    )
    for name in ("Pia", "Quin"):
        t.connect(name)
    t.record(
        "game/me_look_practice",
        "GET",
        "Pia",
        ME,
        status=200,
        about="The look at a table with practice players: they looked the moment "
        "it opened (`progress` 2 of 4); `players[].practice` marks them.",
    )
    t.record(
        "lobby/practice_in_game",
        "POST",
        "Pia",
        PRACTICE,
        {"count": 0},
        status=409,
        about="Practice players cannot change once dealt: `lobby_closed`.",
    )
    _everyone(t, ["Pia", "Quin"], GAME_READY, {"ready": True})
    t.record(
        "game/me_window_practice",
        "GET",
        "Pia",
        ME,
        status=200,
        about="Window 2 with practice players: they chose the moment it opened; "
        "nothing about it reaches anyone (the Seer's prompt is her own).",
    )
    t.record(
        "game/players_practice",
        "GET",
        "Quin",
        PLAYERS,
        status=200,
        about="The players list: practice players are `practice` and always "
        "`connected`.",
    )
    t.clock.advance(5)
    _choose(t, "Pia", [_player(t, "Scarecrow")])
    t.clock.advance(5)
    t.fire("{game_id}:wave:2")
    t.record(
        "game/me_talk_practice",
        "GET",
        "Quin",
        ME,
        status=200,
        about="The talk: the practice players are ready to vote at once "
        "(`progress` 2 of 4); the people decide when it ends.",
    )
    _to_vote(t, ["Pia", "Quin"])
    t.record(
        "game/me_voting_practice",
        "GET",
        "Quin",
        ME,
        status=200,
        about="The vote: the practice players locked a random vote at once "
        "(`progress` 2 of 4), never told whom.",
    )
    _lock_votes(t, {"Pia": "Scarecrow", "Quin": "Scarecrow"})
    t.record(
        "game/results_practice",
        "GET",
        "Pia",
        RESULTS,
        status=200,
        about="The results: a practice player's card, night and vote show like "
        "anyone's.",
    )
    t.call("POST", "Pia", PLAY_AGAIN)
    t.clock.advance(60)
    t.record(
        "lobby/join_takes_practice_seat",
        "POST",
        "Rue",
        JOIN,
        status=200,
        about="A person joins a table whose every seat is taken: the newest "
        "practice player gives up its seat.",
    )
    t.record(
        "lobby/practice_off",
        "POST",
        "Pia",
        PRACTICE,
        {"on": False},
        status=200,
        about="The host switches practice players off (the long press again): "
        "every one gets up; the body has no `practice` and `settings` no "
        "`practice`, as at a table that never used them.",
    )


def record_all(run: Recording) -> None:
    classic_table(run)
    full_table(run, finished=doppelganger_table(run))
    choose_tables(run)
    results_tables(run)
    gone_account(run)
    practice_table(run)
    # Last, so nothing recorded above moves (imported here: it uses this module).
    from .asked_scenarios import asked_table
    from .story_scenarios import story_tables

    story_tables(run)
    asked_table(run)
