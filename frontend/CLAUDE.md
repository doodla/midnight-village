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
