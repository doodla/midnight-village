# Status: where the rebuild stands

Current state only; history is `git log`. Update this file when something lands or the plan
changes. "Branch and deployment" was last checked on 23 November 2026; the lists below were
last gone through on 20 November, and what landed since is `git log` on main (#64 to #73).

## Branch and deployment

- Work lands on main by pull request, squash-merged when every GitHub check is green
  (`docs/dev/running-the-work.md`). Each session works on its own branch, started from main.
- The server is LIVE on Vercel; every merge builds and migrates the shared database
  (`docs/dev/deploy-vercel.md`, "Deploy-safe changes"). Nobody watches deployments by hand (23 November 2026):
  after every merge the "Deployed Check" workflow proves the live server and app work together
  (`docs/dev/deploy-vercel.md`, "The check after each merge"). A red run on main means look now.

## Merged

- Server: one game flow (one `choose` per window, stage tokens, look stage, lock-in vote,
  ready to vote, automatic decks, night timeline), tokens and seats, where-am-I, home extras.
  The original per-role night (protocol 1), its endpoints' old requests, the per-role night
  events, `wave_complete`, `vote_submitted`, `has_voted`, `your_role.has_acted` and the
  lobby ready flag (endpoint, `player_ready`, `is_ready` in bodies) are deleted; a stored
  `night_protocol` key on an older table is ignored, a lobby PATCH checks only the keys it
  gives and the deal clamps stored timer values the server refuses today. Nothing writes
  `night_protocol` or the lobby ready flag any more (23 November 2026). The ready column
  itself is dropped (core migrations 0011 and 0012): never roll back to a build from before
  0011 (commit e8f50b5, #81), which can neither read nor write the lobby's members.
  Runs on Vercel (durable timers and presence rows).
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

## Open items

- A request whose answer was lost but which the server processes late can overtake a newer
  tap of the same lane; closing it needs a per-phone sequence number on the server.
- Ten long names on a 320-wide phone: the night board falls under the 14 px reading floor.
- 04 held, the Minion's face on a 320-wide phone: the role name (13.2 px) and its Night
  line (15.1 px) fall under the reading floor (`just screens 320`, `04-your-card-held-minion`).
- The server now sends `CORS_EXPOSE_HEADERS = ["Date"]` (base settings) and `/me/`
  `stage_started_at`; the app does not read either yet (it times fetches by the phone's
  clock). Nobody has checked that the live server sends it.
- 01 to 03: no rename (a new name on a device makes a new guest account). 03 is the set-up
  page (players 3 to 10 or open, the deck face up, every length with its range; no pace
  presets); the lobby body carries `deck_cards`, `lengths`, `length_ranges` and `deal.seats`.
- Trying the game alone: practice players, switched on by holding "Players" on 03
  (`docs/specs/onuw/solo-play-proposal.md`).
- 01 scanning and links (built, not yet checked on a real phone or in the owner's app): the scan action on 01
  (camera in the app on the web and Android), table links as `<origin>/join/<code>` paths, a native release
  build that needs `PUBLIC_ORIGIN`, Android App Links with a committed PUBLIC signing key (sideloaded installs
  only, to be replaced before any store release: `frontend/android/release-key/README.md`). Skin art for
  Share is still the platform's glyph.
- Untidy payloads left: three lobby refusals still answer `detail` as a list where every other
  refusal's is a string (creating a table with bad settings; a settings change that is not an
  object or that the game refuses; the last two also lack a `code`). The app reads both forms.
  And a player whose account has no display name is named by its username in game bodies
  (`display_name or username`); every guest and practice player is given a name, so this is
  only an account made by hand.
- Renames made with the cleanup: the night module is `apps/onuw/choose_night.py`, the `_v2` samples have
  plain names (`started_with_look`, `results_five`, `detail_*`, ...), the e2e runners are
  `api_game_test.dart` and `ui_game_test.dart`, `ui_end_test.dart`, `ui_journey_test.dart`,
  `ui_roles_test.dart`. Not renamed: `docs/specs/onuw/api-contract-v2.md` (linked from
  many places) and the app's `defaults: "v2"` request value (the server accepts it).
- Six sample looks were made for the owner (https://claude.ai/artifact/7rsphhNPs5Uypyqbj4QiH2,
  not in the repository). Parked by the owner: no other looks until Shadow paper is good.
