---
work_package_id: WP08
title: Developer Documentation & Living Examples
lane: done
dependencies: [WP03, WP04, WP05, WP06, WP07]
requirement_refs: [FR-012]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: main
base_commit: b06b6673254fde884781bab1f508f24806548e06
created_at: '2026-03-26T07:12:32.788500+00:00'
subtasks:
- T037
- T038
- T039
phase: Phase 3 - Polish
assignee: ''
agent: headless-reviewer
shell_pid: '38074'
review_status: approved
reviewed_by: Sridhar Vadlamani
history:
- timestamp: '2026-03-25T23:55:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP08 – Developer Documentation & Living Examples

## IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately (right below this notice).
- **You must address all feedback** before your work is complete. Feedback items are your implementation TODO list.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.
- **Report progress**: As you address each feedback item, update the Activity Log explaining what you changed.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes. Implementation must address every item listed below before returning for re-review.

*[This section is empty initially. Reviewers will populate it if the work is returned from review. If you see feedback here, treat each item as a must-do before completion.]*

---

## Markdown Formatting
Wrap HTML/XML tags in backticks: `` `<div>` ``, `` `<script>` ``
Use language identifiers in code blocks: ````python`, ````bash`

---

## Objectives & Success Criteria

Write clear documentation so any developer new to the project can write, run, update, and debug tests across all three layers. Ensure all example tests serve as living documentation automatically validated by CI.

**Success criteria**:
- A developer unfamiliar with the test setup follows the documentation to write a golden test, an integration test, and a harness-backed widget test — each in under 5 minutes
- All example tests from WP03, WP04, WP05 pass in both local and CI environments
- The README includes quick-start snippets, layer overview, and troubleshooting guide

**Implementation command**: `spec-kitty implement WP08 --base WP07`

## Context & Constraints

- **Spec**: `kitty-specs/002-flutter-ui-test-infrastructure/spec.md` — User Story 6; FR-012
- **Depends on all previous WPs**: Documentation must cover the complete test infrastructure
- **Constraint**: Example tests from WP03, WP04, WP05 ARE the living documentation — no separate "example" directory needed beyond what already exists
- **Constraint**: README should be structured with quick-start snippets at top (copy-paste friendly) and detailed explanations below

## Subtasks & Detailed Guidance

### Subtask T037 – Write `frontend/test/README.md`

- **Purpose**: Provide a comprehensive testing guide that serves as the single source of truth for the project's test infrastructure.
- **Steps**:
  1. Create `frontend/test/README.md`
  2. Structure the document:
     ```markdown
     # Testing Guide

     ## Quick Start
     ```bash
     just flutter-test             # All widget tests
     just flutter-test-golden      # Golden tests only
     just flutter-golden-update    # Update golden baselines
     just flutter-test-integration # Integration tests (Chrome)
     just flutter-golden-report    # Visual diff report
     just flutter-golden-check     # Golden tests + auto-report
     ```

     ## Test Layers
     ### Widget Tests
     - What they test, when to use them
     - Example: link to WP04 harness examples

     ### Golden Tests
     - What they test, when to use them
     - How to write a golden test (copy-paste template)
     - How to update baselines
     - Platform-specific baselines (macOS vs Linux)
     - Example: link to WP03 golden test examples

     ### Integration Tests
     - What they test, when to use them
     - How to write an integration test
     - Mock HTTP setup
     - Navigation assertions
     - Example: link to WP05 auth flow test

     ## Test Harnesses
     - `pumpWithTokens` — theme-aware widget testing
     - `pumpWithGolden` — golden test rendering
     - `pumpAuthenticated` — authenticated user state
     - `pumpWithGameState` — game phase scenarios
     - `pumpApp` — full app with mock layers

     ## Troubleshooting
     - Font loading failures
     - Platform baseline mismatches
     - Chrome headless setup
     - Golden test non-determinism
     - Integration test timeouts
     ```
  3. Include copy-paste-ready code snippets for each test type
  4. Reference justfile commands prominently — they're the primary developer interface
- **Files**: `frontend/test/README.md` (new, ~200 lines)
- **Parallel?**: Yes — independent of T038/T039
- **Notes**: The README is the entry point for new developers. Prioritize clarity and actionability over comprehensiveness. Quick-start at the top, details below. Link to example files rather than duplicating code.

### Subtask T038 – Add descriptive comments to all example tests

