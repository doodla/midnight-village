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
`guardrails/tests/test_release_assets.py` holds `frontend/tool/record_release_assets.py` to refusing to record over a removed asset that has no retired copy or dated reason. The `Web page smoke` job's `routes.test.cjs` judges `frontend/vercel.json` as Vercel compiles it, so `test_workflows.py` no longer reads its rewrite as a pattern.

A second workflow is not part of the wall: `deployed-check.yml` ("Deployed Check") runs after
every merge to main and proves the live server and app work together
(`tool/deployed_check.py`; `docs/dev/deploy-vercel.md`, "The check after each merge"). It can
only run after the merge, so it is never a required check; it reads public addresses, writes
nothing and holds no secret (`WorkflowAfterMerge` in the same test file).

**File sizes.** `tool/check_file_sizes.py` fails `just check`, the commit gate (on what is
staged) and `just gate-full` when a source file passes 600 lines: a file that long cannot be
read whole, and two branches that touch it collide. A file already over it on main may stay
or shrink but not grow: move something out first, then add. There is no list: the check
compares with main on the remote (fetched when a shallow checkout lacks it), so only the change
that adds to a long file fails. Tests and generated code are not counted
(`guardrails/tests/test_file_sizes.py`).

**Guards.** A test that holds a rule for the whole app carries `Guard file` in a comment at
its top (no list: a new guard joins by carrying the line). `tool/guard_edits.py`
(`just guard-edits`, a step of GitHub's "Backend Checks") fails a pull request that edits one
unless its description has a line `- <file name>: <why>`; locally it only reminds
(`guardrails/tests/test_guard_edits.py`). `just check` also lints `tool/` and the hooks for
errors swallowed in silence (`just lint-tools` in `backend/`).

**The fast check.** `just piece-check` (`tool/piece_check.py`) is what a builder runs between
edits: the fast checks, every backend test on every core (about a minute and a half: choosing
among them does not pay, the modules all lead to each other), and for the app only the test
files nearest the change, found by following imports from each test (`--far`: every test that
can see it; `--list`: the plan only). Nothing is listed by hand
(`guardrails/tests/test_piece_check.py`). GitHub still runs everything.

`guardrails/tests/test_checkout_whole.py` keeps a fresh checkout working as it stands: every
shell script parses (`bash -n`), the lint and type tools in recipes and hooks are run as
`uv run --group lint <tool>` (the version in `uv.lock`, never one from PATH), and
`tool/ensure_env.sh` writes a missing `backend/.env` and leaves an existing one alone.

The ruleset `docs/dev/main-ruleset.json` is what makes this the wall: a pull request on the
default branch, squash merges only, every check above required (up to date with main not
required, so two sessions do not block each other), no force pushes or deletion, nobody
bypassing. It is on: the owner imported it (GitHub reports main as protected, checked 23 November 2026).
To import it again: Settings, Rules, Rulesets, New ruleset, Import a ruleset, choose the
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
| PreToolUse Bash | `hooks/git_guard.py` | Stops the mistakes and shortcuts that would skip the commit gate. It is not a wall (the wall is GitHub): it reads one Bash command as text, so a script file, a `just` recipe or another program that calls git is not read. Blocks a commit unless `core.hooksPath` is the git hooks; blocks `--no-verify` (and its shortened spellings), `commit -n`, hooksPath changes (by `git config` or `-c`), an alias or include set from the command, `git config --edit`, `git commit-tree`, `GIT_*=` variables that redirect git, HUSKY/SKIP/`GATE_*` switches on a git call, cherry-pick/revert without `--no-commit`, rebase and am (git runs no commit hooks for those). It reads the command as the shell would: only a `git` in command position counts, so a message, a search pattern, a comment or a here-document that merely contains those words goes on (`SKIP=slow pytest` too); and it looks inside `bash -c`, `eval`, `trap`, `$(...)`, backticks, `$'...'`, a here-document fed to a shell, a function body, wrappers such as `env`, `xargs` and `find -exec`, and the clone's git aliases. A shell fed by a pipe in a command that names a committing git call is blocked, since it cannot be read. Tests: `guardrails/tests/test_git_guard.py` (almost 190 commands in both directions, every line of the recipes, workflows and hook scripts that names git, a fuzz for crashes, and counts of the work big input costs, with no clock). |
| SessionStart startup, resume, compact | `hooks/session-start.sh` | Sets `core.hooksPath` to the git hooks if it is anything else and makes the hooks executable; starts Postgres when it is installed and down; silent, one line if it cannot set the gate, never fails the session. A fresh container's tools come from `tool/bootstrap_container.sh` (`docs/dev/environment.md`), not from this hook. |
| PostToolUse Edit, Write | `hooks/post-edit-format.sh` | Formats the edited `.py` (the ruff in `uv.lock`: `uv run --group lint`, never one from PATH) or `.dart` file. |
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
| `critic-editor`, `critic-art-director` (judge pictures cold, see "The two critics" in `docs/dev/running-the-work.md`) | opus, high | Read, Glob: no edits |
| `worker` (small exact jobs) | sonnet, medium | Read, Edit, Write, Grep, Glob, Bash |
| `eyes` (looks at PNGs, reports in words) | sonnet, medium | Read, Glob: no edits |

Every agent lists its tools: one defined with all tools starts at about 78k tokens of context
(connector tool descriptions), one with a short list at 7-10k. A new agent lists its tools too.
`just contact-sheet` (run in `frontend/`) makes one image of the `just screens` output
(`frontend/tool/contact_sheet.py`). The rules for using them: `docs/dev/running-the-work.md`,
"Lean helpers"; the numbers: `docs/dev/agent-ledger.md`.

The developer agents' briefs carry no old-look or protocol-1 rule any more: both are deleted.

## Skills (`.claude/skills/`)

Seven third-party `flutter-*` skills (Flutter's generic guides on animation, layout,
concurrency, HTTP and JSON, accessibility, testing, theming). Nothing here depends on them, and
where one disagrees with `frontend/CLAUDE.md` the CLAUDE.md wins. Five were removed on 23
November 2026: state and architecture (they prescribe `provider` and `ChangeNotifier`; the app
is Riverpod), navigation (`Navigator.push`; the app is go_router), databases (SQLite; the app
has none) and macOS setup. The second copy of all twelve, in a root `.agents` folder, is gone too.
