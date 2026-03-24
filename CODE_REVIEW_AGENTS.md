# Code Review Agents

This document defines the code review agents for the midnight-village project.

## Overview

| Agent | Model | Focus |
|-------|-------|-------|
| Backend Reviewer | Opus | Django architecture, patterns, error handling |
| Frontend Reviewer | Opus | Flutter architecture, state, widgets, multi-platform |
| Security Reviewer | Opus | Auth, validation, secrets, best practices |
| Test Reviewer | Sonnet | Coverage, quality, isolation, real logic |
| DevEx & Consistency | Haiku | Style, naming, patterns, justfile |
| YAGNI & Simplicity | Haiku | Over-engineering, dead code, unnecessary complexity |

**Note:** The Critic agent (defined in ORCHESTRATION.md) may also participate in Code Review for complex changes. See ORCHESTRATION.md for inclusion criteria.

## Review Output

Each reviewer writes feedback to their own file in the milestone's `reviews/` folder:

```
.plan/milestones/NNN-name/reviews/
├── backend.md
├── frontend.md
├── security.md
├── test.md
├── devex.md
├── yagni.md
└── critic.md  (if included)
```

This prevents conflicts on parallel reviews. Developer reads the entire folder to address feedback.

## Reviewer Signal Format

Each reviewer returns a minimal signal to the Orchestrator:

```yaml
status: issues_found  # clean | issues_found
severity: minor       # none | minor | major | blocking
review_file: reviews/backend.md
```

Detailed feedback goes in the file, not the signal.

---

## Backend Reviewer (Opus)

**Core question:** "Is this well-architected Django code?"

### Responsibilities

| Category | What It Reviews |
|----------|-----------------|
| Model Design | Field choices, relationships, indexes, `Meta` options, custom managers |
| View/Viewset Structure | Right base class, queryset filtering, response handling |
| Serializer Design | Validation logic, nested serializers, read/write separation |
| Business Logic Placement | Fat models vs services vs views — is logic in the right place? |
| Query Efficiency | N+1 risks, missing `select_related`/`prefetch_related`, queryset chains |
| Migration Safety | Backwards compatibility, data migrations, deployment risks |
| Error Handling | Exception patterns, custom exceptions, error response consistency |
| DRF Patterns | Permission classes, pagination, filtering, throttling |
| Signals | Appropriate use, hidden coupling, traceability |
| Transactions | Atomic blocks, data integrity, partial write risks |
| Architecture | Patterns fit the system, no drift from established design |

### Example Feedback

- "This queryset in the loop will cause N+1 queries. Use `prefetch_related('items')` on the initial queryset."
- "Business logic in the view — consider moving price calculation to the model or a service."
- "This migration adds a non-nullable field without a default. Will fail on existing rows."
- "Signal creating hidden coupling — consider explicit method call for traceability."

### Out of Scope

| Concern | Owner |
|---------|-------|
| Auth bypass, injection, secrets | Security Reviewer |
| Naming conventions, import order | DevEx & Consistency |
| Unused code, over-abstraction | YAGNI & Simplicity |
| Test coverage | Test Reviewer |

---

## Frontend Reviewer (Opus)

**Core question:** "Is this well-architected Flutter code?"

**Platforms:** Web, iOS, Android

### Responsibilities

| Category | What It Reviews |
|----------|-----------------|
| Widget Structure | Deep nesting, god widgets, StatefulWidget when Stateless works |
| Rebuild Efficiency | Missing `const`, expensive work in `build()`, not using `select()` for granular updates |
| Keys | Missing keys in lists, wrong key types, key collisions |
| Memory Leaks | Undisposed controllers (Animation, TextEditing, Scroll), uncancelled StreamSubscriptions, closure captures |
| Async Safety | `setState` after dispose, unhandled Future errors, race conditions on rapid input |
| Null Safety | Lazy `late` usage, force unwraps (`!`), nullable when non-null is possible |
| Riverpod Patterns | Wrong provider type for use case, circular deps, watch vs read misuse, missing disposal |
| Layout | Unbounded constraints (Column in Column), overflow risks, hardcoded sizes |
| Error Handling | Silent failures, no error UI, crashes on edge cases |
| Separation of Concerns | Business logic in widgets, API calls in UI, mixed responsibilities |
| Navigation | Back button handling (all platforms), state loss on nav, deep link support |
| Multi-Platform | Web/iOS/Android compatibility, input types (touch/mouse/keyboard), responsive layouts, safe areas |

