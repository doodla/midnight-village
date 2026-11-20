# Frontend: Midnight Village

Flutter (web, iOS, Android), Riverpod with code generation, GoRouter. Read the README of the
part you change, and keep it true:

- `lib/design_system/README.md`: the skin, the primitives, the first-time-play pieces (copy,
  cues, hold to reveal, the night board).
- `lib/features/game/README.md`: the protocol-2 data layer (`GameMe`, screen table, outbox,
  healing fetches).
- `test/README.md`: the e2e harness, fonts, goldens, the screen gallery.
- `test/helpers/contract/README.md`: the contract guard and its helpers.
- `docs/dev/old-look-removal.md`: which old-look file dies with which screen.

## Commands

```bash
just test              # flutter test --exclude-tags e2e
just analyze           # flutter analyze through tool/analyze_gate.sh (old-look rule below)
just format-check      # dart format check of lib, test, test_screens
just gen               # Riverpod code generation, after changing any provider
just screens [width] [report|strict]  # every screen and the component sheet as PNGs beside the mocks
just playtest-pack     # the cold-read pack: four first-game journeys to build/playtest/
just test-harness      # boots the backend on :8001 and replays the reference games (not in `just test`)
just skin-art          # regenerate assets/skins/shadow_paper/ from docs/design/art/
just flutter-golden-update  # regenerate goldens (Linux only)
```

## Traps

- **Forgot `just gen`**: analyzer errors in `*.g.dart` that look like real bugs.
- **Port 8001 is shared** by every worktree's harness: check it is free before `just test-harness`.
- **Goldens are Linux only** (`dart_test.yaml` skips them elsewhere); CI is the source of truth.
- **`MockHttpClient`** lives in `integration_test/helpers/` (the web integration build cannot
  import out of its root); `test/helpers/mock_http_client.dart` re-exports it.
- **Test fonts**: real Gloock and Figtree are loaded in tests; other families are Figtree
  stand-ins, so a golden never proves an unbundled font.

## Server payloads in tests

Every mocked HTTP body and socket event is built from `contract_samples/` and checked against
the samples of its own situation; a request with no mock fails the test; domain objects come
from `FromSample`, never a constructor with made-up values; `fixture_sources_test.dart` fails
any test that goes around this. Night inputs come from recorded protocol-2 samples
(`recordedMe`), never by hand. A test about malformed input says so (`offContract: true`).
After a payload change: `just samples` in `backend/`, then fix the fixtures that fail.

## The app's rules

- **The server decides.** Screens show what `/me/` says. `screenFor` is the one server-state
  to screen table; the only local inputs are `LocalSteps`.
- **Taps change what others can see at once, never on the response.** All protocol-2 taps go
  through the one `Outbox`; a choose is never sent twice for a turn; after any taken choose
  the phone re-reads `/me/` and trusts `chosen` and `chooses_left`.
- **Every fetch a screen depends on heals**: retried with backoff or polled until its reason
  ends (`core/healing/`). Never leave a screen on a failed fetch.
- **No waits.** Nothing adds a wait, a minimum time or an assumed timer length: lengths come
  from the server's deadlines, which are the table's settings. "Ready to vote" is never
  locked.
- **Words**: every player-facing string is in `lib/design_system/copy/copy.dart`, held to the
  spec's budgets by `copy_budget_test.dart`; none in widgets.
- **Names are never cut**: they wrap between words or are set smaller (`FitWords`, `FitLine`),
  never an ellipsis; the fit sweep and `just screens` fail on cut text.
- **Reading floor**: 16 px to act, 14 px captions; no uppercase micro-labels; one amber fill
  per screen; a selection is lift plus outline, never amber.
- **Values from the skin**: build screens from `lib/design_system/primitives/`, read
  `context.skin`, `context.ground`, `Space`, `Motion`; no literals, no `SkinId` checks in
  layout code. One look, Shadow paper; a new look is a whole design, not a recolour.
- **Secrets are held, not tapped**: `HoldToReveal` and `HeldFace`; art for secrets is
  precached at start so a reveal fetches nothing.

## Screens

Rebuild one screen at a time from the primitives, against its mock in `docs/design/mocks/`
(`docs/design/mock-to-skin.md` maps every element), to the copy in
`docs/specs/frontend/first-time-play.md`. Check it by eye with `just screens` at 320, 360 and
390 wide, `strict` before merging, and send before/after pictures to the owner.

## Removing the old look

The old look (`lib/design_system/components/` and `lib/design_system/tokens/`) stays only while screens use it.
Every old-look file is marked `// OLD LOOK` and `@Deprecated`; `just analyze` fails on any new
use outside `tool/old_look_users.txt`. Delete a file with the change that rebuilds the last
screen using it, and its line from that list. Which file dies with which screen:
`docs/dev/old-look-removal.md`.
