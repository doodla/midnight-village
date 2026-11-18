# Backend — Midnight Village

## ONUW Game Domain

Understand these mechanics before implementing any game feature.

**Game flow:** Lobby → Night → Discussion → Voting → Results

**Night phase runs in two windows** (`Game.current_wave` holds the window number: 1 or 2, 0 outside night). `RoleDefinition.wave` is the *order group* (position in the wake order), not a phase of the game; action-log entries are tagged with it so the log stays in wake order.
1. **Window 1 — Doppelganger alone.** Runs whenever the Doppelganger card is in the deck (dealt or in the center), even if nobody can act. It lasts **exactly** `night_doppelganger_window_seconds` (default 10) whatever happens in it (nobody to act, look submitted or not, follow-up or not): one timer is set when it opens, nothing reschedules it, and `phase_deadline` is the real close time. `0` turns the fixed length off: window 1 then closes like window 2. The look resolves and is sent on submit; a follow-up as Seer/Robber/Troublemaker/Drunk/Minion is prompted on submit but resolves when the window closes; anything unsubmitted is skipped.
2. **Window 2 — everyone else at once.** Always runs, even if nobody has a choice. Every actor is prompted together: dealt Werewolves, Minion, Masons, Seer, Robber, Troublemaker, Drunk, Insomniac, and a Doppelganger who copied Werewolf/Mason/Insomniac. Nothing is sent to anyone until the window closes; then the engine resolves, each step seeing the table after the previous one: team views (group 2), Seer -> Robber -> Troublemaker -> Drunk (group 3, Doppelganger before the real role), Insomniac (group 4). Engine entry points: `get_required_actions_for_window`, `resolve_window` (`resolve_night` still takes actions keyed by order group 1-4).
- **Timing (window 2):** a window closes when its last actor submits, but never sooner than `night_min_window_seconds` (default 8) after it opened (the close is scheduled for that moment); `night_wave_seconds` (default 30) is the maximum. Host "advance" closes any window immediately. Timer settings (`night_wave_seconds`, `night_min_window_seconds`, `night_doppelganger_window_seconds`, `discussion_seconds`, `voting_seconds`; and `disconnect_grace_seconds`, 0-60; `host_handover_seconds`, 0-600) are validated in `validate_onuw_settings` (integers 0-3600; min window <= `night_wave_seconds` when that is > 0); `get_timer_seconds` falls back to the default on a bad stored value.
- **Side effects after commit:** every WebSocket send and `timers.schedule/cancel` in the night flow goes through `transaction.on_commit` (`_send_after_commit`, `_schedule_after_commit`, `_cancel_after_commit`), so a rollback leaves nothing sent or rescheduled. Payloads are built inside the transaction. Tests that call these services inside pytest's transaction must use `django_capture_on_commit_callbacks(execute=True)` (or `django_db(transaction=True)`). Timer-thread exceptions are logged by `make_idempotent_callback`.
- **Dealt-card rule:** who wakes as a Werewolf or Mason, who acts in every step, and who a Minion sees is decided by the card DEALT (`state.original_roles`) plus a Doppelganger who copied that role, never the card held mid-night. A stolen Werewolf card does not make the thief a Werewolf; the player it was taken from still wakes (and can be the "lone" Werewolf). Winning is still decided by the card held at the end.
- **Results** are stored per window (`night_action_data["wave_<window>_result"]`); a player gets at most one in window 2.

## Restart, play again, dropped phones, missed results

**ONE SERVER PROCESS ONLY.** Timers (`timers.py`) and presence bookkeeping are per-process, and start-up recovery zeroes every running game's connection counts, so a second server process would stop the first one's timers from being the only ones and would mark live players as gone. Run exactly one ASGI process (`daphne config.asgi:application`, or `manage.py runserver`, which uses daphne). Do not use several gunicorn/uvicorn workers or replicas. Redis in `production.py` is only the channel layer; it does not make timers shareable. Recovery logs one INFO line saying so at every start. (The repo has no Dockerfile, Procfile or deploy config: only `just dev`/`just serve`/`just harness-serve` and CI that runs `just check` and `just test`.)

**Timers survive a restart.** `timers.py` is an in-memory registry (lost with the process); the stored `Game.phase_deadline` / `night_window_opened_at` are the truth. `services.recover_timers()` runs once at server start (`run_startup_recovery()`, called from `config/asgi.py`; it runs in a short-lived joined thread so it works even when the server imports the app inside a running event loop, and closes that thread's DB connections; switched off by `ONUW_RECOVER_TIMERS_ON_START = False` in the test settings, never runs in migrations or management commands, tolerates an unmigrated DB). It resets stale presence (below), opens a night that crashed before its first window, then calls `ensure_timers(game)` for every game in night / discussion / voting. `ensure_timers` re-creates what is missing (`timers.is_scheduled(key)` is the cheap check): the phase or window timer (a deadline that is overdue or less than `RECOVERY_RECONNECT_ALLOWANCE_SECONDS` = 15 s away is first moved to now + 15 s and persisted, so phones can reconnect before the vote is revealed or the night closes; the same happens in the lazy path only when the timer is genuinely missing; the extension depends only on the clock, so the fixed Doppelganger window's length still says nothing about her), the night's deferred "everyone acted, minimum length not passed" close (due at the minimum, not the deadline), and dropped players' grace timers. The Doppelganger window only ever gets its fixed deadline. `GameMeView` calls `ensure_timers` on every fetch, so a game also repairs lazily. Safe in several workers: every callback locks the Game row and checks the phase, and the night callbacks check the window number (`_auto_advance_wave`), so a stale window-1 timer cannot close window 2. A minimum-length (deferred) close re-checks readiness under the lock when it fires (a player treated as gone may have come back); if the window is no longer ready it puts the normal deadline timer back, and a reached deadline always closes. A phase with no deadline (`discussion_seconds`/`voting_seconds`/`night_wave_seconds` = 0) has no timer by design: only the host (or, for the vote, the last voter) moves it.

