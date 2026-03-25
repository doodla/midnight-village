---
work_package_id: WP03
title: Core UI Components
lane: "doing"
dependencies: [WP01]
base_branch: 001-frontend-design-system-and-architecture-WP01
base_commit: 935942f5cd141c469c185ab7eaaf02e89a12078f
created_at: '2026-03-25T03:53:23.020031+00:00'
subtasks:
- T014
- T015
- T016
- T017
- T018
- T019
- T020
phase: Phase B - Core Components
assignee: ''
agent: "headless-impl"
shell_pid: "45500"
review_status: "has_feedback"
reviewed_by: "Sridhar Vadlamani"
review_feedback_file: "/private/var/folders/h1/g68scqh939n8kgw31xxqvq6r0000gn/T/tmp.Ow1Mk9LkUC"
history:
- timestamp: '2026-03-25T01:34:57Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
requirement_refs:
- FR-004
- FR-005
---

# Work Package Prompt: WP03 – Core UI Components

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

**Reviewed by**: Sridhar Vadlamani
**Status**: ❌ Changes Requested
**Date**: 2026-03-25
**Feedback file**: `/private/var/folders/h1/g68scqh939n8kgw31xxqvq6r0000gn/T/tmp.Ow1Mk9LkUC`

Reset from stuck doing state for orchestration re-run.


## Objectives & Success Criteria

Build the 7 universal UI components that every screen uses. Each component:
- Is a `ConsumerWidget` reading `activeThemeProvider`
- Derives ALL visual properties from theme tokens (zero hardcoded colors/sizes/spacing)
- Follows the `Mv` prefix convention to avoid Flutter name collisions
- Works with any theme implementing the `AppTokens` contract

**Success criteria**:
- Each component renders correctly with default Midnight Village theme
- Each component adapts when switched to test theme
- Interactive states (pressed, disabled, error, loading) work correctly
- `just flutter-analyze` passes with zero issues
- No `Color(0x` or hardcoded `TextStyle(fontSize:` in component code

**Implementation command**: `spec-kitty implement WP03 --base WP01`

## Context & Constraints

**Key documents**:
- Component APIs: `kitty-specs/001-frontend-design-system-and-architecture/contracts/component-api.md`
- Quickstart: `kitty-specs/001-frontend-design-system-and-architecture/quickstart.md`

**Constraints**:
- All components are `ConsumerWidget` (not StatelessWidget) — need `ref.watch(activeThemeProvider)`
- Wrap Material widgets with themed styling — don't rebuild from scratch
- No barrel files — each component gets its own import path
- Components in `frontend/lib/design_system/components/core/`

**Pattern for all components**:
```dart
class MvXxx extends ConsumerWidget {
  // constructor with required params

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    // Use tokens.colors, tokens.typography, tokens.spacing, tokens.elevation
    // Wrap Material widget with token-derived styling
  }
}
```

## Subtasks & Detailed Guidance

### Subtask T014 – Create MvButton

- **Purpose**: Themed button with primary, secondary, and destructive variants. Supports disabled and loading states.
- **File**: `frontend/lib/design_system/components/core/mv_button.dart`
- **Steps**:
  1. Create `enum MvButtonVariant { primary, secondary, destructive }`
  2. Create `MvButton` widget:
     ```dart
     class MvButton extends ConsumerWidget {
       final String label;
       final VoidCallback? onPressed;  // null = disabled
       final MvButtonVariant variant;
       final bool isLoading;

       const MvButton({
         super.key,
         required this.label,
         required this.onPressed,
         this.variant = MvButtonVariant.primary,
         this.isLoading = false,
       });
     }
     ```
  3. Build logic per variant:
     - **Primary**: `ElevatedButton` with `tokens.colors.primary` background, `tokens.colors.onPrimary` text
     - **Secondary**: `OutlinedButton` with `tokens.colors.outline` border, `tokens.colors.onSurface` text
     - **Destructive**: `ElevatedButton` with `tokens.colors.error` background, `tokens.colors.onError` text
  4. States:
     - **Disabled** (`onPressed == null`): Use `tokens.colors.disabled` background, `tokens.colors.onDisabled` text
     - **Loading** (`isLoading == true`): Show `SizedBox` with `CircularProgressIndicator` inside the button, disable interactions
  5. Typography: Use `tokens.typography.label` for button text
  6. Padding: Use `tokens.spacing.m` horizontal, `tokens.spacing.s` vertical
  7. Border radius: Consistent rounded corners (e.g., 8.0)
- **Parallel?**: Yes — independent of all other components.
- **Validation**:
  - [ ] Primary variant: amber background, dark text
  - [ ] Secondary variant: outlined, no fill
  - [ ] Destructive variant: error-red background
  - [ ] Disabled: grey background, muted text, no tap response
  - [ ] Loading: spinner replaces text, no tap response

