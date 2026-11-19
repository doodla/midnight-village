"""The games whose payloads become the contract samples.

Three tables, played through the real API (see recorder.py):

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
- ``full_table``: ten players fill a table; the join refusals and the ack from
  someone who does not play in the game.

Adding a situation: drive it here with ``table.record`` / ``table.record_event``,
run ``just samples`` and review the new files.
"""

from __future__ import annotations

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
    # Everyone has acted; the window closes at its minimum length.
    t.clock.advance(8)
    t.fire("{game_id}:wave:2")
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
    _sign_in(t, list(dealt))
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
        "debug/state",
        "GET",
        "Ana",
        "/onuw/games/{game_id}/debug-state/",
        status=200,
        about="The DEBUG-only oracle (dev toolbar and harness).",
        debug=True,
    )
    t.record(
        "debug/fire_timer_none",
        "POST",
        "Ana",
        "/onuw/games/{game_id}/debug-fire-timer/",
        {"key": "wave:2"},
        status=200,
        about="The DEBUG-only timer hook when no such timer is pending.",
        debug=True,
    )
    return t


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


def record_all(run: Recording) -> None:
    classic_table(run)
    full_table(run, finished=doppelganger_table(run))