**Play again.** `Game.lobby` is a ForeignKey (`related_name="games"`); a lobby's current game is its newest (`services.latest_game`). `POST /api/lobbies/<code>/play-again/` (also `/api/onuw/lobbies/<code>/play-again/`, same view, name `lobby-play-again`) is host-only (403), needs the newest game in `results` (409; a repeat while already `waiting` is a harmless 200), sets the lobby `waiting`, sets every member ready, keeps members and settings, and answers with the lobby detail body. `POST .../start/` locks the Lobby row from the status check to creating the Game, so a double tap deals one game. `GET /me/` has `lobby_code` in every phase. After commit: `play.again` on `game_<old id>` (client sees `{"type": "play_again", "lobby_code"}`) and `lobby.update` on `lobby_<code>`. The old game and its results stay readable; `CurrentGameView` skips finished games so nobody is sent back into them. Leaving between games works as before (host leaving deletes the lobby; a non-host leaving may leave the deck mismatched, so the host PATCHes settings before dealing).

**Dropped phones.** `PlayerRole.connections` (open sockets) and `disconnected_at`, changed under row locks (Game row first, then the player) by `register_connection` / `unregister_connection` from `GameConsumer.connect/disconnect`; never below zero. 0 to 1 and 1 to 0 broadcast `player.presence` (client: `{"type": "player_presence", "player_id", "connected"}`); `PlayerListView` has `connected` per player. Setting `disconnect_grace_seconds` (default 25, 0 to 60, 0 = off). When the last socket closes during night or voting a grace timer (`<game>:grace:<user>`) starts; a player disconnected at least the grace period is "gone": the night window may close once every *other* actor has acted (through `_close_or_defer`, so the minimum window length and the fixed Doppelganger window still apply, and the missing player is a timeout), and the vote is revealed once everyone else has voted (the missing player is a non-voter). Discussion never waits. Reconnecting cancels the timer and re-checks readiness. Two deliberate choices: (1) while a player is *inside* their grace period the night window waits for them whether or not they have an action, otherwise the close time would tell the table whether the dropped player was an actor; (2) if every phone is gone nothing closes early (only the deadline or the host). A player never seen connected has no `disconnected_at` and is never treated as gone. On restart every socket is gone, so `recover_timers` zeroes `connections` and stamps `disconnected_at = now` (single-process assumption: a second worker starting while others are live would zero their counts too). Host endpoints (`advance-wave`, `end-discussion`, `reveal-votes`) work with players dropped; there is no host transfer, so a gone host cannot use them (timers still move night and vote; with all timers set to 0 the table waits for the host).

**Host handover.** `Lobby.host` is the owner and never changes; `Lobby.acting_host` (nullable) holds the role while the owner is away. The *effective host* is `acting_host` if set, else `host`; EVERY host-only check calls `Lobby.is_host(user_id)` (start, lobby settings PATCH, advance-wave, end-discussion, reveal-votes, play-again, `is_host` in `/me/`, the debug oracle). Logic lives in `apps/onuw/host.py`. Setting `host_handover_seconds` (default 60, 0 to 600, 0 = off, read from the lobby settings). When the effective host has had no open socket (lobby socket OR newest-game socket; `LobbyMember.connections` / `disconnected_at` count lobby sockets via `LobbyConsumer`, never broadcast) for that long, the first lobby member in join order who is connected becomes the acting host; if nobody is connected nothing happens until someone connects; an acting host who drops for the same period hands on again, never to the absent owner. The moment the owner has a socket the acting host is cleared (no delay). An acting host who *leaves the lobby* passes the role to the next connected member, or to nobody (the role is then back with the owner, reason `returned`); the owner leaving behaves as before (lobby deleted, 409 while a game runs). Event `host.changed` to the lobby group and the newest game's group, only on a real change: clients receive `{"type": "host_changed", "host_id", "host_name", "original_host_id", "reason": "handover" | "returned"}`. Lobby detail: `host` is the effective host (`{id, username, display_name}`), plus `original_host_id` and `is_acting_host`; `/me/` has `host_id` (effective) and `is_host`. Timer key `lobby:<lobby id>:host` (cannot match a game's `<uuid>:` prefix, so the debug fire-timer `current` and `cancel_all_for_game` never see it). Restart recovery resets lobby counts (waiting / in-game lobbies stamped now) and arms the timer, so the owner's minute starts at the restart and nobody is handed the role until someone connects. Lock order is now Game -> PlayerRole -> Lobby -> LobbyMember; host code takes Lobby then LobbyMember and never a Game/PlayerRole lock while holding them, and runs only after the game presence transaction commits.

