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

- `just test-harness` runs the deterministic e2e harness in `test_e2e/` — the real widget tree against a booted real backend on `:8001`, emitting per-player PNG filmstrips. It is intentionally NOT under `test/` and NOT part of `just test` (it needs the harness backend up: `cd backend && just harness-serve`). Full docs: `docs/dev/debug-harness/`.
- `/debug` route (dev-only, gated by const `Env.isDev` so it tree-shakes out of prod) — the debug toolbar: spin up a table, switch player perspectives, god panel, auto-drive. Core lives in `lib/core/debug/`.
