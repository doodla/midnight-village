---
work_package_id: WP06
title: Visual Diff Comparison Tooling
lane: "doing"
dependencies: [WP03]
requirement_refs: [FR-014, FR-015]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 002-flutter-ui-test-infrastructure-WP03
base_commit: 0ca6e54d148cf66481d9081079c92fb4e39c35de
created_at: '2026-03-26T02:06:45.504261+00:00'
subtasks:
- T027
- T028
- T029
- T030
- T031
phase: Phase 2 - Tooling
assignee: ''
agent: ''
shell_pid: "23484"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-25T23:55:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP06 – Visual Diff Comparison Tooling

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

Build a Dart CLI tool that processes golden test failures to produce pixel-diff overlay images and an HTML comparison report for rapid triage of visual regressions.

**Success criteria**:
- Break a golden baseline, run the diff report tool, verify it produces side-by-side comparison and magenta-highlighted pixel overlay
- HTML report lists all failures with thumbnails and click-to-expand full-size views
- `just flutter-golden-report` runs the tool
- `just flutter-golden-check` runs golden tests and generates the report if any fail

**Implementation command**: `spec-kitty implement WP06 --base WP03`

## Context & Constraints

- **Spec**: `kitty-specs/002-flutter-ui-test-infrastructure/spec.md` — User Story 4; FR-014, FR-015
- **Plan**: `kitty-specs/002-flutter-ui-test-infrastructure/plan.md` — Decision #7
- **Depends on WP03**: Golden test baselines must exist to have failure artifacts to process
- **Constraint**: Use the `image` pub package for pixel-level image comparison — `dart:ui` is not available in CLI context (non-Flutter Dart scripts)
- **Constraint**: HTML report should be self-contained (inline CSS, base64-encoded images) for easy sharing
- **Golden failure directory**: Flutter golden test failures produce output in `test/failures/` or a configurable path via the custom comparator

## Subtasks & Detailed Guidance

### Subtask T027 – Create `golden_diff_report.dart` CLI entry point

- **Purpose**: Create the Dart CLI tool that scans for golden test failure outputs and orchestrates diff generation and reporting.
- **Steps**:
  1. Create `frontend/tool/golden_diff_report.dart`
  2. Add the `image` package to `pubspec.yaml` dev dependencies:
     ```yaml
     dev_dependencies:
       image: ^4.0.0  # or latest stable
     ```
  3. Define the CLI entry point:
     ```dart
     import 'dart:io';
     import 'package:image/image.dart' as img;

     void main(List<String> args) {
       final failuresDir = args.isNotEmpty ? args[0] : 'test/failures';
       final outputDir = args.length > 1 ? args[1] : 'test/golden_diff_report';

       final failures = scanForFailures(failuresDir);
       if (failures.isEmpty) {
         print('No golden test failures found in $failuresDir');
         exit(0);
       }

       print('Found ${failures.length} golden test failures');
       final diffs = generateDiffs(failures);
       generateReport(diffs, outputDir);
       print('Report generated: $outputDir/golden_diff_report.html');

       if (args.contains('--open')) {
         Process.run('open', ['$outputDir/golden_diff_report.html']);
       }
     }
     ```
  4. Implement `scanForFailures()` to find pairs of baseline/actual PNG files in the failures directory
  5. The function should identify pairs by naming convention (e.g., `component_test.png` baseline vs `component_test_actual.png`)
- **Files**: `frontend/tool/golden_diff_report.dart` (new, ~60 lines for scaffold)
- **Parallel?**: No — foundational for T028, T029
- **Notes**: The `image` package is a pure Dart image processing library that works in non-Flutter Dart scripts. Check Flutter's golden test output structure — failure images may be in `test/failures/` with naming like `{testName}.png` (expected) and `{testName}_actual.png` (actual). Make the scan path configurable.

### Subtask T028 – Implement pixel-diff overlay generation

- **Purpose**: Generate a third image for each failure where unchanged pixels are dimmed and changed pixels are highlighted in magenta.
- **Steps**:
  1. In `golden_diff_report.dart`, implement the diff generation:
     ```dart
     img.Image generateDiffOverlay(img.Image baseline, img.Image actual) {
       final width = baseline.width;
       final height = baseline.height;
       final diff = img.Image(width: width, height: height);

       for (var y = 0; y < height; y++) {
         for (var x = 0; x < width; x++) {
           final basePixel = baseline.getPixel(x, y);
           final actualPixel = actual.getPixel(x, y);

           if (basePixel == actualPixel) {
             // Unchanged: dim to 50% opacity
             diff.setPixel(x, y, img.ColorRgba8(
               basePixel.r ~/ 2, basePixel.g ~/ 2, basePixel.b ~/ 2, 128,
             ));
           } else {
             // Changed: magenta highlight
             diff.setPixel(x, y, img.ColorRgba8(255, 0, 255, 255));
           }
         }
       }
       return diff;
     }
     ```
  2. Handle size mismatches between baseline and actual (resize to larger or report as separate error)
  3. Save diff images as `*_diff.png` alongside the baseline/actual pair
  4. Track changed pixel count for the report summary
- **Files**: `frontend/tool/golden_diff_report.dart` (extends T027, ~80 lines added)
- **Parallel?**: No — sequential with T027 (same file)
- **Notes**: The `image` package API may differ slightly between versions — check the installed version. Pixel comparison should use exact equality for deterministic renders. Consider adding a tolerance option for near-matches if needed later.

### Subtask T029 – Implement HTML comparison report