**Missed night results.** `GET /me/` has `night_results`: the caller's own results for closed windows, `[{"wave", "action_type", "revealed_info"}]`, built from the night log by `services.client_action_result` (the same transform the `action.result` socket event uses) so the two cannot drift. One entry per result in window order (a Doppelganger with a follow-up gets two in window 1), skips omitted, nothing for a window still open (including her early look), nothing of anyone else's.

**Action types:** `peek_player`, `peek_center`, `swap_with_player`, `swap_with_center`, `swap_others`, `see_team`, `none`, `skip` (explicit "do nothing": Seer, Robber, Troublemaker only, including a Doppelganger follow-up as one of them; advertised in the prompt's `action_types`; never for the Drunk, the Doppelganger's first look, or view-only roles)

**v1 roles (12):** Werewolf, Villager, Seer, Robber, Troublemaker, Drunk, Insomniac, Minion, Tanner, Hunter, Mason, Doppelganger

**Win conditions:**
- Village wins if a Werewolf is eliminated
- Werewolves win if no Werewolf is eliminated
- Tanner wins if Tanner is eliminated (overrides village win)
- Hunter kills the player they voted for if Hunter dies
- No werewolves in play → village must NOT vote to kill anyone to win

**Critical edge cases:**
- Player disconnects mid-action → action skipped after timer (or after the grace period if everyone else is done)
- Timer expires with no submission → action skipped
- Doppelganger copies a role with a night action → acts again (Seer/Robber/Troublemaker/Drunk/Minion immediately in window 1; Werewolf/Mason/Insomniac in window 2)
- All votes tied → no one dies
- Robber swaps then Troublemaker swaps the same player → order matters (resolution order within window 2 settles this)

## Silent Failure Modes

- **WebSocket connections require JWT auth.** The ASGI middleware validates tokens. Tests need `WebsocketCommunicator` with an authenticated user scope — unauthenticated connections are rejected silently.
- **Throttle rates must be configured in test settings.** Guest auth endpoints use DRF throttling. If `DEFAULT_THROTTLE_RATES` is missing from test settings, guest creation tests fail with 429s that look like server errors.
- **Error messages must not leak role information.** Validation errors for night actions must use generic messages (target values must be plain JSON integers: anything else is a 400, never coerced) ("invalid action") not role-specific ones ("Seer cannot do that") — the role name itself is hidden information.
- **Night action TOCTOU race.** Concurrent action submissions for the same player must be guarded with `select_for_update()`. Without it, two simultaneous requests can both pass validation and both write.

## Adding a New Role

Requires updates in multiple files — the type system won't catch a missed one:

1. `engine/roles.py` — role definition and metadata
2. `engine/behaviors.py` — night action behavior
3. `engine/night.py` — wave assignment
4. `engine/win_conditions.py` — if the role affects win logic
5. `serializers.py` — if the role has special display rules
6. Tests for each of the above

## Adding a New Django App

The `apps.` prefix in the app name is required and easy to forget:

```python
# apps/myapp/apps.py
class MyappConfig(AppConfig):
    name = "apps.myapp"  # NOT just "myapp"
```

Then add `"apps.myapp"` to `INSTALLED_APPS` in `config/settings/base.py` and create test directories under `tests/unit/myapp/` and `tests/integration/myapp/`.

## Commands

```bash
just test              # pytest (all tests)
just test tests/path/to/test_file.py  # specific file
just test-cov          # pytest with coverage
just test-unit         # Unit tests only
just lint              # Ruff check
just format            # Ruff format
just typecheck         # Pyrefly
just check             # All of the above
```

Pre-commit hooks must be run from the **repo root** (not `backend/`), because `.pre-commit-config.yaml` lives at the root and scopes to `backend/` files via the `files: ^backend/` pattern.

## Debug / Harness (DEBUG-only)

For the integration harness there are `DEBUG`-gated affordances (all 403 in production, each with a rejection test): a forced-assignment / seed override on game start (`GameStartView`), a `debug-state` full-state oracle (its `connected` is real socket presence), and a `debug-fire-timer` hook (`wave:1` / `wave:2` close that night window now; `current` ignores grace timers) — see `apps/onuw/debug.py` + `debug_views.py`. Game timers are per-game settings, so the harness and `tools/game_driver.py` set `night_min_window_seconds`, `night_doppelganger_window_seconds` (and the other timers) to 0 for speed. Boot the harness backend with `just harness-serve` (`config.settings.harness`: `DEBUG=True`, throwaway DB `midnight_village_harness`, `127.0.0.1:8001`). `tools/game_driver.py` is a CLI that drives a whole ONUW game through these. Full docs: `docs/dev/debug-harness/`.
