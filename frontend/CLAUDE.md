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

- `just test-harness` runs the deterministic e2e harness in `test_e2e/` and boots (and stops) the harness backend on `:8001` itself. The API runner replays all 29 reference games from `backend/tests/onuw/data/reference_games.json` through the two-window night and asserts the debug-state oracle; the UI runner plays a subset through the real widget tree with a live WebSocket and writes per-player PNG filmstrips. It is intentionally NOT under `test/` and NOT part of `just test`. Full docs: `docs/dev/debug-harness/`.
- The night is two windows: a player may get a prompt, submit, then wait with no result until the window closes (`submitAction` shows waiting); results arrive together and are held until dismissed; the Doppelganger's look result arrives with her follow-up prompt in the same window; `skip` is the "do nothing" control wherever the server's prompt lists it.
- Shared test helper `MockHttpClient` lives in `integration_test/helpers/` (the web integration build cannot import out of its root); `test/helpers/mock_http_client.dart` re-exports it.
- `/debug` route (dev-only, gated by const `Env.isDev` so it tree-shakes out of prod) — the debug toolbar: spin up a table, switch player perspectives, god panel, auto-drive. Core lives in `lib/core/debug/`.

## Fonts in tests

`test/flutter_test_config.dart` loads every family in the build's FontManifest (the bundled Gloock and Figtree in `assets/fonts/`, and MaterialIcons) via `test/helpers/test_fonts.dart`, so widget tests, goldens and the screen gallery draw real glyphs for those. Families the app names but does not bundle are drawn in Figtree stand-ins: `Roboto` (Material's default, used by the test theme) and the old look's google_fonts families (until the old look is removed). Build old-theme styles in a unit test through `quietRetiredFonts` to keep google_fonts' load errors for those families out of the output. Delete the retired section of `test_fonts.dart` with the old look. The fonts' OFL licences are registered for the licences page in `lib/main.dart`.

## Goldens

One baseline set, in `test/design_system/goldens/`, made on Linux. Golden-tagged tests are skipped on other OSes (`dart_test.yaml`): font rasterisation differs per OS, and CI (Linux) is the source of truth. Regenerate with `just flutter-golden-update` on Linux, or from the CI workflow (see `.github/workflows/flutter-tests.yml`). Failure diffs go to `test/design_system/failures/` (gitignored).

## Screen gallery

`just screens [width] [report|strict]` (also from the root) renders every screen in the catalogue from the real widgets, in the app's theme, with images precached, to `build/screens/<id>.png` at 390x844 (2x), puts each next to its mock in `build/screens/compare/`, and prints a summary (also in `summary.txt`) of the layout overflows and exceptions caught per screen. Text in the old theme's fonts is drawn in Figtree stand-ins (see above). `just screens 360` renders 360 wide into `build/screens/w360/`; `just screens 390 strict` exits non-zero on findings; any other argument is refused. A screen whose builder throws is reported as BUILD FAILED and always fails the run, with no PNG. It needs no backend and lives in `test_screens/`, outside `test/`, so `just test` never runs it (the same structural exclusion as `test_e2e/`); `test_screens/flutter_test_config.dart` reuses the test config, and `screen_gallery_test.dart` there proves the detector on every run. Every screen and state is one entry in `test_screens/screen_catalogue.dart`; `screen_fixtures.dart` reaches each state through the server's own payloads and events (no state the server cannot produce). A mock screen the app lacks, or cannot reach, is a `ScreenEntry.notBuilt` with the reason.