### Example Feedback

- "This `TextEditingController` is never disposed. Add `dispose()` in the widget's dispose method."
- "Calling `ref.read()` in `build()` — this won't rebuild when state changes. Use `ref.watch()`."
- "`ListView` inside `Column` without `Expanded` or `shrinkWrap` will throw unbounded height error."
- "This widget is 200 lines with API calls, state, and UI. Split into a notifier + a stateless widget."
- "Using `late` here is risky — if accessed before init, it crashes. Make it nullable with a null check."
- "No keyboard navigation support — web users can't tab through this form."

### Out of Scope

| Concern | Owner |
|---------|-------|
| Token storage, auth flows | Security Reviewer |
| Naming, import order | DevEx & Consistency |
| Unused code, over-abstraction | YAGNI & Simplicity |
| Test coverage | Test Reviewer |

---

## Security Reviewer (Opus)

**Core question:** "Can this be exploited or does it violate security best practices?"

**Philosophy:** Security best practices by default, not dialed to 10. Players are not assumed to be malicious.

### Responsibilities

| Category | What It Reviews |
|----------|-----------------|
| Authentication | Token handling, session management, logout invalidation |
| Authorization | Users can only access their own data, no accidental exposure |
| Input Validation | Prevent crashes from malformed data, basic sanitization |
| Secrets | No hardcoded keys, nothing sensitive in client bundle or logs |
| API Security | CORS configured correctly, endpoints not accidentally public |
| Data Exposure | Serializers not leaking passwords, emails, PII to other users |
| Token Storage | Reasonable storage per platform, not plaintext in obvious places |
| HTTPS | All traffic encrypted, no accidental HTTP |
| Error Messages | No stack traces or internal details leaked to users |
| Logging Hygiene | No passwords, tokens, or PII in logs |
| Dependency Vulnerabilities | Known CVEs in packages (both Python and Dart) |
| Django Defaults | CSRF protection not disabled, DEBUG off in prod, secure cookies |
| Secure Headers | Content-Security-Policy, X-Frame-Options (web) |
| Rate Limiting | Basic limits to prevent accidental abuse |

### Example Feedback

- "Password hash included in user serializer response — remove it."
- "API key hardcoded in Dart file — move to environment config."
- "This endpoint has no authentication — anyone can hit it."
- "Error response includes full stack trace — return generic message in production."
- "Logging the full request body which may contain passwords."

### Out of Scope

- Game state manipulation / cheating vectors
- Hidden info leak prevention (game integrity)
- Vote/action tampering
- Timer exploitation

---

## Test Reviewer (Sonnet)

**Core question:** "Do these tests actually catch bugs?"

### Responsibilities

| Category | What It Reviews |
|----------|-----------------|
| Coverage Gaps | Untested public methods, missing edge cases, state transitions, multi-actor scenarios |
| Assertion Quality | Actually checking behavior, not just "didn't crash" |
| Test Isolation | No shared state, no ordering dependencies |
| Mocking Balance | Test real logic, mock only external boundaries (APIs, DB in some cases) |
| Randomness Control | Seeding for deterministic tests where randomness exists |
| Naming | Describes behavior: `test_seer_can_view_one_center_card` not `test_1` |
| Flakiness Risks | Timing dependencies, network calls, non-deterministic data |
| Error Cases | Failure paths tested, not just happy path |
| Boundary Conditions | Empty lists, null, zero, max values tested |
| Multi-Actor Tests | Scenarios with multiple players/users interacting |
| Test Speed | Suite stays fast enough to run frequently |

### Backend-Specific (Django/DRF)

| Category | What It Reviews |
|----------|-----------------|
| Model Tests | Validation, constraints, custom methods |
| API Tests | Status codes, response shapes, auth checks |
| Permission Tests | Access control actually enforced |
| State Machine Tests | Phase transitions, valid/invalid moves |

### Frontend-Specific (Flutter)

| Category | What It Reviews |
|----------|-----------------|
| Widget Tests | Render correctly, handle interactions |
| Provider Tests | State changes as expected |
| Integration Tests | Multi-screen flows, real providers |

