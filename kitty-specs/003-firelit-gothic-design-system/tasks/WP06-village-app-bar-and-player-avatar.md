---
work_package_id: WP06
title: VillageAppBar & PlayerAvatar Widgets
lane: "doing"
dependencies: [WP03]
requirement_refs: [FR-009, FR-011]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 003-firelit-gothic-design-system-WP03
base_commit: 883dee899fa7b3599f85bd716c8912f1f811663c
created_at: '2026-03-26T09:43:43.463470+00:00'
subtasks:
- T028
- T029
- T030
- T031
- T032
phase: Phase 2 - Foundation Widgets
assignee: ''
agent: ''
shell_pid: "20828"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-26T08:24:14Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP06 – VillageAppBar & PlayerAvatar Widgets

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

- Build `VillageAppBar` with 4 variants (brand, back, phase, minimal) covering 13 screens
- Build `PlayerAvatar` with initials, deterministic hue, and 3 sizes covering 11 screens
- **Success**: Widget tests verify all 4 VillageAppBar variants render without overflow. Widget tests verify PlayerAvatar deterministic colors, correct initials, and correct sizes (SC-004, SC-006).

## Context & Constraints

- **Spec**: `kitty-specs/003-firelit-gothic-design-system/spec.md` — User Stories 3 and 5
- **Contracts**: `kitty-specs/003-firelit-gothic-design-system/contracts/village_app_bar.dart` and `contracts/player_avatar.dart`
- **Directive**: TEST_FIRST enforced
- **Dependencies**: WP03 (TestThemeTokens and ThemeBridge must compile)
- **Priority**: P2 — can ship separately if needed, but included in planned scope

**Implementation command**: `spec-kitty implement WP06 --base WP03`

## Subtasks & Detailed Guidance

### Subtask T028 – Write VillageAppBar widget tests

- **Purpose**: TEST_FIRST — define all expected app bar behaviors for 4 variants.
- **Steps**:
  1. Create `frontend/test/design_system/components/foundation/village_app_bar_test.dart`:
     ```dart
     group('VillageAppBar', () {
       group('brand variant', () {
         testWidgets('shows castle icon and Midnight Village title', (tester) async {
           await pumpWithTokens(tester, Scaffold(
             appBar: VillageAppBar.brand(),
           ));
           expect(find.text('Midnight Village'), findsOneWidget);
           // Verify leading icon is present
         });

         testWidgets('renders trailing widget when provided', (tester) async {
           await pumpWithTokens(tester, Scaffold(
             appBar: VillageAppBar.brand(trailing: Icon(Icons.settings)),
           ));
           expect(find.byIcon(Icons.settings), findsOneWidget);
         });
       });

       group('back variant', () {
         testWidgets('shows back arrow and custom title', (tester) async {
           await pumpWithTokens(tester, Scaffold(
             appBar: VillageAppBar.back(title: 'Lobby'),
           ));
           expect(find.text('Lobby'), findsOneWidget);
           expect(find.byIcon(Icons.arrow_back), findsOneWidget);
         });

         testWidgets('back arrow pops navigator', (tester) async {
           // Push a route, render VillageAppBar.back, tap back, verify pop
         });
       });

       group('phase variant', () {
         testWidgets('shows gold phase label', (tester) async {
           await pumpWithTokens(tester, Scaffold(
             appBar: VillageAppBar.phase(label: 'DISCUSSION'),
           ));
           expect(find.text('DISCUSSION'), findsOneWidget);
         });

         testWidgets('renders timer in trailing slot', (tester) async {
           await pumpWithTokens(tester, Scaffold(
             appBar: VillageAppBar.phase(
               label: 'VOTING',
               trailing: Text('2:30'),
             ),
           ));
           expect(find.text('2:30'), findsOneWidget);
         });
       });

       group('minimal variant', () {
         testWidgets('shows role name', (tester) async {
           await pumpWithTokens(tester, Scaffold(
             appBar: VillageAppBar.minimal(roleName: 'SEER'),
           ));
           expect(find.text('SEER'), findsOneWidget);
         });
       });

       testWidgets('does not overflow at 320dp width', (tester) async {
         // Test brand variant in constrained width
         await pumpWithTokens(tester, SizedBox(
           width: 320,
           child: Scaffold(appBar: VillageAppBar.brand()),
         ));
         expect(tester.takeException(), isNull);
       });
     });
     ```
- **Files**: `frontend/test/design_system/components/foundation/village_app_bar_test.dart` (new, ~120 lines)
- **Parallel?**: Yes — fully independent of T030/T031 (PlayerAvatar)

### Subtask T029 – Implement VillageAppBar ConsumerWidget

