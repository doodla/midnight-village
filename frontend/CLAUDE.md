# Frontend — Midnight Village

## Commands

```bash
just run               # Run on web (Chrome, port 3000)
just test              # Run tests
just analyze           # Dart static analysis
just gen               # Riverpod code generation (run after changing providers)
just watch             # Code generation in watch mode
just test-integration  # Integration tests on Chrome
```

## Code Generation

Riverpod uses code generation. After modifying any provider or adding `@riverpod` annotations, run `just gen` to regenerate `*.g.dart` files. Forgetting this causes analyzer errors on generated code that look like real bugs.

## Debug & Integration Harness

- `just test-harness` runs the deterministic e2e harness in `test_e2e/` and boots (and stops) the harness backend on `:8001` itself. The API runner replays all 29 reference games from `backend/tests/onuw/data/reference_games.json` through the two-window night and asserts the debug-state oracle; the UI runner plays a subset through the real widget tree with a live WebSocket and writes per-player PNG filmstrips. `api_lifecycle_test.dart` (helpers `harness/live_table.dart`, `PlayerWire.connectLobby`) runs the table lifecycle through real sockets: play again, dropped phones (night and vote grace, `night_results`) and host handover; the oracle's `pending_timers` shows which timers are armed. Rules for harness tests: `DebugTableController.driveAs` is strict (a refusal throws; `lenient: true` is for the toolbar), wall-clock checks use `TimeBox`, waits take explicit timeouts, and nothing is slept on. It is intentionally NOT under `test/` and NOT part of `just test`. Full docs: `docs/dev/debug-harness/`.
- The night is two windows: a player may get a prompt, submit, then wait with no result until the window closes (`submitAction` shows waiting); results arrive together and are held until dismissed; the Doppelganger's look result arrives with her follow-up prompt in the same window; `skip` is the "do nothing" control wherever the server's prompt lists it.
- Shared test helper `MockHttpClient` lives in `integration_test/helpers/` (the web integration build cannot import out of its root); `test/helpers/mock_http_client.dart` re-exports it.
- `/debug` route (dev-only, gated by const `Env.isDev` so it tree-shakes out of prod) — the debug toolbar: spin up a table, switch player perspectives, god panel, auto-drive. Core lives in `lib/core/debug/`.

## Server payloads in tests (contract samples)

Tests may only claim states the server can produce. The payloads come from `contract_samples/` at the repo root, recorded from the real server (`just samples` in `backend/` regenerates them; the backend suite fails while they are stale). `test/helpers/contract/`:
- `contract_samples.dart` loads them (`dart:io`, found from the working directory upwards; `ContractSamples.map(name)`, `bodyFor(method, path, status:)`).
- `server_json.dart` builds payloads FROM a sample, changing values only (a key the sample lacks throws): `serverPrompt(kind)`, `serverNightResult(kind, info:)`, `serverPlayerList`, `serverResults`, `serverLobby`, `serverLogEntry`. `GameMeJsonBuilder` (`/me/` per phase; TitleCase roles only; window 1 only with a Doppelganger in the deck) and `GameEvents` (no `phase_change` to the night, no `connected` in `/me/` players) work the same way. `GameTestSetup` registers `/me/`, the player list (presence, `away:`), and the server's own bodies for action/vote/end-discussion and `registerPost` defaults.
- `contract_shape.dart` is the guard: every body registered on `MockHttpClient` (hook installed by `test/flutter_test_config.dart`) and every event pushed with `MockWebSocketChannel.addServerEvent` must match the samples of that endpoint+status / event type: no key path the server never sends, no other JSON type, no always-sent key missing (dictionary keys such as role names and player ids are wildcards). It does not check values or which keys belong to which phase. A test about malformed input says so: `thenReturn(..., offContract: true)`, `registerGet(..., offContract: true)`, `addOffContractEvent`. 5xx bodies are not checked.
- Strict mocks: a request with no registered response fails the test (reported to the test zone even if the app swallows the error); an error status is answered as a failed request with its body. `MockWebSocketChannel.send` fails (the server takes no client messages) unless made with `acceptsSends: true` (socket plumbing tests only).
- The web integration test cannot read files: its mock bodies are in `integration_test/helpers/server_bodies.dart`, checked against the samples by `contract_guard_test.dart`.

## Fonts in tests

`test/flutter_test_config.dart` loads every family in the build's FontManifest (the bundled Gloock and Figtree in `assets/fonts/`, and MaterialIcons) via `test/helpers/test_fonts.dart`, so widget tests, goldens and the screen gallery draw real glyphs for those. Families the app names but does not bundle are drawn in Figtree stand-ins: `Roboto` (Material's default, used by the test theme) and the old look's google_fonts families (until the old look is removed). Build old-theme styles in a unit test through `quietRetiredFonts` to keep google_fonts' load errors for those families out of the output. Delete the retired section of `test_fonts.dart` with the old look. The fonts' OFL licences are registered for the licences page in `lib/main.dart`.

## Goldens

One baseline set, in `test/design_system/goldens/`, made on Linux. Golden-tagged tests are skipped on other OSes (`dart_test.yaml`): font rasterisation differs per OS, and CI (Linux) is the source of truth. Regenerate with `just flutter-golden-update` on Linux, or from the CI workflow (see `.github/workflows/flutter-tests.yml`). Failure diffs go to `test/design_system/failures/` (gitignored).

## Screen gallery

`just screens [width] [report|strict]` (also from the root) renders every screen in the catalogue from the real widgets, in the app's theme, with images precached, to `build/screens/<id>.png` at 390x844 (2x), puts each next to its mock in `build/screens/compare/`, and prints a summary (also in `summary.txt`) of the layout overflows and exceptions caught per screen. Text in the old theme's fonts is drawn in Figtree stand-ins (see above). `just screens 360` renders 360 wide into `build/screens/w360/`; `just screens 390 strict` exits non-zero on findings; any other argument is refused. A screen whose builder throws is reported as BUILD FAILED and always fails the run, with no PNG. It needs no backend and lives in `test_screens/`, outside `test/`, so `just test` never runs it (the same structural exclusion as `test_e2e/`); `test_screens/flutter_test_config.dart` reuses the test config, and `screen_gallery_test.dart` there proves the detector on every run. Every screen and state is one entry in `test_screens/screen_catalogue.dart`; `screen_fixtures.dart` reaches each state through the server's own payloads and events (no state the server cannot produce). A mock screen the app lacks, or cannot reach, is a `ScreenEntry.notBuilt` with the reason.
