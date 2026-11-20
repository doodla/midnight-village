"""The games whose payloads become the contract samples.

Tables played through the real API (see recorder.py):

- ``classic_table``: six players, no Doppelganger (so the night is window 2
  only), the default timers. Sign-in, lobby set-up and every lobby event, the
  Seer, Robber, Troublemaker and a Werewolf pack, a player with no night action,
  the close at the minimum window length, the talk, the vote with a Hunter
  chain, the results, play again and the owner leaving; "where am I" in every
  state, online stats, the night results ack, recent games. Most error bodies.
- ``doppelganger_table``: eight players and every remaining prompt kind: the
  Doppelganger's look and her follow-up (window 1), the lone Werewolf's center
  peek, Minion, Masons, Drunk, Insomniac, a Seer who skips. Every timer is 0
  (as the harness plays), so deadlines are null. Host handover and return, the
  host revealing votes with abstentions, the results with the night timeline,
  the debug oracle.
  Then more games there (play again): she copies a Werewolf (window 2 /me/
  listing her window-1 look; a dealt Tanner dies), a Mason, an Insomniac, the
  Minion. Calls from someone who does not play in the game.
- ``full_table``: ten players fill a table; the join refusals and the ack from
  someone who does not play in the game.
- ``protocol_two_tables`` and ``results_tables``: night protocol 2 (see
  ``tests/README.md``): the look stage, the choose night, ready to vote, lock-in
  voting, the automatic deck; then every way a vote ends, three and ten seats,
  an untimed talk and vote.

Adding a situation: drive it here with ``table.record`` / ``table.record_event``,
run ``just samples`` and review the new files.
"""

from __future__ import annotations

from unittest.mock import patch

from rest_framework.throttling import SimpleRateThrottle

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
READY = "/lobbies/{code}/ready/"
MY_TABLE = "/me/table/"
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


def _join_and_ready(table: Table, names: list[str]) -> None:
    for name in names:
        table.clock.advance(60)
        table.call("POST", name, "/lobbies/{code}/join/")
    for name in names:
        table.call("POST", name, "/lobbies/{code}/ready/")


def _act(table: Table, who: str, action: str, targets: dict | None = None) -> None:
    table.call("POST", who, ACTION, {"action_type": action, "targets": targets or {}})


def _vote(table: Table, who: str, target: str) -> None:
    table.call("POST", who, VOTE, {"target_player_id": table.pid(target)})


