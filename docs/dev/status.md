# Status: where the rebuild stands

Current state only; history is `git log`. Update this file when something lands or the plan
changes. Last updated 20 November 2026.

## Branch and deployment

- Work branch: `ccr-2435dc07-33z3jn`, shared with the deployment session, which pushes to it
  too: `git fetch` and merge before pushing.
- The server is LIVE on Vercel; every push builds and migrates the shared database
  (`docs/dev/deploy-vercel.md`, "Deploy-safe changes"). After pushing anything that changes the
  server, tell the deployment session `session_01Gu8f2jPBR1SQpcDEMca4hZ` (remote
  `send_message` tool).
- No pull request is open for this work yet.

## Merged on the branch

- Server: one game flow (one `choose` per window, stage tokens, look stage, lock-in vote,
  ready to vote, automatic decks, night timeline), tokens and seats, where-am-I, home extras.
  The original per-role night (protocol 1), its endpoints' old requests, the per-role night
  events, `wave_complete`, `vote_submitted`, `has_voted`, `your_role.has_acted` and the
  lobby ready flag (endpoint, `player_ready`, `is_ready` in bodies) are deleted; a stored
  `night_protocol` key on an older table is ignored, a lobby PATCH checks only the keys it
  gives and the deal clamps stored timer values the server refuses today. New tables and
  dealt games still carry `night_protocol: 2` for the previous code during a deploy (see
  "Next", 3). Runs on Vercel (durable timers and presence rows).
- Contract samples recorded from the real server, with drift, privacy and shape guards; the
  protocol-1 samples are gone and the app's tests read every sample.
- App: the Shadow paper skin and primitives (the only look); the first-time-play pieces (copy,
  cues, hold to reveal, the night board); the data layer (`GameMe`, screen table,
  one outbox, healing fetches), model-checked (`docs/dev/models/phone/`). With the screens
  branch: 04 Your card, the night board, 08 Talk (with My night) and 09 Vote are rebuilt;
  05 shows only while `/me/` loads; 04 is reachable. 01 Join, 02 Table and 03 Deck (+ 03b) are rebuilt and the old home and
  lobby are deleted: every table is opened with `defaults: "v2"` and every build reaches the
  table's shell (no dev-only gate).
- App, end of the game: 10 The count and 11 Results rebuilt (the dead card is
  the final card with its team, the dealt one before it when it moved; who won, every card,
  the night folded into a strip that opens; play again, edit deck, leave); a restart lands on
  10 or 11 as the phone left it.
- App cleanup: the old game screens, the old night on the app side (the old notifier, state
  and per-role prompt handling, the unplayable-game screen, the lenient lobby parsing,
  `LobbyRoute`, `wave_complete`, the debug controller's `driveAs`) and the old look
  (components, tokens, google_fonts, the analyze gate) are deleted; every game opens in the
  table's shell. The game notifier is `LiveGameNotifier` (`live_game.dart`).
- Tooling: screen gallery, cold-read pack, e2e harness (a free port per run, stopping only
  its own backend; all 29 reference games through the choose API, 1, 4, 5, 8 and 21 through
  the new screens; the backend replays the 29 through the API too), subagent model
  guardrail, commit gate routed by path.

## Next, in order

1. Rerun the cold-read playtest on the real screens (method in
   `docs/dev/playtests/2026-11-19-mocks-cold-read.md`). A screen passes when 4 of 5 simulated
   players name the right first action and nobody makes an unrecoverable mistake.
2. Open the pull request; split it if it is too big to review.
3. A later push, once no instance of the code before the protocol-1 cleanup serves: stop
   writing `night_protocol: 2` (`deal.OLD_CODE_NIGHT_FLAG`, used by `hooks.APP_DEFAULTS` and
   `deal.dealt_settings`; `tests/onuw/test_old_code_reads_new_rows.py` goes with it) and the
   play-again write of `LobbyMember.is_ready` (`core/lobbies.py`). After that, a later
   migration may drop `LobbyMember.is_ready` (nothing reads it; the deploy-safe two-step:
   the code stops writing it first, the column goes in the next push).

## Open items

- A request whose answer was lost but which the server processes late can overtake a newer
  tap of the same lane; closing it needs a per-phone sequence number on the server.
- Ten long names on a 320-wide phone: the night board falls under the 14 px reading floor.
- 04 held, the Minion's face on a 320-wide phone: the role name (13.2 px) and its Night
  line (15.1 px) fall under the reading floor (`just screens 320`, `04-your-card-held-minion`).
- The server now sends `CORS_EXPOSE_HEADERS = ["Date"]` (base settings) and `/me/`
  `stage_started_at`; the app does not read either yet (it times fetches by the phone's
  clock). The deployment session has to be told the CORS change.
- `ENV` defaults to dev, so a build without `--dart-define=ENV=prod` includes the `/debug`
  toolbar.
- 01 to 03: no rename (a new name on a device makes a new guest account); the lobby body
  carries no timer lengths until a pace is chosen.
- 01 to 03, not built: the pace tiles' steppers (03 shows the lengths once a pace is chosen);
  in-app QR scanning (the phone's camera opens the link); path URLs for `/join/<code>` (the link
  is `<origin>/#/join/<code>` until the web host rewrites `/join/*`); a public origin for
  native builds (`--dart-define=PUBLIC_ORIGIN`); skin art for Share (the platform's glyph).
- Untidy payloads still open: `docs/dev/server-payload-quirks.md`.
- `CLAUDE.md` files and `.claude/agents/` still describe protocol 1 in a few lines (the
  cleanup did not edit them: they need the owner's go-ahead): `backend/CLAUDE.md` ("the
  night, protocol 2" and the rule "Protocol 1 answers exactly as before"),
  `frontend/CLAUDE.md` (the sample filter and `UnplayableScreen`),
  `.claude/agents/backend-developer.md` ("an original (protocol 1) sample must not change")
  and `.claude/agents/frontend-developer.md` ("the protocol-2 data layer").
- Renames made with the cleanup: the night module is `apps/onuw/choose_night.py`, the `_v2` samples have
  plain names (`started_with_look`, `results_five`, `detail_*`, ...), the e2e runners are
  `api_game_test.dart` and `ui_game_test.dart`, `ui_end_test.dart`, `ui_journey_test.dart`,
  `ui_roles_test.dart`. Not renamed: `docs/specs/onuw/api-contract-v2.md` (linked from
  many places) and the app's `defaults: "v2"` request value (the server accepts it).
- DRF throttles are per instance on Vercel and keyed on a spoofable header: a courtesy, not
  protection.
- Parallel agents set their own `DB_NAME` by hand; nothing enforces it.
- Six sample looks were made for the owner (https://claude.ai/artifact/7rsphhNPs5Uypyqbj4QiH2,
  not in the repository); waiting on the owner: no more look work until they react.