- **Purpose**: Ensure example tests from WP03, WP04, WP05 include clear comments explaining the pattern for copy-paste reuse.
- **Steps**:
  1. Review all example test files created in previous WPs:
     - `frontend/test/design_system/components/core/mv_button_golden_test.dart` (WP03)
     - `frontend/test/design_system/components/game/role_card_golden_test.dart` (WP03)
     - `frontend/test/design_system/components/game/player_circle_golden_test.dart` (WP03)
     - `frontend/test/helpers/examples/authenticated_harness_test.dart` (WP04)
     - `frontend/test/helpers/examples/game_state_harness_test.dart` (WP04)
     - `frontend/test/helpers/examples/websocket_harness_test.dart` (WP04)
     - `frontend/integration_test/auth_flow_test.dart` (WP05)
  2. For each file, add/verify:
     - A top-of-file comment block explaining what pattern this demonstrates
     - Inline comments on non-obvious setup steps
     - A "Copy this template" section with the minimal boilerplate needed
  3. Keep comments concise — explain the "why" and "how to adapt", not the obvious
- **Files**: All example test files from WP03, WP04, WP05 (modify, ~5-10 lines per file)
- **Parallel?**: No — depends on WP03, WP04, WP05 being complete
- **Notes**: Comments should be additive, not replacing existing code. Focus on making each file a self-contained template that a developer can copy and adapt for a new component/flow.

### Subtask T039 – Validate living documentation in local + CI

- **Purpose**: Confirm all example tests pass in both environments and are properly referenced in the README.
- **Steps**:
  1. Run all test layers locally:
     ```bash
     just flutter-test           # Widget tests (including harness examples)
     just flutter-test-golden    # Golden tests
     just flutter-test-integration  # Integration tests
     ```
  2. Verify all example tests pass
  3. Check that CI runs include the example tests (they should be picked up automatically)
  4. Cross-reference README.md against actual file paths — verify all links/references are correct
  5. Add a note in README.md about which examples to use as templates:
     ```markdown
     ## Template Files
     - Golden test template: `test/design_system/components/core/mv_button_golden_test.dart`
     - Harness template: `test/helpers/examples/authenticated_harness_test.dart`
     - Integration template: `integration_test/auth_flow_test.dart`
     ```
- **Files**: `frontend/test/README.md` (modify if needed), validation of all example tests
- **Parallel?**: No — depends on T037, T038
- **Notes**: This is the final validation step for the entire feature. All test layers should be working and documented. If any example tests fail, fix them before marking this WP complete.

## Test Strategy

The example tests ARE the living documentation — their passing validates the docs:

1. **Local validation**: `just flutter-test`, `just flutter-test-golden`, `just flutter-test-integration` all pass
2. **CI validation**: Same tests pass in CI (verified via WP07)
3. **Documentation accuracy**: README file paths match actual file locations

## Risks & Mitigations

- **Documentation rot**: Mitigated by making example tests runnable — they fail if they drift from the actual API. No separate documentation tests needed.
- **Example tests may have been written with slightly different APIs**: Review and update comments to match the final implementation, not the initial plan.

## Review Guidance

- Verify README covers all three test layers with quick-start snippets
- Verify README references actual justfile commands
- Verify all example test files have descriptive comments
- Verify all example tests pass locally
- Verify README file paths match actual project structure
- Verify troubleshooting section covers common issues discovered during implementation

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

### How to Add Activity Log Entries

**When adding an entry**:
1. Scroll to the bottom of this file (Activity Log section below "Valid lanes")
2. **APPEND the new entry at the END** (do NOT prepend or insert in middle)
3. Use exact format: `- YYYY-MM-DDTHH:MM:SSZ – agent_id – lane=<lane> – <action>`
4. Timestamp MUST be current time in UTC (ISO-8601 `YYYY-MM-DDTHH:MM:SSZ`) and should be generated without shell commands (prefer `NOW_UTC_ISO` from `check-prerequisites --json --paths-only`)
5. Lane MUST match the frontmatter `lane:` field exactly
6. Agent ID should identify who made the change (claude-sonnet-4-5, codex, etc.)

**Format**:
```
- YYYY-MM-DDTHH:MM:SSZ – <agent_id> – lane=<lane> – <brief action description>
```

**Initial entry**:
- 2026-03-25T23:55:37Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:

1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP08 --to <lane> --note "message"` (recommended)

The CLI command updates both frontmatter and activity log automatically.

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
- 2026-03-26T07:12:33Z – headless-impl – shell_pid=31555 – lane=doing – Assigned agent via workflow command
- 2026-03-26T07:16:52Z – headless-impl – shell_pid=31555 – lane=for_review – Ready for review: frontend/test/README.md created with quick-start commands, three-layer test overview, harness API reference, and troubleshooting guide; descriptive template comments added to all 4 example test files; 193 widget tests pass
- 2026-03-26T07:17:03Z – headless-reviewer – shell_pid=38074 – lane=doing – Started review via workflow command
- 2026-03-26T07:21:27Z – headless-reviewer – shell_pid=38074 – lane=approved – Review passed