def _record_night_results(t: Table, players: list[tuple[str, str]]) -> None:
    """`/me/` in the talk for each player, with their night result of that kind
    (`night_results` carries every kind the socket does)."""
    for name, kind in players:
        t.record(
            f"game/me_discussion_result_{kind}",
            "GET",
            name,
            ME,
            status=200,
            about=f"/me/ in the talk with a {kind.replace('_', ' ')} result.",
        )


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
    _join_and_ready(t, ["Cleo", "Dev", "Esme", "Fin"])
    t.record(
        "lobby/ready",
        "POST",
        "Ana",
        "/lobbies/{code}/ready/",
        status=200,
        about="A player toggles ready.",
    )
    t.record(
        "lobby/ready_invalid",
        "POST",
        "Ana",
        READY,
        {"is_ready": "yes"},
        status=400,
        about="A ready flag that is not true or false.",
    )
    t.record_event(
        "lobby/player_ready", "Ben", "lobby", "player_ready", about="Ready toggled."
    )
    t.record(
        "game/start_not_all_ready",
        "POST",
        "Ana",
        START,
        status=400,
        about="The host deals before everyone is ready.",
    )
    t.call("POST", "Ben", "/lobbies/{code}/ready/")
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
        {"settings": {"roles": {"Werewolf": 2, "Seer": 1}}},
        status=400,
        about="A deck that does not fit the table.",
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
        about="The table before the deal, everyone ready.",
    )
    t.record(
        "game/start_not_host",
        "POST",
        "Ben",
        START,
        status=403,
        about="Someone other than the host deals.",
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
    t.record(
        "lobby/ready_in_game",
        "POST",
        "Ben",
        READY,
        status=409,
        about="Toggling ready while a game runs.",
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
    t.record_event(
        "game/wave_start", "Ana", "game", "wave_start", about="Window 2 opens."
    )
    for name, kind in [
        ("Ana", "seer"),
        ("Ben", "robber"),
        ("Dev", "troublemaker"),
        ("Cleo", "werewolf_pack"),
    ]:
        t.record_event(
            f"game/action_prompt_{kind}",
            name,
            "game",
            "action_prompt",
            about=f"Window 2 prompt: {kind.replace('_', ' ')}.",
        )
        t.record(
            f"game/me_night_prompt_{kind}",
            "GET",
            name,
            ME,
            status=200,
            about=f"/me/ in window 2 with the {kind.replace('_', ' ')} prompt.",
        )
    t.record_event(
        "game/wave_waiting",
        "Fin",
        "game",
        "wave_waiting",
        about="Nothing to do this window.",
    )
    t.record(
        "game/me_night_no_action",
        "GET",
        "Fin",
        ME,
        status=200,
        about="/me/ at night for a player with no action.",
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
    t.record(
        "game/action_not_an_actor",
        "POST",
        "Fin",
        ACTION,
        {"action_type": "skip", "targets": {}},
        status=400,
        about="An action from a player with nothing to do this window.",
    )
    t.record(
        "game/action_invalid",
        "POST",
        "Ana",
        ACTION,
        {"action_type": "peek_player", "targets": {"player_id": t.pid("Ana")}},
        status=400,
        about="An action the server refuses (generic message).",
    )
    t.record(
        "game/action_submitted",
        "POST",
        "Ana",
        ACTION,
        {"action_type": "peek_player", "targets": {"player_id": t.pid("Cleo")}},
        status=200,
        about="A night action is accepted.",
    )
    t.record(
        "game/action_already_acted",
        "POST",
        "Ana",
        ACTION,
        {"action_type": "peek_player", "targets": {"player_id": t.pid("Cleo")}},
        status=409,
        about="A second action in the same window.",
    )
    t.record(
        "debug/state_night",
        "GET",
        "Ana",
        DEBUG_STATE,
        status=200,
        about="The DEBUG-only oracle at night, a window open and its timer armed.",
        debug=True,
    )
    t.record(
        "game/me_night_acted",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ after acting, the window still open.",
    )
    _act(t, "Ben", "swap_with_player", {"player_id": t.pid("Dev")})
    _act(t, "Dev", "swap_others", {"player_ids": [t.pid("Ana"), t.pid("Ben")]})
    _act(t, "Cleo", "see_team")
    _act(t, "Esme", "see_team")
    # Everyone has acted; the window would close at its minimum length. The
    # harness's hook closes it now instead.
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
    for name, kind in [
        ("Ana", "peek_player"),
        ("Ben", "swap_with_player"),
        ("Dev", "swap_others"),
        ("Cleo", "see_team_werewolves"),
    ]:
        t.record_event(
            f"game/action_result_{kind}",
            name,
            "game",
            "action_result",
            about=f"Night result: {kind.replace('_', ' ')}.",
        )
    t.record_event(
        "game/wave_complete", "Ana", "game", "wave_complete", about="A window closed."
    )
    t.record_event(
        "game/phase_change_discussion",
        "Ana",
        "game",
        "phase_change",
        about="The night ends; the talk starts (timed).",
    )

    # -- the talk ---------------------------------------------------------
    t.record(
        "game/me_discussion",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the talk, with the night's result.",
    )
    _record_night_results(
        t, [("Ben", "swap_with_player"), ("Dev", "swap_others"), ("Cleo", "see_team")]
    )
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
        "game/advance_wave_not_night",
        "POST",
        "Ana",
        ADVANCE,
        status=400,
        about="The host closes a night window after the night.",
    )
    t.record(
        "game/reveal_votes_not_voting",
        "POST",
        "Ana",
        REVEAL,
        status=400,
        about="The host reveals votes before the vote.",
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
        "game/action_not_night",
        "POST",
        "Ben",
        ACTION,
        {"action_type": "skip", "targets": {}},
        status=400,
        about="A night action after the night.",
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
    t.record(
        "game/end_discussion_wrong_phase",
        "POST",
        "Ana",
        END_DISCUSSION,
        status=400,
        about="Ending a talk that is over.",
    )
    t.record_event(
        "game/phase_change_voting",
        "Ana",
        "game",
        "phase_change",
        about="The vote starts (timed).",
    )

    # -- the vote ---------------------------------------------------------
    t.record(
        "game/me_voting", "GET", "Ana", ME, status=200, about="/me/ before voting."
    )
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
    t.record(
        "game/vote_submitted",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Fin")},
        status=200,
        about="A vote is accepted.",
    )
    t.record_event(
        "game/vote_submitted",
        "Ben",
        "game",
        "vote_submitted",
        about="Someone voted (not for whom).",
    )
    t.record(
        "game/me_voting_voted", "GET", "Ana", ME, status=200, about="/me/ after voting."
    )
    t.record(
        "game/players_voting",
        "GET",
        "Ben",
        PLAYERS,
        status=200,
        about="The player list during the vote.",
    )
    t.record(
        "game/vote_already_voted",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Ben")},
        status=409,
        about="A second vote.",
    )
    t.record(
        "game/vote_invalid_target",
        "POST",
        "Ben",
        VOTE,
        {"target_player_id": t.pid("Ben")},
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
    t.record("game/me_results", "GET", "Ana", ME, status=200, about="/me/ at the end.")
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
    t.call("POST", "Ana", "/lobbies/{code}/leave/")
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
    t.call("POST", "Ana", "/lobbies/{code}/ready/")
    _join_and_ready(t, list(dealt)[1:])
    t.call("PATCH", "Ana", LOBBY, {"settings": {"roles": deck, **UNTIMED}})
    t.clock.advance(60)
    t.start(dealt, ["Werewolf", "Villager", "Tanner"])
    for name in dealt:
        t.connect(name)

    # -- window 1: the Doppelganger --------------------------------------
    t.record_event(
        "game/wave_start_untimed",
        "Ben",
        "game",
        "wave_start",
        about="Window 1 opens, with no deadline.",
    )
    t.record_event(
        "game/wave_waiting_window1",
        "Ben",
        "game",
        "wave_waiting",
        about="Window 1 is the Doppelganger's: nothing to do.",
    )
    t.record(
        "game/action_not_a_player",
        "POST",
        OUTSIDER,
        ACTION,
        {"action_type": "skip", "targets": {}},
        status=403,
        about="A night action from someone who does not play in the game.",
    )
    t.record_event(
        "game/action_prompt_doppelganger",
        "Ana",
        "game",
        "action_prompt",
        about="Window 1 prompt: the Doppelganger's look.",
    )
    t.record(
        "game/me_night_prompt_doppelganger",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in window 1 with the Doppelganger's prompt.",
    )
    t.record(
        "game/me_night_window1_waiting",
        "GET",
        "Ben",
        ME,
        status=200,
        about="/me/ in window 1 for everyone else.",
    )
    _act(t, "Ana", "peek_player", {"player_id": t.pid("Ben")})
    t.record_event(
        "game/action_result_doppelganger_look",
        "Ana",
        "game",
        "action_result",
        about="Her look, sent at once: she copied the Seer.",
    )
    t.record_event(
        "game/action_prompt_doppelganger_followup",
        "Ana",
        "game",
        "action_prompt",
        about="Her follow-up as the copied Seer, still window 1.",
    )
    t.record(
        "game/me_night_prompt_doppelganger_followup",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ with the Doppelganger's follow-up prompt.",
    )
    _act(t, "Ana", "peek_center", {"center_indices": [0, 2]})
    t.record_event(
        "game/action_result_peek_center",
        "Ana",
        "game",
        "action_result",
        about="Night result: two center cards (her follow-up).",
    )

    # -- window 2: everyone else ------------------------------------------
    for name, kind in [
        ("Cleo", "werewolf_lone"),
        ("Dev", "minion"),
        ("Esme", "mason"),
        ("Gus", "drunk"),
        ("Hana", "insomniac"),
    ]:
        t.record_event(
            f"game/action_prompt_{kind}",
            name,
            "game",
            "action_prompt",
            about=f"Window 2 prompt: {kind.replace('_', ' ')}.",
        )
        t.record(
            f"game/me_night_prompt_{kind}",
            "GET",
            name,
            ME,
            status=200,
            about=f"/me/ in window 2 with the {kind.replace('_', ' ')} prompt.",
        )
    _act(t, "Ben", "skip")
    _act(t, "Cleo", "see_team", {"center_index": 1})
    _act(t, "Dev", "see_team")
    _act(t, "Esme", "see_team")
    _act(t, "Fin", "see_team")
    _act(t, "Gus", "swap_with_center", {"center_index": 0})
    # Hana (Insomniac) has not tapped: the host closes the window; her look
    # is automatic and still happens.
    t.record(
        "game/advance_wave",
        "POST",
        "Ana",
        ADVANCE,
        status=200,
        about="The host closes the night window now.",
    )
    for name, kind in [
        ("Cleo", "see_team_lone_werewolf"),
        ("Dev", "see_team_minion"),
        ("Esme", "see_team_masons"),
        ("Gus", "swap_with_center"),
        ("Hana", "insomniac"),
        ("Ben", "skip"),
    ]:
        t.record_event(
            f"game/action_result_{kind}",
            name,
            "game",
            "action_result",
            about=f"Night result: {kind.replace('_', ' ')}.",
        )
    t.record_event(
        "game/phase_change_discussion_untimed",
        "Ben",
        "game",
        "phase_change",
        about="The talk starts, with no deadline.",
    )
    t.record(
        "game/me_discussion_doppelganger",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the talk: the Doppelganger's look and follow-up results.",
    )
    t.record(
        "game/me_discussion_skipped",
        "GET",
        "Ben",
        ME,
        status=200,
        about="/me/ in the talk for a Seer who did nothing (no result).",
    )
    _record_night_results(
        t,
        [
            ("Cleo", "see_team_lone_werewolf"),
            ("Dev", "see_team_minion"),
            ("Esme", "see_team_masons"),
            ("Gus", "swap_with_center"),
            ("Hana", "insomniac"),
        ],
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
        "game/me_voting_untimed",
        "GET",
        "Ben",
        ME,
        status=200,
        about="/me/ in a vote with no deadline.",
    )
    t.record(
        "game/vote_not_a_player",
        "POST",
        OUTSIDER,
        VOTE,
        {"target_player_id": t.pid("Cleo")},
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


def _play_out(t: Table) -> None:
    """Untimed: the host closes the night, ends the talk and reveals the votes."""
    _close_the_night(t)
    t.call("POST", "Ana", END_DISCUSSION)
    t.call("POST", "Ana", REVEAL)


def _deal_again(t: Table, dealt: dict[str, str], center: list[str]) -> None:
    t.call("POST", "Ana", PLAY_AGAIN)
    t.clock.advance(60)
    t.start(dealt, center)


def _doppelganger_copies(t: Table) -> None:
    """More games at the Doppelganger table (play again), one per role she can
    copy that acts in window 2 or with a team view, and a dealt Tanner who
    dies."""
    usual = {
        "Ana": "Doppelganger",
        "Ben": "Seer",
        "Cleo": "Werewolf",
        "Dev": "Minion",
        "Esme": "Mason",
        "Fin": "Mason",
        "Gus": "Drunk",
        "Hana": "Insomniac",
    }
    center = ["Werewolf", "Villager", "Tanner"]

    # She copies a Werewolf (and wakes with them in window 2); Dev is the
    # Tanner and the table votes him out.
    _deal_again(t, {**usual, "Dev": "Tanner"}, ["Werewolf", "Villager", "Minion"])
    _act(t, "Ana", "peek_player", {"player_id": t.pid("Cleo")})
    t.record_event(
        "game/action_prompt_doppelganger_werewolf",
        "Ana",
        "game",
        "action_prompt",
        about="Window 2 prompt for a Doppelganger who copied a Werewolf.",
    )
    t.record(
        "game/me_night_window2_after_look",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in window 2: window 1's look is listed, her new prompt open.",
    )
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

    # She copies a Mason, then an Insomniac: both act in window 2.
    for copied, kind in [("Esme", "mason"), ("Hana", "insomniac")]:
        _deal_again(t, usual, center)
        _act(t, "Ana", "peek_player", {"player_id": t.pid(copied)})
        t.record_event(
            f"game/action_prompt_doppelganger_{kind}",
            "Ana",
            "game",
            "action_prompt",
            about=f"Window 2 prompt for a Doppelganger who copied the {kind}.",
        )
        _play_out(t)

    # She copies the Minion: her team view is window 1's follow-up.
    _deal_again(t, usual, center)
    _act(t, "Ana", "peek_player", {"player_id": t.pid("Dev")})
    _act(t, "Ana", "see_team")
    t.record_event(
        "game/action_result_see_team_doppelganger_minion",
        "Ana",
        "game",
        "action_result",
        about="Night result of a Doppelganger who copied the Minion.",
    )
    _play_out(t)


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


def _v2_lobby(t: Table, names: list[str], *, sample: str | None = None) -> None:
    """A table the way the new screens make it: ``defaults: "v2"`` (the card look,
    night protocol 2, the automatic Simple deck)."""
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
    _join_and_ready(t, names[1:])
    t.call("POST", names[0], "/lobbies/{code}/ready/")


def _everyone(t: Table, names: list[str], path: str, body: dict) -> None:
    for name in names:
        t.call("POST", name, path, body)


def _choose(t: Table, who: str, picks: list[dict]) -> None:
    t.call("POST", who, ACTION, {"action_type": "choose", "picks": picks})


def _player(t: Table, name: str) -> dict:
    return {"player_id": t.pid(name)}


def protocol_two_tables(run: Recording) -> None:
    """Night protocol 2: the look stage, the choose night (a plain table, then a
    Doppelganger table with window 1), lock-in voting, ready to vote, the
    automatic deck and the create defaults."""
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
    """Five players, a lone Werewolf: look stage, window 2 (every phone chooses
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
            "The host opens a table with `defaults: v2`: a 30 s look at the cards, "
            "night protocol 2 and the automatic Simple deck, and nothing else (no "
            "timer length is written)."
        ),
    )
    _join_and_ready(t, names[1:])
    t.call("POST", "Ana", "/lobbies/{code}/ready/")
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
    t.start(dealt, ["Werewolf", "Villager", "Villager"], sample="game/started_v2")
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
    _everyone(t, names[1:4], GAME_READY, {"ready": True})
    since_night = t.mark()
    t.call("POST", "Esme", GAME_READY, {"ready": True})
    t.record_sequence(
        "look_stage",
        since_deal,
        about="What every seat's socket heard from the deal until the last look.",
    )

    # -- window 2: every phone chooses once ------------------------------
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
        about="A phone's choose: the same answer whatever the role.",
    )
    t.record(
        "game/choose_submitted_villager",
        "POST",
        "Esme",
        ACTION,
        {"action_type": "choose", "picks": [{"self": True}]},
        status=200,
        about="The same answer for a player with nothing to choose.",
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
        about="Any other action_type under night protocol 2.",
    )
    t.record(
        "game/me_choose_chosen",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ after choosing: the prompt says how many chooses were sent.",
    )
    _choose(t, "Ben", [_player(t, "Ana")])
    _choose(t, "Dev", [_player(t, "Ana"), _player(t, "Ben")])
    _choose(t, "Cleo", [{"center_index": 0}])
    window_stage = t.stage_now()
    t.fire("{game_id}:wave:2")  # every phone has chosen: the close at the minimum
    t.record_sequence(
        "window_2",
        since_night,
        about="What every seat's socket heard while window 2 was open.",
    )
    t.record_event(
        "game/wave_complete_v2",
        "Ana",
        "game",
        "wave_complete",
        about="The window closed: every phone reads its results from /me/.",
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
        {"target_player_id": t.pid("Cleo"), "lock": False},
        status=200,
        about="A pick: nothing is sent to anyone else; the answer echoes the pick.",
    )
    t.record(
        "game/vote_repicked",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Dev"), "lock": False},
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
        "game/vote_self_v2",
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
        "game/vote_locked_v2",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Dev"), "lock": True},
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
        {"target_player_id": t.pid("Dev"), "lock": True},
        status=200,
        about="The same lock sent again (its answer was lost): the original's answer, "
        "nothing stored or sent.",
    )
    t.record(
        "game/vote_already_locked",
        "POST",
        "Ana",
        VOTE,
        {"target_player_id": t.pid("Cleo"), "lock": False},
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
        "debug/state_v2",
        "GET",
        "Ana",
        DEBUG_STATE,
        status=200,
        about="The oracle under night protocol 2: per-player ready, vote_locked.",
        debug=True,
    )
    vote_stage = t.stage_now()
    for name in names[1:]:
        target = "Dev" if name == "Cleo" else "Cleo"
        t.call("POST", name, VOTE, {"target_player_id": t.pid(target)})
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
        {"target_player_id": t.pid("Cleo"), "stage": vote_stage},
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
        "game/me_results_v2",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in the results phase under night protocol 2.",
    )
    t.record(
        "game/results_v2",
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
    _v2_lobby(t, names)
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
        "lobby/lobby_update_v2_custom_deck",
        "Ben",
        "lobby",
        "lobby_update",
        about="A night protocol 2 table whose host picked the cards (`deck: custom`).",
    )
    t.record(
        "lobby/detail_v2_custom_deck",
        "GET",
        "Ben",
        LOBBY,
        status=200,
        about="A night protocol 2 table with a custom deck, before the deal.",
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
    for name in names[1:]:
        _choose(t, name, [])
    t.record(
        "game/choose_submitted_window1_second",
        "POST",
        "Ben",
        ACTION,
        {"action_type": "choose", "picks": [{"self": True}]},
        status=200,
        about="The server accepts a second choose in window 1 from anyone (only "
        "the Doppelganger's is read), so a second tap is never a tell.",
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
    for name in names:
        if name != "Gus":
            _choose(t, name, [])
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
    _v2_lobby(t, names)
    t.call("PATCH", "Ana", LOBBY, {"settings": {"deck": "auto", "deck_chip": chip}})
    t.record_event(
        f"lobby/lobby_update_v2_auto_deck_{players}",
        "Ben",
        "lobby",
        "lobby_update",
        about=f"A night protocol 2 table with the automatic deck ({chip} chip).",
    )
    t.record(
        f"lobby/detail_v2_auto_deck_{players}",
        "GET",
        "Ben",
        LOBBY,
        status=200,
        about=f"A night protocol 2 table with the automatic deck ({chip} chip), "
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


# -- the results tables (night protocol 2) ----------------------------------


def _deal_v2(
    t: Table,
    dealt: dict[str, str],
    center: list[str],
    *,
    again: bool = True,
    settings: dict | None = None,
) -> None:
    """Deal the given cards at a protocol-2 table (play again first unless it is
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


def _night_v2(t: Table, names: list[str], picks: dict[str, list[dict]]) -> None:
    """Window 2 only: every phone chooses once (``picks`` by name, nothing for the
    rest) and the window closes at its minimum."""
    t.clock.advance(5)
    for name in names:
        _choose(t, name, picks.get(name, []))
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
    """More protocol-2 games played to the results: every way a vote can end
    (after the tables above, so their samples never move)."""
    _six_results_table(run)
    _three_player_table(run)
    _ten_player_table(run)


def _six_results_table(run: Recording) -> None:
    """Six players, one game per way the vote can end (play again between them),
    and a Doppelganger who copies the Minion."""
    t = run.table()
    _v2_lobby(t, SIX)

    # -- the Werewolves win: the table votes out a Villager --------------
    _deal_v2(t, SIX_DEALT, SIX_CENTER, again=False)
    _night_v2(t, SIX, {"Ana": [_player(t, "Cleo")]})
    t.record(
        "game/night_results_seen_v2",
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
        "results_v2_werewolves_win",
        "The table votes out a Villager: no Werewolf dies, the Werewolves win.",
    )

    # -- nobody dies: one vote each ---------------------------------------
    _deal_v2(t, SIX_DEALT, SIX_CENTER)
    _night_v2(t, SIX, {})
    _to_vote(t, SIX)
    _lock_votes(t, {n: SIX[(i + 1) % len(SIX)] for i, n in enumerate(SIX)})
    _record_results(
        t,
        "results_v2_nobody_dies",
        "Every player gets one vote: nobody dies (a Werewolf is at the table, "
        "so the Werewolves win).",
    )

    # -- a tie that kills two ---------------------------------------------
    _deal_v2(t, SIX_DEALT, SIX_CENTER)
    _night_v2(t, SIX, {})
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
        "results_v2_tie",
        "Two players tie on the most votes (two each): both die; one held a "
        "Werewolf, so the village wins.",
    )

    # -- the Hunter chain ---------------------------------------------------
    _deal_v2(t, {**SIX_DEALT, "Fin": "Hunter"}, SIX_CENTER)
    _night_v2(t, SIX, {})
    _to_vote(t, SIX)
    _lock_votes(t, {n: ("Cleo" if n == "Fin" else "Fin") for n in SIX})
    _record_results(
        t,
        "results_v2_hunter_chain",
        "The Hunter is voted out and takes the player he voted for (a Werewolf) "
        "with him.",
    )

    # -- the Tanner dies ----------------------------------------------------
    _deal_v2(t, {**SIX_DEALT, "Dev": "Tanner"}, SIX_CENTER)
    _night_v2(t, SIX, {})
    _to_vote(t, SIX)
    _lock_votes(t, {n: ("Ana" if n == "Dev" else "Dev") for n in SIX})
    _record_results(
        t,
        "results_v2_tanner",
        "The Tanner is voted out under night protocol 2: the Tanner wins.",
    )

    # -- a dead player whose card had moved -------------------------------
    _deal_v2(t, SIX_DEALT, SIX_CENTER)
    _night_v2(t, SIX, {"Ben": [_player(t, "Cleo")]})
    _to_vote(t, SIX)
    _lock_votes(t, {n: ("Ana" if n == "Ben" else "Ben") for n in SIX})
    _record_results(
        t,
        "results_v2_moved_card",
        "The Robber took a Werewolf's card and is voted out holding it: the dead "
        "player's dealt card (Robber) is not their final card (Werewolf); the "
        "village wins.",
    )

    # -- a Doppelganger who copies the Minion -----------------------------
    dealt = {**SIX_DEALT, "Ana": "Doppelganger", "Dev": "Minion"}
    _deal_v2(t, dealt, ["Villager", "Seer", "Insomniac"])
    t.clock.advance(3)
    _choose(t, "Ana", [_player(t, "Dev")])
    t.record(
        "game/me_choose_doppelganger_minion_followup",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in window 1 after she looked at the Minion: her follow-up is "
        "armed (`kind: none`, `chooses_left: 1`); she sends one more choose and "
        "learns the Werewolves when the window closes.",
    )
    _choose(t, "Ana", [])
    for name in SIX[1:]:
        _choose(t, name, [])
    t.clock.advance(7)
    t.fire("{game_id}:wave:1")
    _night_v2(t, SIX, {})
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
    _v2_lobby(t, names)
    _deal_v2(
        t,
        {"Ana": "Werewolf", "Ben": "Seer", "Cleo": "Villager"},
        ["Robber", "Troublemaker", "Villager"],
        again=False,
        settings={"discussion_seconds": 0, "voting_seconds": 0},
    )
    _night_v2(t, names, {"Ben": [_player(t, "Ana")]})
    t.record(
        "game/me_talk_untimed_v2",
        "GET",
        "Ana",
        ME,
        status=200,
        about="/me/ in an untimed talk (`discussion_seconds` 0): no deadline and "
        "no stage start.",
    )
    _to_vote(t, names)
    t.record(
        "game/me_voting_untimed_v2",
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
        "results_v2_three_players",
        "The results of a three-player game: the Seer found the Werewolf.",
    )


def _ten_player_table(run: Recording) -> None:
    """Ten players, the largest table: the talk and the vote."""
    t = run.table()
    names = ["Ana", "Ben", "Cleo", "Dev", "Esme", "Fin", "Gus", "Hana", "Ida", "Jon"]
    _v2_lobby(t, names)
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
    _deal_v2(t, dealt, ["Villager", "Hunter", "Tanner"], again=False)
    _night_v2(t, names, {})
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


def record_all(run: Recording) -> None:
    classic_table(run)
    full_table(run, finished=doppelganger_table(run))
    protocol_two_tables(run)
    results_tables(run)
