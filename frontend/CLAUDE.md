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
just record-assets     # records the bundled files as the last release's (tool/release_assets.json), deliberately, when a build goes out
just check-release     # builds web with no defines, fails if the /debug toolbar is in it
just analyze           # flutter analyze: fails on any issue
just format-check      # dart format check of lib, test, test_screens
just gen               # Riverpod code generation, after changing any provider
just screens [width] [report|strict]  # every screen and the component sheet as PNGs beside the mocks
just scene-frames      # the dusk and the dawn pumped to fixed times: frames and a strip each
just loading-clips     # a tap going busy, a slow join, a failed send and its retry, a reconnect: looping WebPs
just night-frames      # the night board's pick and candle, a frame per 17 ms
just vote-frames       # the vote's finger, pick and lock (the seal landing), a frame per 17 ms
just vote-pictures     # the locked vote, the lock in four frames, the vote at several table sizes
just count-pictures    # the count: one death, a tie, nobody, the moment in four frames, ten with long names
just paper-parts       # every component in paper dress, every state (the parts page)
just paper-components  # the table, your card, the night board and the card sheet, for before and after
just paper-dress       # the dressed-up pass: every paper part in both dresses, and the table, your card and the night board in paper dress
just card-frames       # your card turning over (finger, hold, turn, release), a frame per 17 ms
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
- **A native release build needs `PUBLIC_ORIGIN`** (the web app's https origin): without it
  there is no QR code and no Share, so `tool/build_android.sh` and `build.gradle.kts` stop the
  build and say what to pass (`just build-android`; debug builds and tests need none). The
  release keystore in `android/release-key/` is PUBLIC by the owner's decision (sideloaded
  installs only; replace it before any store release; its README says how). A link is
  `<origin>/join/<code>`, a path: the web host serves the app for it and Android opens it in
  the app (`docs/dev/deploy-vercel.md`).
- **The scanner is behind `CodeScanner`**: a test or a gallery picture brings its own
  (`test/helpers/fake_code_scanner.dart`, `TableSetup.pump(scanner:)`), never the plugin.
- **Test fonts**: real Gloock and Figtree are loaded in tests; `Roboto` (Material's default,
  the debug toolbar's) is a Figtree stand-in.

## An app left open

- **The app renews itself for a new build** (`lib/core/update/`, the rule `mayReloadNow` in
  `features/game/domain/reload_rule.dart`, `docs/dev/deploy-vercel.md`): it knows its commit
  (`BUILD_COMMIT`), reads `/commit.txt`, and reloads at a safe moment through the cold opening, so
  a seated player lands in their seat. In a running game it never reloads on a phase change or the
  timer, only when the tab comes back after a while away. It updates the service worker and waits
  for it to take over before reloading; it never deletes the worker or its caches. Nothing is
  shown. A build with no commit (local, tests, the
  installed app) never looks. A new place that shows a screen or starts a request must not break
  the rule: a screen is an `AppScreen` or one of `HomeGate`'s names, a write goes through
  `playerRequest`.
- **A file removed or renamed in `assets/`** fails `asset_release_test.dart` (compared with the
  bundle at the main branch (origin/main), else `tool/release_assets.json`) until it is an `ArtSet.retired` copy or
  a dated `removedOnPurpose` line in `tool/release_assets.json`; `just record-assets` refuses
  while one is uncovered, so regenerating cannot hide a removal.
- **`vercel.json` is judged as Vercel compiles it**: `tool/web_smoke/routes.test.cjs` (run by
  `just web-smoke`, which needs `@vercel/routing-utils` from `just web-smoke-setup`), never by
  reading a `source` as a plain pattern.

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
- **Every request a player's tap makes goes through `playerRequest`**
  (`core/requests/player_request.dart`), and the tapped control shows it (`Pending`): busy in
  the frame of the tap, never sent twice, settles to done or to its own "Try again". A write
  outside it does not build (it needs a `Door`). Nothing here waits. Detail:
  `docs/app-rules.md`, "Requests".
- **Every place the app waits is `Waiting`** (`design_system/primitives/waiting_sign.dart`), in
  the frame of the screen it waits for: never a bare ground, never lanterns and a failure
  together; a failure is one quiet line on the control (`Notice`), never a box. Detail:
  `docs/app-rules.md`, "Waits".
- **A screen's main action never sits silently disabled**: `PrimaryButton` and
  `SecondaryButton` take no `onPressed` of null. One that cannot act yet is
  `.locked(onLockedTap:)`, `.waiting(reason:)`, or says what to do in its own label and does
  it. `main_button_rule_test.dart` scans `lib/` for a bare disabled main button; a new main
  button brings its state and its test. Detail: `docs/app-rules.md`, "Main buttons".
- **Every fetch a screen depends on heals**: retried with backoff or polled until its reason
  ends (`core/healing/`). Never leave a screen on a failed fetch.
- **No waits.** Nothing adds a wait, a minimum time or an assumed timer length: lengths come
  from the server's deadlines, which are the table's settings. "Ready to vote" is never
  locked.
- **Words**: every player-facing string is in `lib/design_system/copy/copy.dart`, held to the
  spec's budgets by `copy_budget_test.dart`; none in widgets.
- **Names are never cut**: they wrap between words or are set smaller (`FitWords`, `FitLine`),
  never an ellipsis; the fit sweep and `just screens` fail on cut text.
- **Reading floor** (the owner's type choice, 23 November 2026, `docs/design/type-audit.md`): body and names 14 px, small labels 12 px, 7:1 contrast on player screens, full ink
  for anything that says something true; no uppercase micro-labels; one amber fill per screen; a selection is lift plus outline, never amber.
- **One look, two dresses**: a screen is plain (today's look, exactly) unless it asks
  `ScreenFrame(dress: Dress.paper)`; sizes, angles and colours are the skin's, never a number
  in a screen. Detail: `docs/app-rules.md`, "The dress", and `lib/design_system/README.md`.
- **Values from the skin**: build screens from `lib/design_system/primitives/`, read
  `context.skin`, `context.ground`, `Space`, `Motion`; no literals (a text size, weight or face is a
  type role, never a number in a widget: `type_guard_test.dart` fails it), no `SkinId` checks in
  layout code. One look, Shadow paper; a new look is a whole design, not a recolour.
- **Secrets are held, not tapped**: `HoldToReveal` and `HeldFace`; art for secrets is
  precached at start so a reveal fetches nothing. The one day exception is "My night" on 08: a
  tap opens it as a sheet. Nothing vibrates on a card (owner, 23 November 2026).
- **Information a player asks for opens as a sheet from the bottom edge** (`showSkinSheet`),
  the same place whatever was tapped, closed by its button, the scrim or Back; never a popover
  at the touch point, and opened from a context under the screen's `ScreenFrame` (asserted), so it is dressed and lit as its screen is (`lib/design_system/README.md`, "Where information a player asks for appears").

## Screens

Every screen (01 to 11) is built from the primitives, against its mock in
`docs/design/mocks/` (`docs/design/mock-to-skin.md` maps every element), to the copy in
`docs/specs/frontend/first-time-play.md`. A change to one is checked by eye with
`just screens` at 320, 360 and 390 wide (`strict` must pass at 360 and 390: GitHub runs it as
"Screens strict at 360" and "... at 390"), and you hand over before and after pictures. A change to
words or screens also runs `just test-harness` before its pull request (the commit gate does
not; GitHub does, as "End-to-end Harness").
