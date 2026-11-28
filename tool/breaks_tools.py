# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""Deliberate breaks of the tools that guard the work, and of the guards themselves
(tool/prove_guards.py): one for each guard file, so each is proved to bite."""

from breaks_kit import Break, Edit

GUARDRAILS = ".claude/guardrails/tests"
PROVE_GUARDS_TEST = f"{GUARDRAILS}/test_prove_guards.py"
# the harness's own files, held by the tests of test_prove_guards.py, which imports each
HARNESS = tuple(
    f"tool/{name}.py"
    for name in (
        "prove_guards",
        "breaks_kit",
        "breaks_rules",
        "breaks_verdict",
        "breaks_server",
        "breaks_tools",
        "breaks_app",
    )
)
NIGHT_RESULTS = "backend/apps/onuw/night_results.py"

# The guards that came before `just prove-guards` and have no recorded break yet. This list only
# shrinks: a new guard arrives with its break (tool/prove_guards.py fails one listed here that
# was no guard on main), and one that gets a break comes off.
NOT_YET_PROVED = frozenset(
    {
        "frontend/test/design_system/copy/copy_budget_test.dart",
        "frontend/test/design_system/primitives/paper_consistency_test.dart",
        "frontend/test/design_system/primitives/paper_rules_test.dart",
        "frontend/test/design_system/skin/contrast_test.dart",
        "frontend/test/design_system/skin/raw_values_test.dart",
        "frontend/test/design_system/skin/skin_contract_test.dart",
        "frontend/test/helpers/contract/fixture_sources_test.dart",
        "frontend/test/helpers/finger.dart",
        "frontend/test/helpers/screen_sweep.dart",
        "frontend/test/helpers/stage_clock.dart",
        "frontend/test/helpers/still_screen.dart",
        "frontend/test/screen_cases/not_yet_swept.dart",
        "frontend/test_screens/reading_floor.dart",
    }
)


def _tool(name, promise, why, edit, test) -> Break:
    return Break(
        name=name,
        promise=promise,
        why=why,
        edits=(edit,),
        tests=(f"{GUARDRAILS}/{test}",),
    )


TOOLS: tuple[Break, ...] = (
    Break(
        name="sample_coverage_loses_the_unmade_choice",
        promise="fixtures-from-samples",
        why="a default night result stops saying nothing was chosen; samples re-recorded",
        edits=(
            Edit(NIGHT_RESULTS, 'drunk_out["nothing_chosen"] = True', "pass"),
            Edit(NIGHT_RESULTS, 'see_team_out["nothing_chosen"] = True', "pass"),
            Edit(NIGHT_RESULTS, 'return {"nothing_chosen": True}', "return {}"),
        ),
        resample=True,
        tests=(
            "backend/tests/contract/test_sample_coverage.py::test_a_choice_left_unmade_is_recorded",
        ),
    ),
    _tool(
        "file_size_limit_raised",
        "files-under-600",
        "the size check allows 700 lines",
        Edit("tool/check_file_sizes.py", "LIMIT = 600", "LIMIT = 700"),
        "test_file_sizes.py",
    ),
    _tool(
        "a_comment_with_a_rule_is_deleted_unattended",
        "the-wall",
        "no-comments applies a sorter's deletion of a comment that says never or only",
        Edit(
            "tool/empty_comments.py",
            "    if has_rule_word(text):",
            "    if False:",
            within="provably_empty",
        ),
        "test_empty_comments.py::TheClasses.test_a_rule_word_keeps_a_comment_out_of_every_class",
    ),
    _tool(
        "guard_edit_needs_no_reason",
        "guards-hold",
        "any description explains any guard edit",
        Edit(
            "tool/guard_edits.py",
            "    return bool(",
            "    return True or bool(",
            within="explained",
        ),
        "test_guard_edits.py",
    ),
    _tool(
        "a_shortened_no_verify_slips_by",
        "the-wall",
        "the git guard blocks only the full spelling of --no-verify",
        Edit(
            ".claude/hooks/git_guard.py",
            'return len(arg) >= len("--no-veri") and "--no-verify".startswith(arg)',
            'return arg == "--no-verify"',
            within="is_no_verify",
        ),
        "test_git_guard.py",
    ),
    _tool(
        "an_agent_pinning_its_model_counts_as_pinning_both",
        "the-wall",
        "an agent whose definition pins only its model may run with no effort set",
        Edit(
            ".claude/guardrails/rules/subagent_model_effort.py",
            "if not tool_input.get(k) and k not in pins]",
            "if not tool_input.get(k) and not pins]",
            within="check_agent",
        ),
        "test_guardrails.py",
    ),
    _tool(
        "piece_check_forgets_samples",
        "the-wall",
        "a recorded sample's change reaches no test",
        Edit(
            "tool/piece_check.py",
            'samples = any(c.startswith("contract_samples/") for c in changed)',
            "samples = False",
            within="frontend_tests",
        ),
        "test_piece_check.py",
    ),
    _tool(
        "docs_change_ships_the_server",
        "the-wall",
        "a changed .md file moves what Vercel serves",
        Edit(
            "tool/promote_live.py",
            'return not inside.endswith(".md") and not inside.startswith(not_shipped)',
            "return not inside.startswith(not_shipped)",
            within="ships",
        ),
        "test_promote_live.py",
    ),
    _tool(
        "an_undated_reason_covers_a_removed_asset",
        "the-wall",
        "a removed release file is covered by any reason, dated or not",
        Edit(
            "frontend/tool/record_release_assets.py",
            'and not DATED.match(on_purpose.get(path, ""))',
            'and not on_purpose.get(path, "")',
            within="uncovered",
        ),
        "test_release_assets.py",
    ),
    _tool(
        "tidy_clears_a_worktree_someone_works_in",
        "the-wall",
        "a worktree with a process working in it counts as idle, so tidy clears it",
        Edit(
            "tool/tidy.py",
            "            return True\n",
            "            return False\n",
            within="busy",
        ),
        "test_tidy.py",
    ),
    _tool(
        "a_required_check_gets_a_paths_filter",
        "the-wall",
        "Backend Checks runs only when backend/ changes, so it may never start",
        Edit(
            ".github/workflows/backend-tests.yml",
            '  pull_request:\n    branches: ["main"]\n',
            '  pull_request:\n    branches: ["main"]\n    paths: ["backend/**"]\n',
        ),
        "test_workflows.py",
    ),
    _tool(
        "a_shell_script_that_does_not_parse",
        "the-wall",
        "a shell script with a syntax error",
        Edit("tool/previous_build_check.sh", None, '\nif [ -n "$x" ]; then\n'),
        "test_checkout_whole.py::test_every_shell_script_parses",
    ),
    _tool(
        "a_refusal_for_another_reason_passes_the_rehearsal",
        "the-wall",
        "the live-rule rehearsal takes any refused push (a bad token, a network"
        " error) for the rule refusing it, and says PASS",
        Edit(
            "tool/rehearse_live_rule.py",
            "if any(s in said for s in RULE_SAYS):",
            "if True:",
            within="judge",
        ),
        "test_release_workflows.py",
    ),
    _tool(
        "the_way_back_reverts_the_live_migrations",
        "the-wall",
        "undoing a release deletes the migrations the live database has already run",
        Edit(
            "tool/revert_release.py",
            'git("checkout", "origin/main", "--", *migrations)',
            "pass",
            within="revert",
        ),
        "test_revert_release.py",
    ),
    _tool(
        "spec_names_a_key_that_is_gone",
        "few-words",
        "a spec may name a copy key that does not exist",
        Edit(
            "tool/copy_page.py",
            "elif key and key not in known[name]:",
            "elif False:",
            within="check_spec",
        ),
        "test_copy_page.py",
    ),
    _tool(
        "a_speed_verdict_ignores_the_runs_own_spread",
        "the-wall",
        "a gap inside the noise the runs themselves show is called better or worse",
        Edit(
            "tool/phone_frames/verdict.py",
            "if abs(gap) <= spread:",
            "if False:",
            within="judge",
        ),
        "test_speed_verdict.py::TheRule.test_press_1_night_pick_is_level_inside_its_own_spread",
    ),
    _tool(
        "a_hold_that_did_not_register_is_timed",
        "the-wall",
        "a card hold let go before it counted gives a number (the silent desync)",
        Edit(
            "tool/phone_frames/moments.py",
            "if hold >= checks.HOLD_CHECKED and not checks.held_showed(anywhere, hold):",
            "if False:",
            within="Run.tap",
        ),
        "test_speed_verdict.py::MeasuredSteps.test_a_hold_that_showed_nothing_while_held_is_lost_not_a_number",
    ),
    _tool(
        "a_step_that_sent_nothing_is_timed",
        "the-wall",
        "a tap whose request never left (it missed, or its screen was not there) gives a number",
        Edit(
            "tool/phone_frames/checks.py",
            "    if not miss:\n        return None",
            "    return None",
            within="lost_actions",
        ),
        "test_speed_verdict.py::MeasuredSteps.test_a_step_without_its_action_is_lost",
    ),
    _tool(
        "a_speed_verdict_runs_beside_other_heavy_jobs",
        "the-wall",
        "a speed verdict takes one slot of the heavy queue, so a test suite runs beside it",
        Edit(
            "tool/phone_frames/speed_verdict.py",
            '"--alone"]',
            "]",
            within="main",
        ),
        "test_speed_verdict.py::TheCommand.test_a_verdict_holds_every_slot_of_the_heavy_queue",
    ),
    Break(
        name="a_guard_may_arrive_unproved",
        promise="guards-hold",
        why="a guard with no recorded break passes `just prove-guards`",
        edits=(
            Edit(
                "tool/breaks_rules.py",
                "if guard not in bitten and guard not in debt:",
                "if False:",
                within="list_problems",
            ),
        ),
        tests=(PROVE_GUARDS_TEST, f"{GUARDRAILS}/test_prove_guards_runs.py"),
        guards=HARNESS,
    ),
    Break(
        name="a_crash_counts_as_a_catch",
        promise="guards-hold",
        why="a killer test that errors (an import error, a crash) counts as killing a break",
        edits=(
            Edit(
                "tool/breaks_verdict.py",
                'if kind == "error":',
                "if False:",
                within="backend",
            ),
            Edit(
                "tool/breaks_verdict.py",
                "if CRASH.match(message) or not JUDGED.match(message):",
                "if False:",
                within="backend",
            ),
        ),
        tests=(PROVE_GUARDS_TEST, f"{GUARDRAILS}/test_prove_guards_runs.py"),
        guards=HARNESS,
    ),
)
