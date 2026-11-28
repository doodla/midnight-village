# Backend tests

`just test` runs pytest (built from the models, `--nomigrations`) and then the migration
tests in a second pass (`just test-migrations`). `just test tests/path/test_x.py` runs one
file (first pass only). Conventions: descriptive names, every random choice seeded,
multi-player scenarios. Coverage minimum 80% (`pyproject.toml`).

**Scanning the repo.** A test or check that reads the repo's files takes them from
`tool/repo_files.py` (`checkout_files(folder, suffixes=...)`, on pytest's path through
`pythonpath`): the files git tracks plus new files git does not ignore, never a folder
walk. A builder's worktree copy under `.claude/worktrees/` (gitignored) or `__pycache__`
is therefore never read.

## Side effects after commit, and timers in tests

Every WebSocket send and `timers.schedule` / `cancel` in the night flow goes through `transaction.on_commit`
(`_send_after_commit`, `_schedule_after_commit`, `_cancel_after_commit`), so a rollback leaves nothing sent or rescheduled.
Tests that call these services inside pytest's transaction must use `django_capture_on_commit_callbacks(execute=True)` (or `django_db(transaction=True)`).
The autouse fixture makes `timers.schedule` a no-op;
`make_night` (`backend/tests/onuw/conftest.py`) records `(key, delay, callback)` instead, where calling the callback runs the job;
tests that need real rows/threads use `@pytest.mark.uses_timers` and, for the queue backend, `timers.set_queue_sender(fake)` +
`queue_worker.handle_message(payload)`. A test with real memory-backend threads waits for the thread itself
(`backend/tests/timer_threads.py`: `settle(key)` follows re-arms, `join(thread)` for one already cancelled or replaced), never a fixed sleep and never the job's side
effect: the job runs inside the transaction that claims and deletes the row, so its effect shows before that deletion commits.
A timer the test must cancel or replace first is scheduled far off (an hour), so a slow machine cannot fire it before the test gets there;
due times are written with the database clock (`Now()`).

## Traps

- **WebSocket connections require JWT auth.** The ASGI middleware validates tokens.
  Tests need `WebsocketCommunicator` with an authenticated user scope — unauthenticated connections are rejected silently.

- **Throttle rates must be configured in test settings.** Guest auth endpoints use DRF throttling.
  If `DEFAULT_THROTTLE_RATES` is missing from test settings, guest creation tests fail with 429s that look like server errors.

## What a tap costs the server (`backend/tests/perf`)