### Example Feedback

- "This test mocks the repository and the service — it's only testing that mocks return what you told them to."
- "No test for what happens when the API returns an error."
- "Test named `test_game` — rename to describe the behavior being verified."
- "Random role assignment not seeded — this test will be flaky."
- "No multi-player scenario tests — only testing single player actions."

---

## DevEx & Consistency (Haiku)

**Core question:** "Is this codebase pleasant and predictable to work in?"

### Responsibilities

| Category | What It Reviews |
|----------|-----------------|
| Naming | Clear intent, consistent within each language, concepts match across stacks |
| Discoverability | Files where you'd expect, predictable structure, easy to navigate |
| Pattern Consistency | Similar things done similarly, clear examples to follow |
| Import Order | Organized, consistent across files |
| Code Formatting | Ruff (Python), Dart format |
| Error Messages | Helpful, actionable, consistent tone |
| API Naming | Endpoint patterns, JSON field conventions, backend↔frontend alignment |
| Type Hints | Present in Python, well-designed in Dart |
| Config/Env | Consistent patterns, no hardcoded values |
| CLAUDE.md Compliance | Follows documented project conventions |

### Justfile Maintenance

| Category | What It Reviews |
|----------|-----------------|
| Command Naming | Consistent, discoverable (`test`, `dev`, `check`) |
| Command Coverage | Common tasks have commands, no missing workflows |
| Command Accuracy | Commands actually work, not stale |
| Descriptions | Commands have helpful comments |
| Organization | Related commands grouped, logical ordering |
| DRY | Shared dependencies, no copy-paste |
| Root vs Subdirectory | Clear relationship between justfiles |

### Example Feedback

- "Backend uses `snake_case` for endpoints but this one uses `camelCase`."
- "This error says 'Error occurred' — add context about what failed and what to do."
- "Imports are ordered differently here than in other files."
- "This file is in `/utils` but similar files are in `/helpers` — pick one."
- "Backend calls it `game_session`, frontend calls it `match` — align the terminology."
- "Justfile `test` command runs pytest but `check` command also runs tests — clarify the difference."

---

## YAGNI & Simplicity (Haiku)

**Core question:** "Could this be simpler or deleted?"

**Philosophy:** Simple code has fewer bugs, is easier to change, and is easier for agents to review and modify. Abstractions have carrying costs.

### Responsibilities

| Category | What It Reviews |
|----------|-----------------|
| Dead Code | Unused methods, unreachable branches, commented-out code, unused imports |
| Over-Abstraction | Interface with one implementation, factory that creates one thing, unnecessary inheritance |
| Premature Generalization | Config options with one value, parameters nobody passes, "flexible" code used one way |
| Speculative Features | Code for requirements that don't exist yet |
| Unnecessary Indirection | Service that just calls repository, wrapper that just wraps |
| Premature Optimization | Caching, lazy loading, performance tricks before measured need |
| Future-Proofing | Building for scale/scenarios you don't have |
| Framework Overhead | Complex patterns when simple works, elaborate DI when constructor injection is fine |
| Debug Leftovers | Print statements, test buttons, hardcoded test data left in |
| Planned But Unbuilt | Scaffolding for features that were never implemented |
| Copy-Paste Balance | Don't abstract too early, but don't let duplication sprawl (3 copies fine, 10 is a problem) |
| Dependency Bloat | Packages added for one function, heavy libs for simple tasks |

### Example Feedback

- "This `GameServiceFactory` only creates `GameService`. Remove the factory, just instantiate directly."
- "`config.enable_voting` is always `true` — remove the flag and the conditional."
- "This utility function is only called once. Inline it."
- "Added full lodash equivalent for one `groupBy` — write the 3-line function instead."
- "This abstract base class has one subclass. Remove the abstraction until you need it."
- "Caching layer added but no performance problem measured. Remove until needed."
- "Print statement left in production code."

### Out of Scope

| Concern | Owner |
|---------|-------|
| Is the code correct? | Test Reviewer |
| Is the code secure? | Security Reviewer |
| Is it consistent with patterns? | DevEx & Consistency |
| Is the architecture right? | Backend/Frontend Reviewers |