- **Purpose**: Generate a self-contained HTML report listing all failing golden tests with side-by-side thumbnails (baseline / actual / diff overlay) and click-to-expand views.
- **Steps**:
  1. In `golden_diff_report.dart`, implement report generation:
     ```dart
     void generateReport(List<DiffResult> diffs, String outputDir) {
       final buffer = StringBuffer();
       buffer.writeln('<!DOCTYPE html>');
       buffer.writeln('<html><head>');
       buffer.writeln('<title>Golden Diff Report</title>');
       buffer.writeln('<style>');
       // Inline CSS for layout, thumbnail sizing, click-to-expand
       buffer.writeln('</style>');
       buffer.writeln('</head><body>');
       buffer.writeln('<h1>Golden Test Diff Report</h1>');
       buffer.writeln('<p>${diffs.length} failures found</p>');

       for (final diff in diffs) {
         buffer.writeln('<div class="failure">');
         buffer.writeln('<h2>${diff.testName}</h2>');
         buffer.writeln('<p>${diff.changedPixels} pixels changed</p>');
         buffer.writeln('<div class="comparison">');
         // Base64-encode images for self-contained report
         buffer.writeln('<img src="data:image/png;base64,${diff.baselineBase64}" title="Baseline">');
         buffer.writeln('<img src="data:image/png;base64,${diff.actualBase64}" title="Actual">');
         buffer.writeln('<img src="data:image/png;base64,${diff.diffBase64}" title="Diff">');
         buffer.writeln('</div></div>');
       }

       buffer.writeln('</body></html>');

       Directory(outputDir).createSync(recursive: true);
       File('$outputDir/golden_diff_report.html').writeAsStringSync(buffer.toString());
     }
     ```
  2. Include inline CSS for:
     - Side-by-side thumbnail layout (3 columns)
     - Click-to-expand full-size images
     - Summary table with failure count and component names
  3. Base64-encode all images so the HTML file is fully self-contained
  4. Add a timestamp and test run info to the report header
- **Files**: `frontend/tool/golden_diff_report.dart` (extends T027/T028, ~100 lines added)
- **Parallel?**: No — depends on T028 (needs diff images)
- **Notes**: Self-contained HTML (inline CSS, base64 images) is critical for CI artifact downloads — the report must work without external file references. Keep the CSS minimal but functional.

### Subtask T030 – Add `flutter-golden-report` justfile command

- **Purpose**: Provide developer-friendly commands for generating the visual diff report and a combined check-and-report workflow.
- **Steps**:
  1. Read `frontend/justfile` for existing patterns
  2. Add commands:
     ```just
     # Generate visual diff report from golden test failures
     flutter-golden-report:
         dart run tool/golden_diff_report.dart

     # Run golden tests and generate diff report if any fail
     flutter-golden-check:
         just flutter-test-golden || just flutter-golden-report
     ```
  3. Verify `dart run tool/golden_diff_report.dart` works from the `frontend/` directory
- **Files**: `frontend/justfile` (modify, ~8 lines added)
- **Parallel?**: Yes — independent of T027-T029 (different file)
- **Notes**: The `||` operator in `flutter-golden-check` runs the report only if golden tests fail (non-zero exit code). This is the expected developer workflow: test, and if anything fails, automatically generate the diff report.

### Subtask T031 – Validate diff tooling with deliberate failure

- **Purpose**: Prove the diff tooling works end-to-end by deliberately breaking a golden baseline and verifying the report output.
- **Steps**:
  1. Modify a component used in WP03 golden tests (e.g., change `MvButton`'s primary color)
  2. Run `just flutter-test-golden` — expect failures
  3. Run `just flutter-golden-report` — expect HTML report generated
  4. Open the HTML report and verify:
     - Component name is listed
     - Baseline image shows original appearance
     - Actual image shows modified appearance
     - Diff overlay highlights changed pixels in magenta
     - Click-to-expand works for full-size views
  5. Run `just flutter-golden-check` and verify the combined workflow
  6. Revert the component modification
- **Files**: No new files — validation step
- **Parallel?**: No — depends on T027-T030
- **Notes**: This is a manual validation step. Document any issues found and fix them before marking WP06 complete.

## Test Strategy

The diff tool is validated by T031's end-to-end test:

1. **Deliberate failure**: Break a golden, generate report, verify output
2. **Empty case**: Run diff tool with no failures — verify clean exit message
3. **Multiple failures**: Break 2+ goldens, verify report lists all of them

No automated tests for the diff tool itself — it's a developer tool validated by usage.

## Risks & Mitigations

- **`dart:ui` not available in CLI**: Use the `image` pub package instead. This is a pure Dart library that works in non-Flutter scripts.
- **Golden failure directory location may vary**: Make the scan path configurable via CLI argument with a sensible default (`test/failures/`).
- **Large base64 images may make the HTML report slow**: Consider limiting thumbnail size in the report while keeping full-size available on click.
- **`image` package API version**: Check the latest stable version and its API. The pixel manipulation API may differ between major versions.

## Review Guidance

- Verify diff overlay correctly highlights changed pixels in magenta
- Verify HTML report is self-contained (no external file references)
- Verify the report works in a browser (open and inspect)
- Verify justfile commands follow existing naming conventions
- Verify the `image` package is added to dev dependencies only (not regular dependencies)
- Verify the tool handles edge cases: no failures, size mismatches, missing files

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
2. **Use CLI**: `spec-kitty agent tasks move-task WP06 --to <lane> --note "message"` (recommended)

The CLI command updates both frontmatter and activity log automatically.

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