`tap_costs.play` plays one whole game the way the app does (a `v2` table, every phone
reading `/me/` and `/me/table/`, real access tokens, the queue timer backend the live
server runs, a forced deal where every seat holds a card that wakes) at 3, 6 and 10 seats,
on the contract recorder (`backend/tests/contract/recorder.py`), then a second hand by play again
with a Doppelganger who copies the host's Seer and looks in window 1 while the host moves
every stage on itself (move on in both windows, end the talk, reveal the votes); it
measures every request, timer
firing and game socket opening: database round trips, row locks and how long the first is
held, socket messages and the Redis round trips they cost on the live server before the
answer leaves (`redis_trips`: 2 per batch, one `send_after_commit` call; each person's own view as a stage opens is
counted apart, `own_views`, held to one per person and riding in the same batch;
`backend/apps/core/channel_layer.py`) and timer messages (a queue send each). `test_tap_query_budget.py` holds two rules:
nothing costs more at ten seats than at three (a query per player fails, whatever the
budget), and at ten seats each kind of request costs exactly what `tap_budget.json` says and
never more than 40 round trips. A change that adds or removes a query fails until
`just tap-budget` re-records the file; review its diff as you would a sample's. `just
server-timing` prints the whole table (`just server-timing sql`: every query at ten seats).
Not played there: leave, practice players, the night results ack, the token refresh.
`test_header_hides_play.py` holds the rule that nothing in an answer varies with game state
the caller cannot see, for the `Server-Timing` header: the host's answers in two games that
differ only in what the Doppelganger did carry the same live header (rounded time aside), and
with the header's detail on they would not.

The live server's channel layer is tested against a real Redis:
`backend/tests/core/test_channel_layer.py` uses `REDIS_TEST_URL` (GitHub's backend job sets it),
else starts a `redis-server` from the PATH on a free port, else is skipped (never on CI,
where `CI` is set: there it fails instead).

## What a seat is told (`backend/tests/privacy`)

`test_two_deals.py` (a guard) plays one scripted game twice, seat for seat, through the real
API, the second game changing one thing the viewer must not know: two other seats' cards, the
cards of the seat whose pick lands on the viewer (a Robber takes the viewer's card in one game
only), a seat's card against a centre card, the centre's order (for a viewer that picks from
the centre), the card a pick of the viewer's that reads nothing lands on (a Troublemaker's
swap, the Drunk's take, a Doppelganger copying either), or another seat's first vote (onto
the viewer, or off it). Everything the viewer is told must be byte-identical: each answer it
gets (status, headers, body, errors), each frame its lobby and game sockets send, and an
answer from every route of the urlconf at every stage (GET; while voting also POST, PATCH and
DELETE, each undone after). The sockets are the viewer's real consumers (`sockets.py`): their
own `connect` (the groups they join, what they send at once, the first beat), every group
message to a group they joined, through their own handlers, and one heartbeat at each stage.
They run in the test's own thread through `async_to_sync`, so their database work uses the
test's connection and sees its transaction (Channels' closing of old connections around it is
switched off there); only the heartbeat's timer is not theirs: one beat is driven per stage.
What a seat may rightly learn is stated once in `two_deals.py`, from the action type of each
pick: a look or a robbery reads the card picked, a swap of two others or a blind take from the
centre reads nothing. A scripted move the server refuses, or a case whose two games did not
differ as it claims (checked from the database), is a `ScriptError`, not the comparison: only
the comparison failing says "learns", and only that kills a break (`expect="learns"`). Cases
come from `ROLE_REGISTRY`: each role a viewer and a changed card; each kind of change at one
table size (seat swaps at nine seats, the rest at seven); a role with no night action has
one case, the sleepers taking the kinds in turn. Each game runs in a savepoint that is undone,
so both start from the same ids; the Server-Timing detail is read from the live settings
(`backend/config/settings/vercel.py`). Its breaks (`tool/breaks_server.py`, L1 to L14) are the leaks
two reviews found it missed; X4 (every unlocked vote refused, no leak) must come out "broken".

## Migration tests

`backend/tests/test_migrations.py` (marker `migration`) applies the REAL migrations (the rest of the suite uses `--nomigrations`, where these tests skip), seeds
old-shape rows through the historical models, migrates forward, asserts, runs the old code's INSERTs (`backend/tests/old_code.py`, never add columns to them), then back
and forward again. Add a case per migration.
`backend/tests/test_migration_rules.py` scans every migration file for app imports and the `lock_timeout` first operation.
The rules themselves: `docs/dev/deploy-vercel.md`, "Deploy-safe changes".

## Contract samples (`backend/tests/contract`)

`backend/tests/contract` records what the server sends, for the app's tests:
`scenarios.py` first plays three tables made without `defaults` (no look stage):
a classic six-player game with the default timers
(sign-in, lobby set-up and every lobby event, the deal and its refusals, the night closed by the harness's timer hook, the talk, a vote with a Hunter chain, "where am I" in every state, the night results ack, recent games and online stats, most error bodies);
an untimed eight-player game with a Doppelganger
(window 1, the host closing window 2, host handover, the host's reveal with abstentions, the night timeline, the oracle), then a second game there by play again
(she copies a Werewolf; a dealt Tanner dies);
a full ten-player table for the join refusals through the real API
(`recorder.Table`: DRF test client against the URL conf; a `RecordingLayer` channel layer whose group messages are turned into client frames by the consumers' own handlers; on-commit effects run per request; real timer rows with no thread, `is_scheduled` = the row exists, fired by claiming the row; clock frozen at a past date, user ids from 1, fixed lobby codes and forced-deal seed; game ids, guest usernames and tokens replaced by stable stand-ins).
Each socket sample's index entry has `group` (`player` or `broadcast`) and `recipients`;
`test_contract_privacy.py` fails if any per-player night event is recorded at all, or a game broadcast before the results names a role.
`test_contract_samples.py` writes them to `contract_samples/` at the repo root with `UPDATE_CONTRACT_SAMPLES=1` (`just samples`) and otherwise fails, with a
diff, if the committed files differ. A new endpoint, event or situation is a `table.record(...)` / `table.record_event(...)` line in `scenarios.py`, then
`just samples`. A payload change shows up as a diff of the samples (review it), and may fail the app's tests where a fixture relied on the old shape.

**The choose tables.** `scenarios.choose_tables` (after the three tables above) plays four more tables:
a plain five-player table made with `defaults: "v2"`
(the look stage with `ready` / `progress`, window 2 where every phone with a choice chooses once (the Villager's choose is still recorded, taken alike), the lone Werewolf's prompt, every `choose` answer and refusal, ready to vote, the lock-in vote with pick / re-pick / lock / 409, the oracle),
a nine-player Doppelganger table with a real Werewolf pack
(window 1 with her two chooses and a stale-stage refusal, her look listed at once, then window 2 and every prompt kind; the recorder sends each request's current `stage` unless a scenario names a stale one),
and the automatic deck at 5 (classic) and 9 (chaos) players;
the five-player game's `/results/` is recorded too (`results_five`, the playtest pack's game 7).
`scenarios.results_tables` then plays three more:
six players played to the results by play again
(the Werewolves win, nobody dies, a tie that kills two, the Hunter chain, the Tanner, a dead Robber who held a Werewolf card; the night results ack in the talk; a Doppelganger who copied the Minion with her follow-up armed),
a three-player game with an untimed talk and vote, and a ten-player talk and vote;
then a table before its deal (`_lobby_table`):
lobby sockets (`Table.connect_lobby` / `disconnect_lobby`), a phone that drops (in its grace period, then told when the presence check fires) and comes back,
`deck_preview` for each chip at four and seven players, `deal` for a custom deck that fits and one a card short, a join of another table refused because the
player sits at this waiting one, and a deal nobody tapped ready for.
Every request to a stage endpoint is sent the way the app sends it:
the recorder adds the game's current `stage` (and, for a `choose`, the prompt's `chosen`) unless the scenario names one.
`Table.record_sequence` stores per seat the TYPES of the game events heard in a window (`ws_sequence/*`);
the privacy test requires them equal for every seat and free of player-only night events, and every `night_window` / `progress` sample to be a broadcast.
**The story table.** `story_scenarios.story_tables` plays last (after `gone_account` and `practice_table`, so nothing earlier moves):
one seven-player `v2` table, game after game by play again, recording a talk `/me/` per kind of night result the app draws
(Seer on two centre cards, an Insomniac whose card changed, a Minion with no Werewolf, a lone Mason, Hunter, Tanner, a Seer who timed out, the Doppelganger copying Troublemaker / Robber / Drunk (chosen and timed out) / Werewolf / Insomniac / Villager / Mason / Hunter / Tanner, and her look timed out)
and the results of the Doppelganger-Robber, -Troublemaker, -Drunk and -Insomniac games and of the Minion with no Werewolf.
`test_sample_coverage.py` takes the cases from the engine's role table (every role, every night action a role can take, every role the Doppelganger can copy),
so a new role fails until a scenario records it.
**The asked table.** `asked_scenarios.asked_table` plays after the story table (so nothing earlier moves):
three players, one refusal each for a request carrying an `asked` older than a tap already applied
(`settings_stale`, `ready_stale`, `vote_stale`: 409 `stale_request`).
A diff in any sample is a behaviour change:
review it, and fix the server if it was not meant.
