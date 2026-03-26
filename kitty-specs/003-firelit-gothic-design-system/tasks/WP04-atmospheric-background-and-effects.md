---
work_package_id: WP04
title: AtmosphericBackground & Decorative Effects
lane: "approved"
dependencies: [WP03]
requirement_refs: [FR-008, FR-012, FR-006]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 003-firelit-gothic-design-system-WP03
base_commit: 883dee899fa7b3599f85bd716c8912f1f811663c
created_at: '2026-03-26T09:20:41.152498+00:00'
subtasks:
- T019
- T020
- T021
- T022
phase: Phase 2 - Foundation Widgets
assignee: ''
agent: headless-reviewer
shell_pid: '93224'
review_status: "approved"
reviewed_by: "Sridhar Vadlamani"
history:
- timestamp: '2026-03-26T08:24:14Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP04 – AtmosphericBackground & Decorative Effects

## IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes.

*[This section is empty initially.]*

---

## Markdown Formatting
Wrap HTML/XML tags in backticks: `` `<div>` ``, `` `<script>` ``
Use language identifiers in code blocks: ````python`, ````bash`

---

## Objectives & Success Criteria

- Build the `AtmosphericBackground` ConsumerWidget with phase-specific backgrounds, candle glow, and noise grain overlays
- Verify decorative effects (`AppShadows`, `AppDecorations`) render correctly on containers
- **Success**: Widget tests verify correct background color for all 5 game phases. Noise overlay and glow effects render when enabled. Decorative effects apply without errors (SC-003).

## Context & Constraints

- **Spec**: `kitty-specs/003-firelit-gothic-design-system/spec.md` — User Stories 2 and 6
- **Contract**: `kitty-specs/003-firelit-gothic-design-system/contracts/atmospheric_background.dart`
- **Token map**: `docs/stitch/token-map.md` — shadow/glow token values
- **Data model**: `kitty-specs/003-firelit-gothic-design-system/data-model.md`
- **Directive**: TEST_FIRST enforced
- **Dependencies**: WP03 (TestThemeTokens and FirelitGothicTheme must compile)
- **This is the most visible single component in the app** — it appears on ALL 15 screens

**Implementation command**: `spec-kitty implement WP04 --base WP03`

## Subtasks & Detailed Guidance

### Subtask T019 – Write AtmosphericBackground widget tests

- **Purpose**: TEST_FIRST — establish test expectations for the atmospheric background widget.
- **Steps**:
  1. Create `frontend/test/design_system/components/foundation/atmospheric_background_test.dart`:
     ```dart
     import 'package:flutter_test/flutter_test.dart';
     import 'package:flutter_riverpod/flutter_riverpod.dart';
     // import AtmosphericBackground, GamePhase, TestThemeTokens, pumpWithTokens helper

     void main() {
       group('AtmosphericBackground', () {
         testWidgets('renders night phase background color', (tester) async {
           await pumpWithTokens(tester, AtmosphericBackground(
             phase: GamePhase.night,
             child: Text('Night'),
           ));
           // Verify background container has nightBg color from TestThemeTokens
         });

         testWidgets('renders lobby phase background color', (tester) async {
           // Verify lobbyBg color
         });

         testWidgets('renders discussion phase background color', (tester) async {
           // Verify discussionBg color
         });

         testWidgets('renders voting phase background color', (tester) async {
           // Verify votingBg color
         });

         testWidgets('renders results phase background color', (tester) async {
           // Verify resultsBg color
         });

         testWidgets('shows noise overlay when enabled', (tester) async {
           // Verify Image.asset is present with noise texture
         });

         testWidgets('shows glow effect when enabled', (tester) async {
           // Verify gradient decoration is present
         });

         testWidgets('renders child widget on top', (tester) async {
           // Verify child Text is findable
         });

         testWidgets('consumes tokens from activeThemeProvider', (tester) async {
           // Pump with TestThemeTokens, verify colors match test theme
         });
       });
     }
     ```
  2. Use `pumpWithTokens` helper from `frontend/test/design_system/test_helpers/pump_with_tokens.dart`
- **Files**: `frontend/test/design_system/components/foundation/atmospheric_background_test.dart` (new, ~100 lines)
- **Parallel?**: Yes — can write in parallel with T021

### Subtask T020 – Implement AtmosphericBackground ConsumerWidget

- **Purpose**: Build the phase-aware background wrapper (FR-008).
- **Steps**:
  1. Create `frontend/lib/design_system/components/foundation/atmospheric_background.dart`:
     ```dart
     import 'package:flutter/material.dart';
     import 'package:flutter_riverpod/flutter_riverpod.dart';
     import '../../tokens/app_tokens_provider.dart';
     import '../../models/game_phase.dart';

     class AtmosphericBackground extends ConsumerWidget {
       final GamePhase phase;
       final Widget child;
       final bool showNoiseOverlay;
       final bool showGlow;

       const AtmosphericBackground({
         super.key,
         required this.phase,
         required this.child,
         this.showNoiseOverlay = true,
         this.showGlow = true,
       });

       @override
       Widget build(BuildContext context, WidgetRef ref) {
         final tokens = ref.watch(activeThemeProvider);
         final bgColor = _backgroundColorForPhase(tokens);

         return Stack(
           fit: StackFit.expand,
           children: [
             // Layer 1: Solid background color
             ColoredBox(color: bgColor),

             // Layer 2: Optional glow gradient
             if (showGlow)
               DecoratedBox(
                 decoration: BoxDecoration(
                   gradient: tokens.decorations.candleGlow,
                 ),
               ),

             // Layer 3: Optional noise overlay
             if (showNoiseOverlay)
               Opacity(
                 opacity: 0.03,
                 child: Image.asset(
                   tokens.decorations.noiseOverlayAsset,
                   repeat: ImageRepeat.repeat,
                   fit: BoxFit.none,
                 ),
               ),

             // Layer 4: Child content
             RepaintBoundary(child: child),
           ],
         );
       }

       Color _backgroundColorForPhase(AppTokens tokens) {
         return switch (phase) {
           GamePhase.night => tokens.colors.nightBg,
           GamePhase.lobby => tokens.colors.lobbyBg,
           GamePhase.discussion => tokens.colors.discussionBg,
           GamePhase.voting => tokens.colors.votingBg,
           GamePhase.results => tokens.colors.resultsBg,
         };
       }
     }
     ```
  2. Verify T019 tests pass
