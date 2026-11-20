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

- Server: night protocol 2 (one `choose` per window, stage tokens, look stage, lock-in vote,
  ready to vote, automatic decks, night timeline), tokens and seats, where-am-I, home extras;
  protocol 1 unchanged beside it. Runs on Vercel (durable timers and presence rows).
- Contract samples recorded from the real server, with drift, privacy and shape guards.
- App: the Shadow paper skin and primitives (the only look); the first-time-play pieces (copy,
  cues, hold to reveal, the night board); the protocol-2 data layer (`GameMe`, screen table,
  one outbox, healing fetches), model-checked (`docs/dev/models/phone/`). With the screens
  branch: 04 Your card, the night board, 08 Talk (with My night) and 09 Vote are rebuilt for
  protocol 2; 05 shows only while `/me/` loads; under protocol 2, 04 is reachable (it was not
  under protocol 1). 01 Join, 02 Table and 03 Deck (+ 03b) are rebuilt and the old home and
  lobby are deleted: every table is opened with `defaults: "v2"` and every build reaches the
  table's shell (no dev-only gate).
- App, end of the game: 10 The count and 11 Results rebuilt for protocol 2 (the dead card is
  the final card with its team, the dealt one before it when it moved; who won, every card,
  the night folded into a strip that opens; play again, edit deck, leave); a restart lands on
  10 or 11 as the phone left it.
- Tooling: screen gallery, cold-read pack, e2e harness, subagent model guardrail, commit gate
  routed by path.

## Next, in order

1. Rebuild the remaining screens for protocol 2, one at a time, from the primitives, checked
   by eye with `just screens` against the mocks, before/after pictures to the owner (01 to 04,
   06 and 08 to 11 are done). Delete each old-look file with the last screen using it
   (`docs/dev/old-look-removal.md`).
2. Rerun the cold-read playtest on the real screens (method in
   `docs/dev/playtests/2026-11-19-mocks-cold-read.md`). A screen passes when 4 of 5 simulated
   players name the right first action and nobody makes an unrecoverable mistake.
3. One cleanup slice: delete protocol 1, the legacy vote fields, the per-role prompt events and
   the staging paragraph in `docs/specs/onuw/api-contract-v2.md`.
4. Open the pull request; split it if it is too big to review.

## Open items

- `PrimaryButton.done` looks like `PrimaryButton.locked`.
- A request whose answer was lost but which the server processes late can overtake a newer
  tap of the same lane; closing it needs a per-phone sequence number on the server.
- Ten long names on a 320-wide phone: the night board falls under the 14 px reading floor.
- The old 10 and 11 (`components/game/game_results.dart`) stay while protocol 1's
  `GameContainerScreen` shows them.
- Protocol 1 only (goes with the cleanup slice): across several server instances a phone can
  get `action_prompt` before `wave_start` and lose its prompt. (The unreachable "your card"
  screen is fixed under protocol 2.)
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
- Untidy protocol-1 payloads still open: `docs/dev/server-payload-quirks.md`.
- DRF throttles are per instance on Vercel and keyed on a spoofable header: a courtesy, not
  protection.
- Parallel agents set their own `DB_NAME` by hand; nothing enforces it.
- Six sample looks were made for the owner (https://claude.ai/artifact/7rsphhNPs5Uypyqbj4QiH2,
  not in the repository); waiting on the owner: no more look work until they react.