- **Purpose**: Build the 4-variant app bar (FR-009).
- **Steps**:
  1. Create `frontend/lib/design_system/components/foundation/village_app_bar.dart`:
     ```dart
     class VillageAppBar extends ConsumerWidget implements PreferredSizeWidget {
       // Internal state for which variant
       final _VillageAppBarVariant _variant;
       final String? _title;
       final String? _label;
       final String? _roleName;
       final IconData? _icon;
       final Widget? trailing;

       // Named constructors for each variant
       const VillageAppBar.brand({super.key, this.trailing})
         : _variant = _VillageAppBarVariant.brand, ...;

       const VillageAppBar.back({super.key, required String title, this.trailing})
         : _variant = _VillageAppBarVariant.back, _title = title, ...;

       const VillageAppBar.phase({super.key, required String label, this.trailing})
         : _variant = _VillageAppBarVariant.phase, _label = label, ...;

       const VillageAppBar.minimal({super.key, required String roleName, IconData? icon, this.trailing})
         : _variant = _VillageAppBarVariant.minimal, _roleName = roleName, _icon = icon, ...;

       @override
       Size get preferredSize => const Size.fromHeight(kToolbarHeight);

       @override
       Widget build(BuildContext context, WidgetRef ref) {
         final tokens = ref.watch(activeThemeProvider);
         return AppBar(
           backgroundColor: Colors.transparent,
           elevation: 0,
           scrolledUnderElevation: 0,
           leading: _buildLeading(context, tokens),
           title: _buildTitle(tokens),
           actions: trailing != null ? [trailing!] : null,
         );
       }
       // ... _buildLeading and _buildTitle per variant
     }

     enum _VillageAppBarVariant { brand, back, phase, minimal }
     ```
  2. Brand: castle icon leading + "Midnight Village" title
  3. Back: `Icons.arrow_back` leading that calls `Navigator.of(context).pop()`
  4. Phase: No leading, phase label in `tokens.typography.phaseLabel` with gold color
  5. Minimal: No leading, role name with optional icon
  6. Verify T028 tests pass
- **Files**: `frontend/lib/design_system/components/foundation/village_app_bar.dart` (new, ~100 lines)
- **Parallel?**: No — follows T028 (TEST_FIRST)
- **Notes**: Implements `PreferredSizeWidget` to work with `Scaffold.appBar`. Transparent background integrates with `AtmosphericBackground`.

### Subtask T030 – Write PlayerAvatar widget tests

- **Purpose**: TEST_FIRST — define expected avatar behaviors.
- **Steps**:
  1. Create `frontend/test/design_system/components/foundation/player_avatar_test.dart`:
     ```dart
     group('PlayerAvatar', () {
       testWidgets('extracts single initial from single name', (tester) async {
         await pumpWithTokens(tester, PlayerAvatar(
           displayName: 'Alice',
           size: AvatarSize.medium,
         ));
         expect(find.text('A'), findsOneWidget);
       });

       testWidgets('extracts two initials from multi-word name', (tester) async {
         await pumpWithTokens(tester, PlayerAvatar(
           displayName: 'Bob Smith',
           size: AvatarSize.medium,
         ));
         expect(find.text('BS'), findsOneWidget);
       });

       testWidgets('shows ? for empty name', (tester) async {
         await pumpWithTokens(tester, PlayerAvatar(
           displayName: '',
           size: AvatarSize.medium,
         ));
         expect(find.text('?'), findsOneWidget);
       });

       testWidgets('deterministic hue - same name same color', (tester) async {
         // Render twice with same name, verify background color matches
       });

       testWidgets('renders small size at 32dp', (tester) async {
         await pumpWithTokens(tester, PlayerAvatar(
           displayName: 'Alice',
           size: AvatarSize.small,
         ));
         // Find the Container/SizedBox and verify size
       });

       testWidgets('renders medium size at 48dp', (tester) async {
         // similar
       });

       testWidgets('renders large size at 64dp', (tester) async {
         // similar
       });

       testWidgets('sigil overlay appears when provided', (tester) async {
         await pumpWithTokens(tester, PlayerAvatar(
           displayName: 'Carol',
           size: AvatarSize.medium,
           sigil: Icons.check,
         ));
         expect(find.byIcon(Icons.check), findsOneWidget);
       });

       testWidgets('consumes tokens from activeThemeProvider', (tester) async {
         // Verify uses test theme colors
       });
     });
     ```
- **Files**: `frontend/test/design_system/components/foundation/player_avatar_test.dart` (new, ~100 lines)
- **Parallel?**: Yes — fully independent of T028/T029 (VillageAppBar)

### Subtask T031 – Implement PlayerAvatar ConsumerWidget

