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
