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
  one outbox, healing fetches), model-checked (`docs/dev/models/phone/`). The screens are still
  the old ones on protocol 1.
- Tooling: screen gallery, cold-read pack, e2e harness, subagent model guardrail, commit gate
  routed by path.

## Next, in order

1. Rebuild screens 01 to 11 for protocol 2, one at a time, from the primitives, checked by eye
   with `just screens` against the mocks, before/after pictures to the owner: 01 Join, 02
   Table, 03 Deck (+ 03b role sheet), 04 Your card, 05/06 night board, 08 Talk with "My night",
   09 Vote, 10 The count, 11 Results. Delete each old-look file with the last screen using it
   (`docs/dev/old-look-removal.md`).
2. Rerun the cold-read playtest on the real screens (method in
   `docs/dev/playtests/2026-11-19-mocks-cold-read.md`). A screen passes when 4 of 5 simulated
   players name the right first action and nobody makes an unrecoverable mistake.
3. One cleanup slice: delete protocol 1, the legacy vote fields, the per-role prompt events and
   the staging paragraph in `docs/specs/onuw/api-contract-v2.md`.
4. Open the pull request; split it if it is too big to review.

## Open items

- `PrimaryButton.done` looks like `PrimaryButton.locked`.
- The server should expose its time to the web app (`Date` exposed to the browser, or a
  `server_time` field); without it the web app times fetches by the phone's clock.
- A request whose answer was lost but which the server processes late can overtake a newer
  tap of the same lane; closing it needs a per-phone sequence number on the server.
- Ten long names on a 320-wide phone: the night board falls under the 14 px reading floor.
- Recorder gap: no contract sample of a Doppelganger who copied the Minion with a follow-up.
- Protocol 1 only (goes with the cleanup slice): the "your card" screen is unreachable (it
  waits for an event the server never sends); across several server instances a phone can get
  `action_prompt` before `wave_start` and lose its prompt.
- Untidy protocol-1 payloads still open: `docs/dev/server-payload-quirks.md`.
- DRF throttles are per instance on Vercel and keyed on a spoofable header: a courtesy, not
  protection.
- Parallel agents set their own `DB_NAME` by hand; nothing enforces it.
- Six sample looks were made for the owner (https://claude.ai/artifact/7rsphhNPs5Uypyqbj4QiH2,
  not in the repository); waiting on the owner: no more look work until they react.