### Subtask T015 – Create MvCard

- **Purpose**: Content container with optional header and footer. Used extensively for game cards, info panels, and content sections.
- **File**: `frontend/lib/design_system/components/core/mv_card.dart`
- **Steps**:
  1. Create `MvCard` widget:
     ```dart
     class MvCard extends ConsumerWidget {
       final Widget child;
       final Widget? header;
       final Widget? footer;
       final double? elevation;   // overrides theme default (raised)
       final EdgeInsets? padding;  // overrides theme default (spacing.m)
     }
     ```
  2. Build: Use Material `Card` or raw `Container` + `DecoratedBox`:
     - Background: `tokens.colors.surface`
     - Elevation: `elevation ?? tokens.elevation.raised`
     - Padding: `padding ?? EdgeInsets.all(tokens.spacing.m)`
     - Border radius: Consistent rounded corners (e.g., 12.0)
     - Shadow color: Subtle, based on `tokens.colors.background` with low opacity
  3. Layout: `Column` with optional header, child content, optional footer. Divider between sections if header/footer present using `tokens.colors.outline`.
- **Parallel?**: Yes.
- **Validation**:
  - [ ] Card has surface background color
  - [ ] Elevation creates subtle shadow
  - [ ] Header and footer render when provided
  - [ ] Padding defaults to `spacing.m`

### Subtask T016 – Create MvTextInput

- **Purpose**: Text input with label, hint, error state. Used for player name entry, game codes, etc.
- **File**: `frontend/lib/design_system/components/core/mv_text_input.dart`
- **Steps**:
  1. Create `MvTextInput` widget:
     ```dart
     class MvTextInput extends ConsumerWidget {
       final String label;
       final String? hint;
       final String? errorText;
       final TextEditingController? controller;
       final ValueChanged<String>? onChanged;
       final bool obscureText;
       final bool enabled;
     }
     ```
  2. Build: Wrap `TextField` with `InputDecoration`:
     - Label: `tokens.typography.label` style, `tokens.colors.onSurface` color
     - Hint: `tokens.typography.body` style, `tokens.colors.disabled` color
     - Error: `tokens.typography.caption` style, `tokens.colors.error` color
     - Border: `OutlineInputBorder` with `tokens.colors.outline` (normal), `tokens.colors.primary` (focused), `tokens.colors.error` (error)
     - Fill color: Slightly lighter than surface (e.g., `tokens.colors.surface` with slight opacity shift)
     - Disabled: Use `tokens.colors.disabled` for border and text
  3. Input text style: `tokens.typography.body`
- **Parallel?**: Yes.
- **Validation**:
  - [ ] Label renders above input
  - [ ] Error text appears below input in error color
  - [ ] Focus border changes to primary color
  - [ ] Disabled state greys out the input
  - [ ] Obscure text works (password field)

### Subtask T017 – Create MvDialog

- **Purpose**: Modal dialogs for confirmation, information, and error scenarios. Three named constructor variants.
- **File**: `frontend/lib/design_system/components/core/mv_dialog.dart`
- **Steps**:
  1. Create `MvDialog` widget with named constructors:
     ```dart
     class MvDialog extends ConsumerWidget {
       final String title;
       final String body;
       final List<Widget> actions;

       // Named constructors
       MvDialog.confirmation({...})
       MvDialog.info({...})
       MvDialog.error({...})
     }
     ```
  2. **Confirmation** constructor:
     - Two action buttons: confirm (primary) + cancel (secondary)
     - `confirmLabel`, `onConfirm`, `cancelLabel`, `onCancel` params
  3. **Info** constructor:
     - One dismiss button
     - `dismissLabel` param (default: 'OK')
  4. **Error** constructor:
     - Error icon/color header
     - Optional retry button
     - `retryLabel`, `onRetry` params
  5. Build: Use `AlertDialog` with themed styling:
     - Background: `tokens.colors.surface`
     - Title: `tokens.typography.heading` style
     - Body: `tokens.typography.body` style
     - Shape: Rounded rectangle with consistent radius
     - Elevation: `tokens.elevation.overlay`
  6. Provide a static helper for showing:
     ```dart
     static Future<void> show(BuildContext context, MvDialog dialog) {
       return showDialog(context: context, builder: (_) => dialog);
     }
     ```
- **Parallel?**: Yes.
- **Validation**:
  - [ ] Confirmation: two buttons, correct callbacks
  - [ ] Info: single dismiss button
  - [ ] Error: error-colored header, optional retry
  - [ ] Dialog background uses surface color
  - [ ] Overlay elevation applied

### Subtask T018 – Create MvScaffold