- **Purpose**: Build the circular initials avatar with deterministic hue (FR-011).
- **Steps**:
  1. Create `frontend/lib/design_system/components/foundation/player_avatar.dart`:
     ```dart
     class PlayerAvatar extends ConsumerWidget {
       final String displayName;
       final AvatarSize size;
       final IconData? sigil;
       final Color? borderColor;
       final double borderWidth;

       const PlayerAvatar({
         super.key,
         required this.displayName,
         required this.size,
         this.sigil,
         this.borderColor,
         this.borderWidth = 0,
       });

       @override
       Widget build(BuildContext context, WidgetRef ref) {
         final tokens = ref.watch(activeThemeProvider);
         final hue = _deterministicHue(displayName);
         final bgColor = HSLColor.fromAHSL(1.0, hue, 0.4, 0.3).toColor();
         final initials = _extractInitials(displayName);

         return SizedBox(
           width: size.pixels,
           height: size.pixels,
           child: Stack(
             children: [
               Container(
                 decoration: BoxDecoration(
                   color: bgColor,
                   shape: BoxShape.circle,
                   border: borderWidth > 0
                     ? Border.all(color: borderColor ?? tokens.colors.outline, width: borderWidth)
                     : null,
                 ),
                 alignment: Alignment.center,
                 child: Text(
                   initials,
                   style: TextStyle(
                     color: tokens.colors.onSurface,
                     fontSize: _fontSizeForSize(size),
                     fontWeight: FontWeight.w600,
                   ),
                 ),
               ),
               if (sigil != null) _buildSigil(tokens),
             ],
           ),
         );
       }

       static double _deterministicHue(String name) {
         return (name.hashCode % 360).abs().toDouble();
       }

       static String _extractInitials(String name) {
         if (name.trim().isEmpty) return '?';
         final words = name.trim().split(RegExp(r'\s+'));
         if (words.length == 1) return words[0][0].toUpperCase();
         return '${words[0][0]}${words[1][0]}'.toUpperCase();
       }

       double _fontSizeForSize(AvatarSize size) => switch (size) {
         AvatarSize.small => 14,
         AvatarSize.medium => 18,
         AvatarSize.large => 24,
       };

       Widget _buildSigil(AppTokens tokens) {
         final sigilSize = size.pixels * 0.3;
         return Positioned(
           right: 0, bottom: 0,
           child: Container(
             width: sigilSize, height: sigilSize,
             decoration: BoxDecoration(
               color: tokens.colors.surface,
               shape: BoxShape.circle,
             ),
             child: Icon(
               sigil,
               size: sigilSize * 0.7,
               color: tokens.colors.onSurface,
             ),
           ),
         );
       }
     }
     ```
  2. Verify T030 tests pass
- **Files**: `frontend/lib/design_system/components/foundation/player_avatar.dart` (new, ~80 lines)
- **Parallel?**: No — follows T030 (TEST_FIRST)
- **Notes**: Deterministic hue via `displayName.hashCode % 360`. HSL with saturation 0.4, lightness 0.3 produces muted/dark colors fitting the palette.

### Subtask T032 – Verify acceptance scenarios for US3 + US5

- **Purpose**: Verify all User Story 3 and User Story 5 acceptance scenarios pass.
- **Steps**:
  1. Review US3 acceptance (4 VillageAppBar variants) — verified by T028 tests
  2. Review US5 acceptance (avatar sizes, deterministic colors, sigil) — verified by T030 tests
  3. Run all tests: `cd frontend && flutter test test/design_system/components/foundation/`
  4. Document results in activity log
- **Files**: No new files
- **Parallel?**: No — final verification step

## Test Strategy

**TEST_FIRST**: T028/T030 write tests before T029/T031 implement widgets.

**Parallel testing**: VillageAppBar (T028+T029) and PlayerAvatar (T030+T031) are fully independent — different files, no shared state.

Run:
```bash
cd frontend && flutter test test/design_system/components/foundation/village_app_bar_test.dart
cd frontend && flutter test test/design_system/components/foundation/player_avatar_test.dart
```

## Risks & Mitigations

- **VillageAppBar overflow on small screens** → Test with constrained width (320dp minimum)
- **PlayerAvatar hash collisions** → Acceptable; different names may produce same color; test verifies determinism, not uniqueness
- **Navigator.pop in tests** → Use `Navigator.push` to create a route stack before testing back button

## Review Guidance

- Verify VillageAppBar implements `PreferredSizeWidget`
- Verify all 4 variants render correct leading/title/trailing elements
- Verify `VillageAppBar.back` calls `Navigator.of(context).pop()`
- Verify `VillageAppBar.phase` uses `tokens.typography.phaseLabel`
- Verify PlayerAvatar initials extraction: single word → first letter, two words → first two letters, empty → "?"
- Verify deterministic hue: `displayName.hashCode % 360` → HSL(hue, 0.4, 0.3)
- Verify 3 sizes: 32dp, 48dp, 64dp

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

- 2026-03-26T08:24:14Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:
1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP06 --to <lane> --note "message"` (recommended)

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
