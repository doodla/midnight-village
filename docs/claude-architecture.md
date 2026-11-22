# Claude Code setup

What `.claude/` enforces, so agents do not have to remember it. Update this file in the same
commit as any change under `.claude/`.

## The commit gate: git's own hooks (`.claude/hooks/git/`)

Enabled by `git config core.hooksPath .claude/hooks/git` (shared by every worktree of the
clone), which `hooks/session-start.sh` sets at the start of every session (and
`tool/setup_env.sh` calls). The Bash guard blocks a commit while it is not set and says to run
that script. The hooks check what git is really about to commit, however the commit was typed
(`-a`, pathspecs, `-C`, global options):

- `pre-commit`: the instruction link check on the staged text (`--staged`), then the suites the commit's paths need
  (`git diff --cached --no-renames`, so a file moved out of code still runs its suite), in
  parallel. `pre-merge-commit` runs the same for a merge git commits by itself, on everything
  the merge changes; a merge with conflicts is finished with `git commit`, which runs
  `pre-commit`; a fast-forward makes no commit.
- `commit-msg`: the subject reads `type(scope): description` (git's merge and revert subjects pass).

Routing (`hooks/lib/gate.sh`): `backend/**` and `docs/specs/onuw/recommended-setups.md` run
backend `just check` and `just test`; `frontend/**` runs `just analyze`, `just format-check`
and `just test`; `contract_samples/**` runs both; `.claude/**` (not skills), `tool/**` and the
root `justfile` run `just test-guardrails`; Markdown and `docs/**` run no suite; anything else
runs both. A suite that already passed on the same inputs (its files, `backend/.env`, the root
`justfile`, tool versions; recorded in the git dir for 14 days) is not run again. A suite is
stopped after 1500 s, which blocks. A broken or missing `gate.sh` blocks every commit.
Tests: `hooks/test_gate_routing.sh` (in `just test-guardrails`).

## Claude Code hooks (`.claude/settings.json`; timeouts in seconds)

Every hook command starts from `$CLAUDE_PROJECT_DIR`, never a relative path: a session whose shell sits in `backend/` or `frontend/` must still find the script. The Bash guard does nothing when its script is missing (the git hooks are the gate).

| Event | Script | Does |
|---|---|---|
| PreToolUse Agent, Task, Workflow | `guardrails/runner.py` | Blocks a subagent not pinned to `opus` or `sonnet` with an effort, and forks. |
| PreToolUse Bash | `hooks/git_guard.py` | Blocks a commit unless `core.hooksPath` is the git hooks; blocks `--no-verify`, `commit -n`, hooksPath changes, `GIT_*=` and HUSKY/SKIP switches, cherry-pick/revert without `--no-commit`, rebase and am (git runs no commit hooks for those); asks a committing call for timeout 600000 or the background. |
| SessionStart startup, resume, compact | `hooks/session-start.sh` | Sets `core.hooksPath` to the git hooks if it is anything else and makes the hooks executable; silent, one line if it cannot, never fails the session. |
| PostToolUse Edit, Write | `hooks/post-edit-format.sh` | Formats the edited `.py` (ruff) or `.dart` file. |
| Stop | `hooks/verify-done.sh` | With uncommitted `.py`/`.dart` work, runs the tests it touches, unless they already passed on the same inputs. |

## Guardrails (`.claude/guardrails/`)

`runner.py` runs the rules in `config.toml` (deny or warn only). The one rule,
`subagent_model_effort`, keeps subagents off the main session's model for cost. Its message points at
`docs/dev/running-the-work.md`, which holds how to choose a model and effort. Adding a
rule: `.claude/guardrails/README.md`. Tests: `just test-guardrails`. A test or check that scans
repo files reads them from `tool/repo_files.py` (git's tracked files only), so a builder's
worktree copy under `.claude/worktrees/` is never scanned.

## Agents (`.claude/agents/`, each pins model and effort)

| Agent | Model, effort | Tools |
|---|---|---|
| `backend-developer`, `frontend-developer` | opus, high | all |
| `backend-code-reviewer`, `frontend-code-reviewer` | opus, high | Read, Grep, Glob, Bash: no edit tools |
| `player-experience` | opus, high | Read, Grep, Glob |

The developer agents' briefs carry no old-look or protocol-1 rule any more: both are deleted.

## Skills (`.claude/skills/`)

Twelve third-party `flutter-*` skills (Flutter's generic guides on animation, architecture,
layout, concurrency, HTTP and JSON, navigation, accessibility, state, macOS setup, testing,
theming, databases), mirrored in `.agents/skills/`. Nothing here depends on them; keeping them
is the owner's call.
