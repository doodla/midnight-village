# Session notes: where the rebuild stands (20 November 2026)

Working notes for whoever continues this (a person or a Claude session). Plain facts, newest
state first. Delete this file when the rebuild is done.

## How the product owner wants the work done

- The owner is not an engineer: write to them in plain words, short, no jargon.
- "The game is yours to complete. Take whatever choices you have to." Do not stop to ask;
  decide, say what you decided, carry on.
- I plan and orchestrate; Opus/Sonnet subagents write the code (Opus for design-heavy or tricky
  work, Sonnet for well-specified work). Every change is reviewed by a FRESH agent that was not
  given my conclusions. When a review comes back, zoom out and fix the root cause as a
  mechanism, not the single instance.
- **Fun first.** Do not over-index on secrecy. No added waits, no minimum response times, no
  assumed timer lengths (every length is the table's own setting). Test for any rule: would a
  table of friends notice the protection, or only the friction? See
  `docs/specs/frontend/first-time-play.md` section 8.
- Cut "AI prose": few words, elements do the job, the one thing to do is the loudest thing.
  Teach a gesture once by making the player do it, then never mention it again.
- A "skin"/look is a completely different design (own layouts, components, original art), NOT a
  recolour or an image filter. Finish Shadow paper only. The two filter-made looks
  (`nightPrint`, `warmBlood`) are being deleted.
- Never open or read https://github.com/mankidev/antialgorithm in the main session; only
  subagents may, and their reports must not reproduce it.
- Do not generate large batches of art without asking. Do not touch the owner's Vercel, Neon or
  Redis accounts.

## Environment (cloud container; the setup script proposal was declined)

A fresh container needs, by hand: `uv tool install rust-just`; Flutter **3.38.10** unpacked to
`/opt/flutter` and linked into `/usr/local/bin`; `service postgresql start` with user/password
`postgres`/`postgres` and database `midnight_village_dev`; `backend/.env` WITHOUT
`DJANGO_SETTINGS_MODULE` (it makes tests run under dev settings); `cd backend && just install`;
`cd frontend && flutter pub get`. After a container restart Postgres is down: start it.
Parallel agents must use their own worktree AND their own `DB_NAME` in their `backend/.env`, and
check port 8001 is free before `just test-harness`. Heavy parallel load makes timing tests fail
falsely (e.g. `test_timers ... test_a_scheduled_job_runs_after_the_delay_with_its_params`):
re-run on a quiet machine before believing a failure.

## Branch and deployment

- Work branch: `ccr-2435dc07-33z3jn` (shared with the deployment session, which pushes to it
  too: always `git fetch` and merge before pushing). Last pushed commit when this was written:
  `aa96e21`. Everything on it passes: backend 3,618 tests, frontend 1,151, harness green.
- The server is LIVE on Vercel. Every push builds and runs `migrate` on the shared database
  before the new code serves. Rules are in `backend/CLAUDE.md` "Deploy-safe changes"
  (migrations frozen once pushed, `db_default` on NOT NULL columns, no app imports in
  migrations, `lock_timeout` first, a migration-test case per migration). Tell the deployment
  session (`session_01Gu8f2jPBR1SQpcDEMca4hZ`, via the remote `send_message` tool) after pushing
  anything that changes the server.
- No pull request is open for this work yet. Open one when a coherent piece is ready.

## What is done and on the branch

Tooling
- `just screens [width] [report|strict]`: every screen and the component sheet as
  PNGs beside the mocks (`frontend/build/screens/`); `just playtest-pack`: the cold-read pack
  (`frontend/build/playtest/`).
- Real fonts in tests; one Linux golden set; `just analyze` runs `tool/analyze_gate.sh` (fails
  on new uses of the old look; allowed files in `tool/old_look_users.txt`).
- End-to-end harness (`just test-harness`): 29 reference games, play again, dropped phones,
  host handover, and protocol-2 scenarios; strict driving, explicit time budgets.
- Contract samples: `contract_samples/` recorded from the real server (`just samples`), a drift
  test, a privacy test (which events are player-only), a frontend shape guard per protocol,
  phase and kind, strict mocks, a scan that stops tests bypassing the guard. The app parses
  strictly.
- Backend: `makemigrations --check` in `just check`; a migration test pass in `just test`.

Server (all additive; today's behaviour is "protocol 1" and is byte-identical in the samples)
- Tokens and seats, `GET /api/me/table/`, night-results ack, `night_timeline` in results,
  `GET /api/stats/online/`, `GET /api/onuw/me/recent-games/`, settings PATCH merges and is
  refused during a game, tolerant socket consumers.
- Protocol 2 (only for lobbies created with `defaults: "v2"` or setting `night_protocol: 2`):
  lock-in voting (counts only), ready to vote, the look stage (`card_look_seconds`), one
  `choose` request per window with the server interpreting picks, a `stage` token every request
  echoes (409 `wrong_stage` when late), prompt `shapes` so the phone can stop a wasted turn,
  automatic decks (`deck: "auto"` + `deck_chip`). Code: `backend/apps/onuw/night2.py`,
  `protocol.py`, `engine/choose.py`, `engine/decks.py`.

Design layer
- `Skin` + primitives (`frontend/lib/design_system/skin`, `primitives`, `layout`), Shadow paper
  from the mocks, `docs/design/mock-to-skin.md`, all ten player tokens in `docs/design/art/`.

Specs
- `docs/specs/onuw/api-contract-v2.md` (with two amendment sections at the end).
- `docs/specs/frontend/first-time-play.md`: copy rules, teach-once cues, final copy per screen,
  starter decks. **Sections 7 and 8 override the earlier sections** (named stages; nothing
  waits; "What you saw" folded into the talk's "My night" box, no screen 07; fun first).
- `docs/dev/playtests/2026-11-19-mocks-cold-read.md`: the playtest findings and how to rerun.
- `docs/dev/server-payload-quirks.md`: untidy server payloads still open under protocol 1.

## In flight when this was written

- Subagent `abee542b53e53f325` (Opus, its own worktree): the shared first-time-play pieces for
  Shadow paper only (LearnedStore, TeachOnce, HoldToReveal timings, HeldFace, `copy.dart` +
  budget test, RoleText, NightBoard driven by the server's prompt shapes, the amber rule, the
  reading floor, the cold-read pack) AND deleting the `nightPrint` and `warmBlood` skins with
  their filtered art, fonts and scripts. It was told about spec sections 7 and 8 mid-flight.
  When it reports: have it reviewed by a fresh agent, merge its worktree branch into
  `ccr-2435dc07-33z3jn`, run every check, push. If it is gone after a restart, its worktree is
  under `.claude/worktrees/agent-abee542b53e53f325`; resume it or finish from there.
- Six sample looks were made for the owner to react to (not app code, not in the repository):
  page https://claude.ai/artifact/7rsphhNPs5Uypyqbj4QiH2 ; files in
  `frontend/build/show/` (gitignored). Looks: Small Hours, Lights Out, Wrong Side, All-Night
  Coin-Op, Dress-Up Night, Huff. Waiting for the owner's reaction; do nothing more until then.

## Next, in order

1. Land the shared pieces (above).
2. App data layer for protocol 2: read `stage`, `shapes`, `progress`, `my_vote`, `ready`; send
   `choose`, `ready`, `vote` with `lock`; create lobbies with `defaults: "v2"`; extend the
   "parses every /me/" test to protocol-2 samples (`game_models_test.dart` has the marker).
   Phones change what others can see immediately on tap, never on the response.
3. Rebuild the screens for Shadow paper, one at a time, each from the primitives, checked by
   eye against its mock with `just screens`, to the copy in the spec: 01 Join (QR/link join,
   online count, recent games), 02 Table, 03 Deck (+ 03b role sheet), 04 Your card, 05/06 night
   board, 08 Talk with "My night", 09 Vote, 10 The count, 11 Results (timeline). Delete each
   old-look file with the last screen that used it (`frontend/CLAUDE.md` "Removing the old
   look").
4. Rerun the cold-read playtest on the real screens (method in the playtest doc). A screen
   passes when 4 of 5 simulated players name the right first action with confidence and nobody
   makes an unrecoverable mistake. If they hesitate or wait, cut more.
5. One cleanup slice: delete protocol 1, the legacy vote fields, per-role prompt events, and
   the staging paragraph in the contract.
6. Open the pull request; keep it reviewable (split if needed).

## Known open items

- The "your card" screen is unreachable in today's app (it waits for an event the server never
  sends); the rebuild fixes it via the look stage.
- A phone can, across several server instances, receive `action_prompt` before `wave_start` and
  lose its prompt (protocol 1 only; protocol 2 has no per-player night events).
- DRF throttles are per instance on Vercel and keyed on a spoofable header: a courtesy, not
  protection.
- Still to build in tooling: a faster commit gate (it runs both full suites, about 7 minutes)
  and per-worktree test database names so parallel agents cannot collide.
- Commit format: `type(scope): description`; the hook in `.claude/hooks/` runs the checks on
  every commit and must never be bypassed. Changes under `.claude/` need
  `docs/claude-architecture.md` updated in the same commit.