- **Purpose**: Consistent page layout with themed app bar, body area, optional bottom bar. Provides responsive padding.
- **File**: `frontend/lib/design_system/components/core/mv_scaffold.dart`
- **Steps**:
  1. Create `MvScaffold` widget:
     ```dart
     class MvScaffold extends ConsumerWidget {
       final Widget body;
       final String? title;
       final List<Widget>? actions;
       final Widget? bottomBar;
       final bool showBackButton;
     }
     ```
  2. Build: Wrap Material `Scaffold`:
     - App bar: `AppBar` with `tokens.colors.surface` background, `tokens.typography.heading` for title, `tokens.colors.onSurface` for text/icons
     - Body: Wrapped in `SafeArea` with responsive padding:
       - Phone portrait (< 600dp): `tokens.spacing.m` horizontal
       - Wider screens: Centered with max content width (e.g., 600dp) + `tokens.spacing.l` padding
     - Bottom bar: If provided, themed bottom bar area with `tokens.colors.surface` background
     - Back button: If `showBackButton`, display themed back arrow
  3. Background: `tokens.colors.background` (scaffoldBackgroundColor from ThemeData should handle this)
- **Parallel?**: Yes.
- **Validation**:
  - [ ] App bar renders with surface color background
  - [ ] Title uses heading typography
  - [ ] Body content has responsive padding
  - [ ] Bottom bar renders when provided
  - [ ] Back button appears when `showBackButton` is true

### Subtask T019 – Create MvLoading

- **Purpose**: Themed loading indicator with optional message. Used during async operations.
- **File**: `frontend/lib/design_system/components/core/mv_loading.dart`
- **Steps**:
  1. Create `MvLoading` widget:
     ```dart
     class MvLoading extends ConsumerWidget {
       final String? message;
       const MvLoading({super.key, this.message});
     }
     ```
  2. Build: Centered column with:
     - `CircularProgressIndicator` using `tokens.colors.primary` as value color
     - If `message` provided: Text below with `tokens.typography.body`, `tokens.colors.onBackground`, and `tokens.spacing.m` gap
  3. Center the whole thing vertically and horizontally.
- **Parallel?**: Yes.
- **Validation**:
  - [ ] Spinner uses primary color
  - [ ] Message renders below spinner when provided
  - [ ] Centered on screen

### Subtask T020 – Create MvError

- **Purpose**: Error display with message and optional retry action. Used when API calls fail or unexpected errors occur.
- **File**: `frontend/lib/design_system/components/core/mv_error.dart`
- **Steps**:
  1. Create `MvError` widget:
     ```dart
     class MvError extends ConsumerWidget {
       final String message;
       final VoidCallback? onRetry;
       const MvError({super.key, required this.message, this.onRetry});
     }
     ```
  2. Build: Centered column with:
     - Error icon: `Icons.error_outline` in `tokens.colors.error`, size 48
     - Error message: `tokens.typography.body` style, `tokens.colors.onBackground`
     - If `onRetry` provided: `MvButton` with destructive variant and "Retry" label, below the message
     - Spacing: `tokens.spacing.m` between elements
  3. Wrap in appropriate padding.
- **Parallel?**: Yes.
- **Validation**:
  - [ ] Error icon uses error color
  - [ ] Message is readable
  - [ ] Retry button appears when `onRetry` provided
  - [ ] No retry button when `onRetry` is null

## Risks & Mitigations

- **Material widget theming conflicts**: Some Material widgets (e.g., `TextField`) have complex theming. Use `InputDecoration` and `InputDecorationTheme` carefully. Verify that token colors override Material defaults.
- **Responsive layout complexity**: Keep MvScaffold responsive logic simple. Use `LayoutBuilder` or `MediaQuery` — don't over-engineer.
- **Dialog dismissal**: Ensure dialogs can be dismissed by tapping outside (default Material behavior). Don't break this.

## Review Guidance

- **Zero hardcoded values**: Grep for `Color(0x`, `fontSize:`, `EdgeInsets.all(` with literal numbers in component files. All visual values must come from tokens.
- **Consistent patterns**: All components should follow the same `ConsumerWidget` + `ref.watch(activeThemeProvider)` pattern.
- **API match**: Verify each component's constructor matches the contract in `component-api.md`.
- **Theme adaptation**: Mentally trace what happens when tokens change — does every visual property update?

## Activity Log

- 2026-03-25T01:34:57Z – system – lane=planned – Prompt created.
- 2026-03-25T03:53:23Z – headless-impl – shell_pid=35941 – lane=doing – Assigned agent via workflow command
- 2026-03-25T04:01:31Z – headless-impl – shell_pid=35941 – lane=planned – Reset for re-run
- 2026-03-25T04:01:50Z – headless-impl – shell_pid=45500 – lane=doing – Started implementation via workflow command
