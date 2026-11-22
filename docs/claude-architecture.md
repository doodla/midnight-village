# Claude Code setup

What `.claude/` enforces, so agents do not have to remember it. Update this file in the same
commit as any change under `.claude/`.

## The commit gate: git's own hooks (`.claude/hooks/git/`)

The gate only catches the embarrassing things, in seconds. GitHub is the wall: it runs every
check on every pull request (next section). Enabled by `git config core.hooksPath .claude/hooks/git`
(shared by every worktree of the clone), which `hooks/session-start.sh` sets at the start of every
session (and `tool/setup_env.sh` calls). The Bash guard blocks a commit while it is not set and
says to run that script. The hooks check what git is really about to commit, however the commit
was typed (`-a`, pathspecs, `-C`, global options):

- `pre-commit`: the instruction link check on the staged text (`--staged`), then the fast
  checks the commit's paths need (`git diff --cached --no-renames`, so a file moved out of code
  still runs its checks), in parallel. `pre-merge-commit` runs the same for a merge git commits
  by itself, on everything the merge changes; a merge with conflicts is finished with
  `git commit`, which runs `pre-commit`; a fast-forward makes no commit.
- `commit-msg`: the subject reads `type(scope): description` (git's merge and revert subjects pass).

Routing and what each block runs (`hooks/lib/gate.sh`, mode "fast"):

| Paths | Block | Fast checks |
|---|---|---|
| `backend/**` (not Markdown), `docs/specs/onuw/recommended-setups.md` | backend | `just check`: ruff lint and format, pyrefly, `makemigrations --check` (about 5 s) |
| `frontend/**` (not Markdown) | frontend | `just analyze`, `just format-check` (about 15 s) |
| `contract_samples/**` | backend, frontend | both of the above |
| `.claude/**` (not skills), `tool/**`, `.github/**`, `docs/dev/main-ruleset.json`, root `justfile` | guardrails | `just test-guardrails`: guardrail, gate-routing and workflow tests |
| Markdown, `docs/**` | none | only the link check (under a second) |
| anything else | backend, frontend | both of the above |

A block that already passed on the same inputs (its files, `backend/.env`, the root `justfile`,
tool versions; recorded in the git dir for 14 days) is not run again; a `just gate-full` pass
counts. A block is stopped after 100 s, which blocks. A broken or missing `gate.sh` blocks every
commit. No test suite runs in a commit, so a commit needs no long Bash timeout.

`just gate-full [backend|frontend|guardrails ...]` (`hooks/gate-full.sh`, mode "full") is the
whole local suite on demand, in parallel, with times: the link check; backend `just check` and
`just test`; frontend analyze, format check, `just test`, `just gen-check`, `just screens` strict
at 360 and at 390; the hook tests. A pass is recorded. It skips what only GitHub runs (web
integration, the release build, the end-to-end harness). Tests: `hooks/test_gate_routing.sh`
(in `just test-guardrails`) checks routing, that a commit runs no suite and that `gate-full` runs
them all.

## GitHub: the wall (`.github/workflows/`)

Every check runs on every pull request to main (and on each push to main), as parallel jobs that
only call `just` recipes. `guardrails/tests/test_workflows.py` fails when a workflow names a
recipe that does not exist, a check workflow filters on paths (a required check that never starts blocks the
merge for ever) or has a job with no name or time limit.

| Job (the check name) | Runs |
|---|---|
| `Backend Checks` | `just check`, `just test`: pytest with the 80% coverage floor and the contract samples compared with the server, the migration tests, the guardrail, gate-routing and workflow tests |
| `Analyze and Format` | `just analyze`, `just format-check` |
| `Release has no debug toolbar` | `just check-release` |
| `Widget Tests` | `just gen-check`, `just test-widgets` |
| `Golden Tests` | `just flutter-test-golden` |
| `Screens strict at 360`, `Screens strict at 390` | `just screens 360 strict`, `just screens 390 strict` (one job each, side by side) |
| `Integration Tests` | `just test-integration-ci` |
| `End-to-end Harness` | `just test-harness` |
| `Web page smoke` | `just web-smoke-setup`, `just web-smoke`: the release web page in Chromium (first visit, return, a deploy runs the new build, a table's link) |

One workflow is not part of the wall: `android-download.yml` ("Android App Download") builds the
Android app on a push to main that touches `frontend/` (or by hand) and replaces the one asset of
the rolling release `android-latest` (`docs/dev/deploy-vercel.md`, "Android app download"). It never
runs on a pull request, is not in the ruleset, has a paths filter and `contents: write` on its one
job. `guardrails/tests/test_workflows.py` sets it apart (`PUBLISHING`) and holds it to those rules
(`WorkflowPublishing`); the wall's rules above apply to every other workflow.

The ruleset `docs/dev/main-ruleset.json` is what makes this the wall: a pull request on the
default branch, squash merges only, every check above required (up to date with main not
required, so two sessions do not block each other), no force pushes or deletion, nobody
bypassing. It is not on today: the owner decides (GitHub reports main as not protected, with no
rulesets). To turn it on: Settings, Rules, Rulesets, New ruleset, Import a ruleset, choose the
file; or as a repository admin:

```bash
gh api -X POST repos/doodla/midnight-village/rulesets --input docs/dev/main-ruleset.json
```

When a check is added, renamed or removed, change the job's `name:` and the ruleset file in
the same commit (`guardrails/tests/test_workflows.py` fails until they match), then import the
file again (delete the old ruleset first, or edit its checks in the settings).

## Claude Code hooks (`.claude/settings.json`; timeouts in seconds)

Every hook command starts from `$CLAUDE_PROJECT_DIR`, never a relative path: a session whose shell sits in `backend/` or `frontend/` must still find the script. The Bash guard does nothing when its script is missing (the git hooks are the gate).

| Event | Script | Does |
|---|---|---|
| PreToolUse Agent, Task, Workflow | `guardrails/runner.py` | Blocks a subagent not pinned to `opus`, `sonnet` or `haiku` (on trial) with an effort, and forks. |
| PreToolUse Bash | `hooks/git_guard.py` | Blocks a commit unless `core.hooksPath` is the git hooks; blocks `--no-verify`, `commit -n`, hooksPath changes, `GIT_*=` and HUSKY/SKIP switches, cherry-pick/revert without `--no-commit`, rebase and am (git runs no commit hooks for those); asks nothing of a committing call's timeout (the gate takes seconds). |
| SessionStart startup, resume, compact | `hooks/session-start.sh` | Sets `core.hooksPath` to the git hooks if it is anything else and makes the hooks executable; silent, one line if it cannot, never fails the session. |
| PostToolUse Edit, Write | `hooks/post-edit-format.sh` | Formats the edited `.py` (ruff) or `.dart` file. |
| Stop | `hooks/verify-done.sh` | With uncommitted `.py`/`.dart` work, runs the fast checks it touches (as the commit gate does), unless they already passed on the same inputs. No test suite. |

## Guardrails (`.claude/guardrails/`)

`runner.py` runs the rules in `config.toml` (deny or warn only). The one rule,
`subagent_model_effort`, keeps subagents off the main session's model for cost. Its message points at
`docs/dev/running-the-work.md`, which holds how to choose a model and effort. Adding a
rule: `.claude/guardrails/README.md`. Tests: `just test-guardrails`. A test or check that scans
repo files reads them from `tool/repo_files.py` (the files git tracks or does not ignore), so a builder's
worktree copy under `.claude/worktrees/` is never scanned.

## Agents (`.claude/agents/`, each pins model and effort)

| Agent | Model, effort | Tools |
|---|---|---|
| `backend-developer`, `frontend-developer` | opus, high | Read, Edit, Write, Grep, Glob, Bash, Agent (Agent so a builder can call `eyes`) |
| `backend-code-reviewer`, `frontend-code-reviewer` | opus, high | Read, Grep, Glob, Bash: no edit tools |
| `player-experience` | opus, high | Read, Grep, Glob |
| `worker` (small exact jobs) | sonnet, medium | Read, Edit, Write, Grep, Glob, Bash |
| `eyes` (looks at PNGs, reports in words) | sonnet, medium | Read, Glob: no edits |

Every agent lists its tools: one defined with all tools starts at about 78k tokens of context
(connector tool descriptions), one with a short list at 7-10k. A new agent lists its tools too.
`just contact-sheet` (run in `frontend/`) makes one image of the `just screens` output
(`frontend/tool/contact_sheet.py`). The rules for using them: `docs/dev/running-the-work.md`,
"Lean helpers"; the numbers: `docs/dev/agent-ledger.md`.

The developer agents' briefs carry no old-look or protocol-1 rule any more: both are deleted.

## Skills (`.claude/skills/`)

Twelve third-party `flutter-*` skills (Flutter's generic guides on animation, architecture,
layout, concurrency, HTTP and JSON, navigation, accessibility, state, macOS setup, testing,
theming, databases), mirrored in `.agents/skills/`. Nothing here depends on them; keeping them
is the owner's call.
