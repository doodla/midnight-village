# Frontend: Midnight Village

Flutter (web, iOS, Android), Riverpod with code generation, GoRouter. Read the README of the
part you change, and keep it true:

- `lib/design_system/README.md`: the skin, the primitives, the first-time-play pieces (copy,
  cues, hold to reveal, the night board).
- `lib/features/game/README.md`: the game's data layer (`GameMe`, screen table, outbox,
  healing fetches) and the screens 04 to 11.
- `test/README.md`: the e2e harness, fonts, goldens, the screen gallery.
- `test/helpers/contract/README.md`: the contract guard and its helpers.

## Commands

```bash
just test              # flutter test --dart-define=ENV=dev --exclude-tags e2e (dev is explicit: a build with no ENV is prod, without /debug)
just check-release     # builds web with no defines, fails if the /debug toolbar is in it
just analyze           # flutter analyze: fails on any issue
just format-check      # dart format check of lib, test, test_screens
just gen               # Riverpod code generation, after changing any provider
just screens [width] [report|strict]  # every screen and the component sheet as PNGs beside the mocks
just scene-frames      # the dusk and the dawn pumped to fixed times: frames and a strip each
just playtest-pack     # the cold-read pack: five first-game journeys to build/playtest/
just test-harness      # boots its own backend on a free port, runs the e2e harness (not in `just test`)
just gen-check         # fails when committed *.g.dart / *.freezed.dart differ from `just gen` (about 50 s)
just test-widgets      # the widget tests without the goldens (GitHub's "Widget Tests")
just skin-art          # regenerate assets/skins/shadow_paper/ from docs/design/art/
just flutter-golden-update  # regenerate goldens (Linux only)
```

The commit gate runs `just analyze` and `just format-check` only (seconds). GitHub runs the rest on
every pull request, as its own checks, and merges nothing on red: analyze and format, widget tests
with `just gen-check`, goldens, `just screens` strict at 360 and 390, `just check-release`, the
web integration test and `just test-harness`. `just gate-full` runs the first four locally.

## Traps

- **Bare `flutter test` / `flutter run` is prod** (fails with "Production API_ORIGIN not configured"): pass `--dart-define=ENV=dev` or use the just recipes.
- **Forgot `just gen`**: analyzer errors in `*.g.dart` that look like real bugs.
- **The harness runs side by side**: each `just test-harness` takes a free port (or
  `HARNESS_PORT`) and stops only the backend it started; the throwaway database is shared.
- **Goldens are Linux only** (`dart_test.yaml` skips them elsewhere); CI is the source of truth.
- **`MockHttpClient`** lives in `integration_test/helpers/` (the web integration build cannot
  import out of its root); `test/helpers/mock_http_client.dart` re-exports it.
- **Test fonts**: real Gloock and Figtree are loaded in tests; `Roboto` (Material's default,
  the debug toolbar's) is a Figtree stand-in.

## Server payloads in tests

Every mocked HTTP body and socket event is built from `contract_samples/` and checked against
the samples of its own situation; a request with no mock fails the test; domain objects come
from `FromSample`, never a constructor with made-up values; `fixture_sources_test.dart` fails
any test that goes around this. Night inputs come from recorded samples (`recordedMe`), never
by hand. A test about malformed input says so (`offContract: true`). The app's tests read every
sample.
After a payload change: `just samples` in `backend/`, then fix the fixtures that fail.

## The app's rules

- **The server decides.** Screens show what `/me/` says. `screenFor` is the one server-state
  to screen table; the only local inputs are `LocalSteps`.
- **Taps change what others can see at once, never on the response.** All taps go
  through the one `Outbox`; a choose is never sent twice for a turn; after any taken choose
  the phone re-reads `/me/` and trusts `chosen` and `chooses_left`. A phone with nothing to
  choose sends no choose at all; its board has no button.
- **Every fetch a screen depends on heals**: retried with backoff or polled until its reason
  ends (`core/healing/`). Never leave a screen on a failed fetch.
- **No waits.** Nothing adds a wait, a minimum time or an assumed timer length: lengths come
  from the server's deadlines, which are the table's settings. "Ready to vote" is never
  locked.
- **Words**: every player-facing string is in `lib/design_system/copy/copy.dart`, held to the
  spec's budgets by `copy_budget_test.dart`; none in widgets.
- **Names are never cut**: they wrap between words or are set smaller (`FitWords`, `FitLine`),
  never an ellipsis; the fit sweep and `just screens` fail on cut text.
- **Reading floor**: 16 px to act, 14 px captions, 7:1 contrast on player screens, full ink
  for anything that says something true; no uppercase micro-labels; one amber fill per screen; a selection is lift plus outline, never amber.
- **Values from the skin**: build screens from `lib/design_system/primitives/`, read
  `context.skin`, `context.ground`, `Space`, `Motion`; no literals, no `SkinId` checks in
  layout code. One look, Shadow paper; a new look is a whole design, not a recolour.
- **Secrets are held, not tapped**: `HoldToReveal` and `HeldFace`; art for secrets is
  precached at start so a reveal fetches nothing.

## Screens

Every screen (01 to 11) is built from the primitives, against its mock in
`docs/design/mocks/` (`docs/design/mock-to-skin.md` maps every element), to the copy in
`docs/specs/frontend/first-time-play.md`. A change to one is checked by eye with
`just screens` at 320, 360 and 390 wide (`strict` must pass at 360 and 390: GitHub runs it as
"Screens strict at 360" and "... at 390"), and you hand over before and after pictures. A change to
words or screens also runs `just test-harness` before its pull request (the commit gate does
not; GitHub does, as "End-to-end Harness").