- **Files**: `frontend/lib/design_system/components/foundation/atmospheric_background.dart` (new, ~60 lines)
- **Parallel?**: No — must follow T019 (TEST_FIRST)
- **Notes**: Use `RepaintBoundary` around child to prevent unnecessary repaints. The `switch` expression pattern requires Dart 3.0+. Noise overlay at ~3% opacity (`0.03`).

### Subtask T021 – Write decorative effects render tests

- **Purpose**: Verify `AppShadows` and `AppDecorations` render without errors (User Story 6).
- **Steps**:
  1. Add tests (either in the atmospheric background test file or a new file):
     ```dart
     group('Decorative Effects', () {
       testWidgets('AppShadows.fireGlow renders on container', (tester) async {
         await pumpWithTokens(tester, Container(
           decoration: BoxDecoration(
             boxShadow: AppShadows.fireGlow,
           ),
           child: SizedBox(width: 100, height: 100),
         ));
         expect(tester.takeException(), isNull);
       });

       testWidgets('AppDecorations.visionGlow renders on container', (tester) async {
         await pumpWithTokens(tester, Container(
           foregroundDecoration: BoxDecoration(
             gradient: AppDecorations.visionGlow,
           ),
           child: SizedBox(width: 100, height: 100),
         ));
         expect(tester.takeException(), isNull);
       });

       testWidgets('AppDecorations.bloodVignette renders on container', (tester) async {
         // Similar verification
       });

       testWidgets('AppDecorations.candleGlow renders on container', (tester) async {
         // Similar verification
       });
     });
     ```
- **Files**: `frontend/test/design_system/components/foundation/atmospheric_background_test.dart` (extend) or new test file
- **Parallel?**: Yes — can write in parallel with T019

### Subtask T022 – Verify acceptance scenarios for US2 + US6

- **Purpose**: Manual acceptance verification that all User Story 2 and User Story 6 scenarios pass.
- **Steps**:
  1. Review US2 acceptance scenarios (5 phases with correct colors) — verified by T019 tests
  2. Review US6 acceptance scenarios (decorative effects on containers) — verified by T021 tests
  3. Run all tests: `cd frontend && flutter test test/design_system/components/foundation/`
  4. Document any gaps in the activity log
- **Files**: No new files
- **Parallel?**: No — must follow T020 and T021

## Test Strategy

**TEST_FIRST**: T019 and T021 write tests before T020 implements the widget.

Run:
```bash
cd frontend && flutter test test/design_system/components/foundation/atmospheric_background_test.dart
```

Key test areas:
- Background color correctness for all 5 phases (using TestThemeTokens, NOT hardcoded values)
- Noise overlay visibility toggling
- Glow effect visibility toggling
- Child widget rendering
- Decorative effects render without exceptions

## Risks & Mitigations

- **Noise overlay performance on low-end devices** → Pre-rendered 512x512 PNG at 3% opacity (not a shader)
- **Asset not found in tests** → `assets/textures/` registered in pubspec.yaml (WP01 T004); tests may need `rootBundle` mock or asset directory setup
- **Phase enum exhaustiveness** → Dart 3 switch expression ensures all phases handled

## Review Guidance

- Verify Stack layer order: solid color → glow gradient → noise overlay → child
- Verify `RepaintBoundary` wraps the child
- Verify `_backgroundColorForPhase` handles all 5 `GamePhase` values
- Verify noise overlay uses `ImageRepeat.repeat` for tiling
- Verify decorative effects tests cover all 4 presets from US6

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

- 2026-03-26T08:24:14Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:
1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP04 --to <lane> --note "message"` (recommended)

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
- 2026-03-26T09:20:41Z – headless-impl – shell_pid=87147 – lane=doing – Assigned agent via workflow command
- 2026-03-26T09:24:01Z – headless-impl – shell_pid=87147 – lane=for_review – Ready for review: AtmosphericBackground ConsumerWidget with phase backgrounds, candle glow, noise overlay (3% opacity), RepaintBoundary child wrapping. 18 tests cover all 5 GamePhase colors, overlay toggling, decorative effects (AppShadows + AppDecorations). flutter analyze clean for new files.
- 2026-03-26T09:24:13Z – headless-reviewer – shell_pid=93224 – lane=doing – Started review via workflow command
- 2026-03-26T09:25:25Z – headless-reviewer – shell_pid=93224 – lane=approved – Review passed: AtmosphericBackground ConsumerWidget with correct 5-layer stack order, all 5 GamePhase backgrounds verified via TestThemeTokens (no hardcoded values), noise overlay/glow toggling tested, RepaintBoundary confirmed, decorative effects (AppShadows + AppDecorations) render without exceptions. 18/18 tests pass, flutter analyze clean.
