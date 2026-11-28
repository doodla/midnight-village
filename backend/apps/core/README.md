# apps.core: shared table infrastructure

Lobbies, sockets, presence, host handover, play again, tokens and durable timers: the parts
any game uses. `apps.core` imports no game app (a test scans its source). The ONUW side is in
`backend/apps/onuw/README.md`; running on Vercel in `docs/dev/deploy-vercel.md`. Keep this file true
when you change the code it describes.

## Sign-in (`auth.py`, SimpleJWT)

Guests sign up with `POST /api/auth/guest/`; an access token lives 60 minutes, a refresh
token 7 days. `POST /api/auth/token/refresh/` rotates the refresh token (the week slides with
use) and does NOT blacklist the used one (`BLACKLIST_AFTER_ROTATION = False`): a renewal whose
answer was lost (a slow server, two tabs) is sent again with the same token and must still
work, or the phone loses its seat. The blacklist app stays installed for an explicit
`POST /api/auth/logout/`. One rule for an account that is gone (deleted, inactive): 401, on
the refresh (`AccountTokenRefreshView`: "User not found", as a read says it, where SimpleJWT's own answered 500)
as on any authenticated read; the app starts afresh on a 401 and asks again on anything else
(`backend/tests/core/test_auth.py`, `contract_samples/http/auth/token_refresh_user_gone.json`, `user_gone.json`, `user_gone_game_me.json`).

## How many server processes?

Depends on `ONUW_TIMER_BACKEND`. With `"vercel_queue"` (Vercel; `backend/config/settings/vercel.py`) there is NO per-process state:
timers are rows fired by queue messages, presence is rows with heartbeats, nothing resets or re-arms at start-up, so any number of instances may start and stop
at any time (`docs/dev/deploy-vercel.md`).
With `"memory"` (default: dev, tests, harness, `just dev`) still run ONE process:
its timers are `threading.Timer`s in that process
(the rows make them survive a restart, but a timer armed in process A is lost with A until a restart re-arms it, and a second process would not know about A's timers),
and `recover_timers` re-derives and re-arms at start-up.
Redis in `production.py` is only the channel layer.
Recovery logs one INFO line about it at every start.
(The repo has no Dockerfile or Procfile: `just dev`/`just serve`/`just harness-serve` and CI.)

## Where things live (principle 6)

`apps.core` is shared infrastructure and imports NO game app (a test scans its source):
lobbies, `LobbySocket` rows and the lobby consumer, host handover (`backend/apps/core/host.py`), play again (`backend/apps/core/lobbies.py`), the after-commit helpers
(`backend/apps/core/effects.py`; one `send_after_commit` call is one batch, which the live server's channel layer, `backend/apps/core/channel_layer.py`, sends in two Redis round trips whatever it holds, in order for every socket),
a JSON parser that answers a body nested too deep with a 400, not a 500 (`backend/apps/core/parsers.py`, every view's; `backend/tests/core/test_open_routes.py` sends hostile bodies to every route),
the `Server-Timing` header every answer carries (CORS exposes it to the web app, whose field recorder splits a round trip with it)
(`backend/apps/core/server_timing.py`: on the live server only how long the request took to get its database connection, when it made one, and the total rounded to 50 ms, because round-trip and message counts can depend on other players' hidden moves (`backend/tests/perf/test_header_hides_play.py`); with `SERVER_TIMING_DETAIL`, on in development, the harness and the tests, also its database round trips, socket and timer messages and each part's time),
durable timers (`backend/apps/core/timers.py`, `ScheduledTimer`, the queue subscriber `backend/apps/core/queue_worker.py`) and generic presence (`backend/apps/core/presence.py`).
A game app plugs in through `backend/apps/core/games.py`:
`GameHooks` registered per `Lobby.game_type` from `AppConfig.ready`
(`backend/apps/onuw/hooks.py`: settings validation, the newest game's socket group, who is connected to it, when its players were noticed gone, whether it is finished, which game a member plays in: `member_game`)
plus `timers.register_job_module` and `presence.register_scope`.
ONUW keeps the game: `Game`, `PlayerRole`, `SocketPresence` (GAME sockets only), its services and its timer jobs.

## Durable timers (`timers.py`)

A timer is a named job with JSON params stored in `ScheduledTimer` (unique `key`, random `token`, `due_at`, `job`, `params`):
`timers.schedule(key, delay, job, params)` upserts the row with a fresh token and arms the backend;
`cancel(key)` deletes the row; `cancel_all_for_game(game_id)` deletes by `"<game id>:"` prefix;
`is_scheduled(key)` checks the row (memory: also that a thread is armed in this process; queue: also not overdue by more than 120 s).
Handlers register with `@timers.job("name")`:
`night_window` (deadline AND the deferred minimum-length close, `deferred` param), `discussion_deadline`, `voting_deadline`, `grace_expired`, `host_handover`,
`presence_check`. Callers still schedule after commit (`basics._schedule_after_commit(key, delay, job, params)`).
`timers.fire(key, token)` is the one runner for every backend:
it locks the row, runs only if it still exists with that token and is due
(2 s of clock skew tolerated; earlier = "early", the subscriber re-sends with the remaining delay), deletes the row in the SAME transaction and runs the job
inside it, so a stale token, a cancelled key or a duplicate delivery does nothing and two instances cannot both run it;
the handlers' phase / window checks are a second guard.
A job that FAILS must raise: every real job logs and re-raises
(`make_idempotent_callback(..., reraise=True)`, `_grace_expired`, `_handover_due`, the presence check), so `fire` rolls back and the row survives for a retry
(memory backend: `_thread_fire` retries after `RETRY_DELAY_SECONDS` = 5, at most `MAX_ATTEMPTS` = 5 times; queue backend: the worker raises the SDK's `RetryAfter(15 s)` until `delivery_count` reaches 5, then drops the message and leaves the row for the sweep).
`run_job_quietly` is for tests' fake schedulers only.
**Lost firings:** the row records `published_at` (set only after the queue send returned / the thread was armed) and `scheduled_at`;
under the queue backend a row unpublished for more than 5 s is NOT `is_scheduled`, so the lazy `ensure_timers` re-publishes it, and `timers.sweep(prefixes)`
re-sends (SAME token; a duplicate is harmless) unpublished rows and published rows more than 5 s past due (at most every 30 s per row);
under the memory backend it re-arms threads this process lacks.
`GET /me/` sweeps its own game (`recovery.timer_prefixes`);
`GET|POST /api/onuw/internal/sweep-timers/` sweeps everything for a platform cron and answers 403 unless `Authorization: Bearer <CRON_SECRET>`
(setting `ONUW_CRON_SECRET`, env `CRON_SECRET`) matches (no secret configured = always 403).
**Clocks:** `due_at`, `scheduled_at`, `published_at`, `last_seen` and every freshness / due comparison use the DATABASE clock (`Now()`), never an instance
clock. Backends: `memory` = `threading.Timer(key, token)`;
`vercel_queue` = delayed message `{key, token}` (`vercel.queue` imported lazily, optional extra `vercel`) handled by `backend/apps/core/queue_worker.py`
(registered as `[[tool.vercel.subscribers]]`).
The debug `fire-timer` claims the row with `fire(..., force=True)`;
`current` ignores `:grace:` keys, and the `lobby:` / `presence:` keys never match a game's prefix.

## Play again

(The generic part, `backend/apps/core/lobbies.py`: host check, reopen, events, asks the game hooks whether the newest game is finished.) `Game.lobby` is a ForeignKey
(`related_name="games"`); a lobby's current game is its newest (`services.latest_game`).
`POST /api/lobbies/<code>/play-again/` (also `/api/onuw/lobbies/<code>/play-again/`, same view, name `lobby-play-again`) is host-only (403), needs the newest
game in `results` (409; a repeat while already `waiting` is a harmless 200), sets the lobby `waiting`, sets every member ready, keeps members and settings, and
answers with the lobby detail body. `POST .../start/` locks the Lobby row from the status check to creating the Game, so a double tap deals one game, and opens
the first night window in that same transaction (side effects after commit), so there is never a committed night without a window;
a night still at window 0 more than `NIGHT_START_STUCK_SECONDS` (15) after creation is opened by the lazy `ensure_timers` (`GET /me/`);
a younger one is left to its starter. `GET /me/` has `lobby_code` in every phase.
After commit: `play.again` on `game_<old id>` (client sees `{"type": "play_again", "lobby_code"}`) and `lobby.update` on `lobby_<code>`.
The old game and its results stay readable;
`CurrentGameView` skips finished games so nobody is sent back into them.
Leaving between games works as before
(host leaving deletes the lobby; a non-host leaving may leave the deck mismatched, so the host PATCHes settings before dealing).

## Dropped phones (presence)

Presence is one row per open socket
(`SocketPresence` for a game socket, `core.LobbySocket` for a lobby socket: `user`, the game or lobby, unique `channel_name`, `connected_at`, `last_seen`),
never a counter and never reset at start-up.
`GameConsumer`/`LobbyConsumer` insert the row on connect, delete it on disconnect and refresh `last_seen` every `ONUW_PRESENCE_HEARTBEAT_SECONDS`
(15; an asyncio task per consumer; each beat is a short non-thread-sensitive DB call that releases its connection; `disconnect` cancels the task and waits for it, and a beat in flight finishes first, however often the task is cancelled, so it cannot write the row back after `disconnect` deletes it).
A user is *connected* in a scope while a row has `last_seen` newer than `ONUW_PRESENCE_STALE_SECONDS` (40) (`presence.fresh_rows`, `connected_user_ids`).
**Silent deaths** (instance killed, no `disconnect`):
when a row is created or refreshed a durable `presence_check` timer (key `presence:<game|lobby>:<id>:<user>`, one pending per scope+user) is ensured, due at
`last_seen + stale`; a heartbeat writes no timer, the check re-arms itself when it fires early (about one timer write per staleness period), and when it fires
on a user with no fresh row it deletes the stale rows
(the healthy path, a fresh row, takes NO Game/Lobby lock: it only re-arms; the stale path re-checks under the usual locks) and runs EXACTLY the clean
last-socket path (`game_presence._game_went_offline` / `host._lobby_went_offline`).
The "gone since when" stamps stay as `PlayerRole.disconnected_at` and `LobbyMember.disconnected_at`
(set when noticed, cleared on coming back; a silent death starts its grace clock when noticed, not at the last beat).
Transitions are under row locks (Game then PlayerRole; Lobby then LobbyMember) in `register_connection` / `unregister_connection` / `refresh_connection` /
`check_game_presence` and `host.register_lobby_connection` / ...
. 0 to 1 and 1 to 0 broadcast `player.presence` (client: `{"type": "player_presence", "player_id", "connected"}`);
`PlayerListView` has `connected` per player (fresh rows).
Setting `disconnect_grace_seconds` (default 25, 0 to 60, 0 = off).
When the last socket goes during night or voting a grace timer (`<game>:grace:<user>`) starts;
a player disconnected at least the grace period is "gone":
the night window may close once every *other* phone with a choice has chosen
(through `_close_or_defer`, so the minimum window length and the fixed Doppelganger window still apply, and the missing player is a timeout), and the vote is
revealed once everyone else has voted (the missing player is a non-voter).
Discussion never waits. Reconnecting cancels the timer and re-checks readiness.
Two deliberate choices: (1) while a player WITH a choice is *inside* their grace period the night window waits for them;
a dropped player with nothing to choose holds nothing
(a phone with nothing to choose is never waited for; who acts is an accepted tell, first time play spec, section 8);
(2) if every phone is away (gone, or dropped inside its grace period) nothing closes early (a phone coming back, the deadline or the host).
A player never seen disconnected has no `disconnected_at` and is never treated as gone.
Host endpoints (`advance-wave`, `end-discussion`, `reveal-votes`) work with players dropped;
a gone owner is replaced by host handover (below).

## Host handover

`Lobby.host` is the owner and never changes;
`Lobby.acting_host` (nullable) holds the role while the owner is away.
The *effective host* is `acting_host` if set, else `host`;
EVERY host-only check calls `Lobby.is_host(user_id)`
(start, lobby settings PATCH, advance-wave, end-discussion, reveal-votes, play-again, `is_host` in `/me/`, the debug oracle).
Logic lives in `backend/apps/core/host.py`. Setting `host_handover_seconds`
(default 60, 0 to 600, 0 = off, read from the lobby settings; the same limits are validated by `backend/apps/onuw/engine/validation.py`).
When the effective host has had no open socket (a fresh lobby socket row OR a fresh newest-game socket row; lobby presence is never broadcast) for that long,
the first lobby member in join order who is connected becomes the acting host;
if nobody is connected nothing happens until someone connects;
an acting host who drops for the same period hands on again, never to the absent owner.
The moment the owner has a socket the acting host is cleared (no delay).
An acting host who *leaves the lobby* passes the role to the next connected member, or to nobody (the role is then back with the owner, reason `returned`);
**the owner leaving** is refused while a game runs (409);
otherwise, if anyone else is in the lobby, the table is NOT deleted:
ownership moves for good to the next member in join order (a connected one preferred), `acting_host` is cleared, the leaver's membership and sockets go, and
`host.changed` goes to the lobby and the newest game's group with reason `transferred`
(`host_id` == `original_host_id` == the new owner; finished games stay readable by those who remain).
Only the last member leaving deletes the lobby.
Event `host.changed` to the lobby group and the newest game's group, only on a real change:
clients receive `{"type": "host_changed", "host_id", "host_name", "original_host_id", "reason": "handover" | "returned", "rev"}`
(`rev`: `_announce` bumps the table's number, below; both consumers forward the key when the event has it).
Lobby detail: `host` is the effective host (`{id, display_name}`), plus `original_host_id` and `is_acting_host`;
`/me/` has `host_id` (effective) and `is_host`.
Timer key `lobby:<lobby id>:host`
(job `host_handover`; cannot match a game's `<uuid>:` prefix, so the debug fire-timer `current` and `cancel_all_for_game` never see it).
Nothing is reset at a restart: the owner's rows go stale, the presence check notices (stamping `LobbyMember.disconnected_at`) and the owner's minute starts
then; nobody is handed the role until someone is connected.
Lock order is now Game -> PlayerRole -> Lobby -> LobbyMember;
host code takes Lobby then LobbyMember and never a Game/PlayerRole lock while holding them, and runs only after the game presence transaction commits
(a silent-death check schedules `host.game_presence_changed` with `_after_commit`).
The owner leaving locks the Lobby row first, so a concurrent presence check waits, then finds the lobby gone (or the new owner) and does nothing.

## Tokens, seats, deal snapshot

Each `LobbyMember` has a `token`
(`backend/apps/core/tokens.py`: ten ids, a permutation seeded by the lobby code, the first free one is taken at join / create by `lobbies.add_member` under the Lobby row lock, logged at INFO; capacity is checked there too, so the join is atomic: `max_players`, or less when the game says the table takes fewer now, `GameHooks.seat_limit`, ONUW's `settings.seats`; every join refusal has a `code`: `lobby_not_found` 404, `already_in_lobby`, `lobby_closed`, `lobby_full` 400; `max_players` is capped at create by the token count, `core.tokens.MAX_TABLE_SIZE` = 10, the one home of the limit; the game checks its own 3 to 10 when it deals).
The token is freed when the member's row is deleted and stays across play again.
`GameStartView._deal` validates everything first
(a refusal returns inside `atomic()`, which would COMMIT earlier writes, so `post` also calls `transaction.set_rollback(True)` on one), then gives a blank token
to any member who has none (`lobbies.ensure_tokens`: rows made by code from before tokens), then `_snapshot_player_roles` copies token and seat (join order)
into `PlayerRole.token` and `.seat`, and the dealt center goes to `Game.dealt_center_cards` (`Game.center_cards` is overwritten by the night).
`PlayerRole` orders by `(seat, user_id)`;
every players list uses `serializers.player_identity`.
`PlayerRole.phase_ready` and `night_results_seen` exist for later slices (`api-contract-v2.md`).

## Where am I (`GET /api/me/table/`)

`GET /api/me/table/` (`core/lobbies.current_table`, view `MyTableView`) starts from MEMBERSHIP, not from games:
the caller's newest-joined `LobbyMember` whose lobby had activity within `CORE_TABLE_RESUME_HOURS`
(default 12; `Lobby.updated_at`, which create, join, leave, settings, deal, finish, play again and host changes all bump, via `save()` or `lobbies.touch`; an `in_game` table nobody finished expires too).
It answers `{"table": {"lobby_code", "game_type", "status", "is_host", "token", "game": {"game_id", "phase"} | null}}` or `{"table": null}`;
`game` comes from `GameHooks.member_game(lobby, user_id)`
(the lobby's newest game if the caller plays in it, so after "play again" the lobby is `waiting` while `game` is still the old results game).
The client routes: `game.phase != "results"` -> the game, `status == "waiting"` -> the lobby, `finished` -> the results.
`CurrentGameView` is unchanged.

## Home extras and lobby settings

`GET /api/stats/online/`
(`OnlineStatsView`, no login, `authentication_classes = []`, its own throttle scope `online_stats` = 600/min so the home screen cannot eat guest sign-up's `sign_up` budget; `Cache-Control: public, max-age=15, s-maxage=15`, which PERMITS 15 s reuse by browsers and shared caches and guarantees nothing more: whether a CDN honours it is the platform's choice. **the two request limits (`backend/apps/core/throttles.py`) count per client address: the connection's, or on Vercel the header Vercel itself writes (`CLIENT_ADDRESS_HEADER`), never a header a caller can make up. They count in the default cache, a per-process LocMem cache, so on Vercel every instance has its own count: see `docs/dev/deploy-vercel.md`, "Request limits"**)
answers `{"players", "tables"}`: distinct users and lobbies with a FRESH socket row on the database clock
(`backend/apps/core/online.py`: core's `LobbySocket` rows plus the sources a game app registers with `online.register_online_source`; ONUW registers `presence.online_sockets` for `SocketPresence` in `AppConfig.ready`).
It counts sockets, so someone on the home screen is not counted:
label it "players at tables". `GET /api/onuw/me/recent-games/?limit=` (default 5, 1..10) lists the CALLER's games in `results`, newest first:
`{game_id, ended_at (Game.updated_at), player_count, winning_teams, you_won, token, seat}`;
no lobby code, nothing about others. `PATCH /api/lobbies/<code>/` MERGES the given `settings` keys over the stored ones
(shallow: a key given again is replaced whole), under the Lobby row lock, host only, 409 `lobby_in_game` while a game runs
(a finished table may change the deck for the next game), 400 if `settings` is not an object, and the game's validator checks the MERGED result
(nothing is stored if it refuses; the deck-against-player-count check runs only when `roles` is in the PATCH, via the hook's `changed` keys, so a pace-only PATCH is not refused because a player joined; the deal checks again);
there is no way to delete a key, send its default.
**A late tap (`asked`, `backend/apps/core/asked.py`, issue #16):** a PATCH may carry `"asked": <int>`
(the phone's tap time in ms, rising per phone; anything else that is not a plain non-negative integer is 400 `bad_request`).
`Lobby.asked` keeps, per settings key, `[user_id, asked]` of the newest request that set it;
under the Lobby lock a given key whose entry is this user's with a GREATER `asked` is dropped before the merge and the check
(an equal one is the same tap again; another user's entry, after a handover, is never compared).
Every key dropped: 409 `stale_request` with `newest` (the largest stored `asked` among them, the caller's own; `asked.stale_response` builds every stale body),
nothing stored or sent. The key is the player, not the phone:
a second phone with its clock behind is refused until it sends above `newest`.
Without `asked` nothing is compared or noted.
`pace` (`quick`, `normal`, `long`, `custom`) is validated if present and never read by the server.
The ready toggle is refused while a game runs (409 `lobby_in_game`) and takes the Lobby lock like the deal.

## The table before the deal (games that opt in)

A game opts a table in with `GameHooks.shows_table_extras(lobby)`
(settings only, cheap; ONUW: every table; a game that opts nothing in is answered without them).
For such a table `LobbySerializer` adds the game's keys (ONUW: `deck_preview`, `deal`, `backend/apps/onuw/README.md`) and, per member, `connected`
(`lobbies.connected_members`: a fresh lobby socket, a socket on the newest game, or a phone that went away less than `GameHooks.presence_grace_seconds` ago, ONUW's `disconnect_grace_seconds`; a member never seen with a socket is not connected).
The table hears `lobby_update` (the whole body, `lobbies.announce_lobby`, after commit) when a member joins or leaves, when a phone comes back after being SHOWN
as gone
(`register_lobby_connection` 0 to 1; a phone back inside its grace, a flapping one, sends nothing; the pending check is replaced by a staleness check then, so a silent death right after a blip is noticed on time)
and when a dropped phone's grace period ends:
`_lobby_went_offline` arms the existing durable `presence_check`
(same key and job, no new job name, so an older instance that gets it simply finds no socket and does nothing) for the end of the grace, and when it fires with
no socket row left `_announce_if_dropped` re-checks under the Lobby lock
(back already, left, or reachable on the game socket: nothing; fired early: re-armed for the rest).
The grace is measured on the instance clock, as `disconnected_at` is written.
Not secret: who is at the table is shown at the table.
**One table at a time (joins of opted-in tables only):** `POST /lobbies/<code>/join/` answers 409 `{"detail", "code": "already_at_table", "lobby_code"}` when
the caller is a member of ANOTHER table that is WAITING (`lobbies.other_active_table`, with activity within `CORE_TABLE_RESUME_HOURS`).
Only waiting tables count because any member, the owner included, can always leave one (200), so the refusal never traps anyone;
a table in a game (whose owner cannot leave) or finished does not block a join, and `/me/table/` routes people back to a running game.
The join locks the User row first, then the Lobby (lock order User, Lobby), so two joins by one user to two tables cannot both pass.
Checked after `already_in_lobby` and `lobby_closed`, before `lobby_full`.

## The lobby's number (`Lobby.rev`)

Every lobby body has `rev`, an integer that starts at 0 and only rises, so a phone can tell
an older body from a newer one whatever order they arrive in (the rule it follows:
`docs/specs/onuw/api-contract-v2.md`, section 2). **Telling is the bump.**
`lobbies.told_body(lobby)` is the one way to build a body told to anyone because of a
change: it raises `rev` by one (`lobbies.bump_rev`: an UPDATE on the lobby row, which takes
or waits for the row lock, so numbers follow commit order), then re-reads the WHOLE row under
the lock its UPDATE took and builds the body from that, inside the caller's transaction: a
body is never numbered ahead of its content, even from a copy the caller loaded earlier. A
caller saves its own changes before telling (unsaved ones on the instance are dropped by the
re-read; every caller does). `announce_lobby`
calls it and returns the body, so a request that answers and sends `lobby_update` (join,
practice) bumps once and gives both one number; the settings PATCH and play again use
`told_body` the same way. A change the table hears about without a body bumps alone:
`host._announce` (`host_changed` carries the new `rev`), the deal (`backend/apps/onuw/views.py`)
and a game's end (`backend/apps/onuw/voting.py`, in the UPDATE that sets `finished`). A request
that is refused or tells nobody (a stale `asked`, a repeated play again) does not bump; a
plain read (GET, the create answer) shows the `rev` of the row it loaded. A request that
changes the host and the members tells twice and bumps twice (`host_changed`, then the
`lobby_update` with the next number): the owner leaving with others there, an acting host
leaving, the owner's phone back after being shown as gone. Presence is not a write:
`connected` may differ between two bodies with one `rev`.

## Practice players (`practice.py`)

Computer-filled seats, so one person can try a whole game alone. A practice player is an
account the server makes for one table: a guest whose username starts with `practice-`
(guest sign-up only makes bare uuids, and the account has no password), so no phone can sign
in as one and nothing a host sends can make a person one. That username is the one mark.

- `POST /api/lobbies/<code>/practice/` (`LobbyPracticeView`; host, waiting table, a game
  whose `GameHooks.practice_seats` says so): `{"on": bool}` switches them on or off for the
  table (`settings.practice`; off takes every one away and drops the key), `{"count": n}` sets
  how many sit (a target: a request sent twice leaves the table as once; above 0 switches
  them on). Either or both; answers the lobby body and sends `lobby_update`. 400
  `bad_request` (a non-bool `on`, a `count` that is not a plain non-negative integer, or
  neither), 400 `lobby_full` (past the free seats; nothing changes), 403 not the host, 404
  `lobby_not_found` (also for a game with no practice players), 409 `lobby_closed` once dealt.
  An optional `asked` works as the settings PATCH's, for the whole request under the one key
  `Lobby.asked["practice"]` (the PATCH strips `practice`, so it never writes that key): an
  older one is 409 `stale_request`, checked after `lobby_closed` and the host check and
  before the count is tried (so a stale ask for too many is `stale_request`, not `lobby_full`).
- They sit through `lobbies.add_member` like anyone (tokens, `seats`, `max_players`), named
  from a fixed list of village things (`NAMES`: "Scarecrow", "Teapot", ...; the first not
  taken at the table), so an older app that shows no tag still reads them as not people.
  Each brings its own seat token, the thing it is named for (`practice.token_for`:
  "teapot" for Teapot, through `lobbies.add_member(token=...)`), outside the people's ten
  (`tokens.TOKENS`), so a practice player never takes a person's token; an app that does
  not know one draws a plain disc.
  Lowering the count takes the newest away; its account is deleted unless it played a game
  at the table (`GameHooks.played_user_ids`: its results keep it until the table goes).
- The lobby body (`practice.body_extras`, from `LobbySerializer`): each practice member has
  `practice: true` and is always `connected` (no phone to drop); a table that switched them
  on or has some seated also has `practice: {"most": n}` (seated plus free seats, the
  stepper's top). A table that never used them is answered exactly as before.
- **Never host, never hold a table open alone.** `host._Presence.members` holds the PEOPLE
  only, so neither a handover nor the owner leaving (`transfer_ownership`) can pick one; the
  owner leaving with only practice players left closes the table (`practice.close_table`).
  A person joining a full table takes the newest practice player's seat
  (`practice.make_room`, in `LobbyJoinView`).
- **Accounts never pile up.** A table owns its practice accounts
  (`practice.owned_account_ids`: seated now, or holding a seat in one of its games), and
  closing the table deletes every one of them with the lobby and its games, those that
  played and got up included. Nothing sweeps tables on a clock (no cron on Vercel), so the
  number is BOUNDED instead: **a person has practice players at one table at a time.**
  Switching them on (`LobbyPracticeView`, which locks the table with the caller's other
  tables in one statement, primary-key order) and starting a new table
  (`LobbyCreateView`) first run `practice.clear_elsewhere`: every other table the person
  owns or acts as host for that is not in a running game loses its practice players and
  its switch (`lobby_update` to it), and the accounts nothing kept points at are deleted
  (a finished game's results keep theirs until that table goes). So at any moment a person
  accounts for at most one table's practice seats, plus those their finished games hold.
- `settings.practice` is the endpoint's alone: the settings PATCH and a new table's settings
  drop the key (`practice.strip_setting`), so they never set or clear it.
- No migration: the mark is the username, the switch a settings key.
- Who plays them is the game's business (ONUW: `backend/apps/onuw/practice.py`).
