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
runs on a pull request, is not in the ruleset, has a paths filter, builds with a read token and
publishes from a second job, the only one with `contents: write`, that runs nothing but `gh`.
`WriteTokens` (same file) holds every workflow to this: a job with a write token runs only actions
pinned by commit (version in a comment), and its checkout keeps the token only if the job pushes. `guardrails/tests/test_workflows.py` sets it apart (`PUBLISHING`) and holds it to those rules
(`WorkflowPublishing`); the wall's rules above apply to every other workflow.
`guardrails/tests/test_release_assets.py` holds `frontend/tool/record_release_assets.py` to refusing to record over a removed asset that has no retired copy or
dated reason. The `Web page smoke` job's `routes.test.cjs` judges `frontend/vercel.json` as Vercel compiles it, so `test_workflows.py` no longer reads its
rewrite as a pattern.

The branches Vercel deploys from (`live-server`, `live-app`) are moved by `tool/promote_live.py`
only when what a side ships changed, only once main's required checks passed on the merged
commit, the server before the app, only forward, and never below the rollback floor `FLOOR`
(`guardrails/tests/test_promote_live.py`: a deliberate break per promise, with no network).
GitHub holds the same on its side: rulesets in `docs/dev/rulesets/` (no deleting or rewinding;
only the release job's deploy key, kept in the environment `live` that only main may use, moves a
live branch), rehearsed first on `live-rehearsal` by `live-rehearsal.yml` and
`tool/rehearse_live_rule.py`. `guardrails/tests/test_release_workflows.py` holds the files to each
other (the rehearsal is the real rule on a scratch branch; only those two workflows read the key).
The way back is `just revert-release <PR or commit>` (`tool/revert_release.py`): a branch from
main that undoes one merge, keeping the migrations the live database ran, refusing a change at
or below the floor, pushing only with `--push` (`guardrails/tests/test_revert_release.py`
rehearses it on a throwaway repository).

A second workflow is not part of the wall: `deployed-check.yml` ("Deployed Check") runs after
every merge to main and proves the live server and app work together
(`tool/deployed_check.py`; `docs/dev/deploy-vercel.md`, "The check after each merge"). It can
only run after the merge, so it is never a required check; it reads public addresses, writes
nothing and holds no secret (`WorkflowAfterMerge` in the same test file).
Its socket step also reports how long each kind of request took on the live server
(`tool/deployed_timing.py`, held by `guardrails/tests/test_deployed_timing.py`): a table in the run's summary and a kept file, never a failure.
`live-watch.yml` ("Live Watch") runs the same check every 6 hours and by hand, with `--deep`
(`/api/health/?deep=1`: the database and Redis, ok or failed), moving nothing
(`TheWatch` in `guardrails/tests/test_release_workflows.py`).

**What a change is compared with.** `tool/change_base.py`: the main the change was built
on (on a pull request the merge's first parent, elsewhere where the branch left main),
never main as it is now, so main moving under a running check is not blamed on the
change (`guardrails/tests/test_change_base.py`). The file-size, guard-edit and
previous-build checks all take it from there.

**Words added.** `tool/words_added.py` (the same step as the guard lines, `just guard-edits`)
compares every copy key with the main the change was built on; a copy class with more words
than it had needs a line under `Words added` in the pull request's description. It replaces
the pinned per-screen word budgets (`guardrails/tests/test_words_added.py`).

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
(`guardrails/tests/test_guard_edits.py`; a changed binary file, a golden picture, is never
read: a guard is a text file). `just check` also lints `tool/` and the hooks for
errors swallowed in silence (`just lint-tools` in `backend/`).

**Proved guards.** A guard counts only if a recorded deliberate break proves it bites. `just prove-guards`
(`tool/prove_guards.py`) holds named breaks (`tool/breaks_server.py`, `breaks_tools.py`,
`breaks_app.py`): each a small realistic mistake, the CLAUDE.md promise it breaks, and the
focused tests that must fail on it. Each is put into a throwaway copy of the tree, anchored on
a function or a marker line (an anchor that moved fails "break no longer applies: update
it"). A break is killed only when a named killer test fails an assertion, and a backend
break names that failure (`expect=`, the words of the promise's own assertion, or its tests as
`path::test`) (`tool/breaks_verdict.py`): an import error, a test that errors, a crash in the
code under test, the two-deal script failing to play (`ScriptError`), a failure other than the
named one, a command that fails without printing what its guard prints, a failed sample
re-record or a Flutter file that does not build is "broken" and fails the run. A bogus break
(`proves_nothing=`, the review's X4) must come out "broken". It also fails when a
known survivor (`survives=`) is killed, and when a `Guard file` kills no break or its breaks
ran and none saw a test in it fail (`tool/breaks_rules.py`; a helper guard counts through the
tests that import it). Against main, `NOT_YET_PROVED` (the guards older than the rule) and the
known survivors only shrink and no break disappears, unless the pull request names it under
"Guards changed". GitHub runs the server's and tools' breaks in "Backend Checks" and the
app's in "Analyze and Format" (a Flutter break that cannot run there fails); `just handover`
runs those whose promise the change touches (`guardrails/tests/test_prove_guards.py` and
`test_prove_guards_runs.py`; the first also applies every break to the tree as it stands).

**Disk.** Each worktree fills about a gigabyte of build output. `tool/tidy.py` clears it for
a worktree that has gone quiet: no source file changed for three hours and no process is
working in it (the session-start hook runs this in the background). `just tidy` also removes
a worktree whose branch's remote is gone (merged) when nothing in it is uncommitted. A
helper's worktree, whose branch never had a remote of its own name, is never removed by it:
that stays a person's decision (`guardrails/tests/test_tidy.py`).

**Words.** The app's copy has one home, `frontend/lib/design_system/copy/`. `tool/copy_page.py`
makes a page of every key and its words on demand (`just copy-page`, to `frontend/build/`,
not committed: two branches regenerating one file would collide; GitHub attaches it to the
screens job) and, in `just check`, fails a spec under `docs/specs/frontend/` that names a copy
class or key in backticks that does not exist, and a quote in section 3 of
`first-time-play.md` that repeats the words of a key, exact or filled in (the spec names
the key; the words cannot drift into a second home) (`guardrails/tests/test_copy_page.py`).

**Starting and handing over.** `just brief <screen>` (`tool/brief.py`) prints what a builder
needs from the sources themselves: the spec's section and the owner's lines about the
screen word for word, its catalogue states and parked faults, the files that draw it with
their sizes, its tests, and the remote branches in the same files. Work that is not a screen
has an area brief (`just brief copy`; `tool/brief_areas.py` is the table: an area's rules
printed word for word from where they are written, its files with sizes, its model slice,
its tests, who else is in them; `test_brief.py` fails a row that points at nothing), and
`just brief` alone lists every brief. A red test run ends with what failed
(`tool/failed_tests.py`: each failed test's file, name and first error line, from the run's
own report; on GitHub an annotation each, and the database keeps its own log quiet so the
list is the job's last lines; `guardrails/tests/test_failed_tests.py`). `just handover <file>`
(`tool/handover.py`, `frontend/tool/handover_sheet.py`) is the one way to hand over: it
refuses work that is not committed, pushed and mergeable with main; runs the fast check's
plan at both widths plus the harness, and, when the app's code or assets changed, the golden
tests and every test that scans all of `lib/` (found by what they do, not listed:
`tool/lib_scans.py`, a test that lists a directory tree or carries `Guard file`); reads GitHub's
required checks from the workflows and the ruleset (`tool/github_checks.py`) and says for each
whether it ran here, passed, failed, ran only in part or did not run, so the first line is
"READY (N of M of GitHub's checks run here)" and never "GitHub will pass"
(`guardrails/tests/test_github_checks.py`); each result and each finished set of pictures kept per commit
the moment it is done, so a run killed part way carries on when run again; draws every reached state beside main at 412x915 and 360x640 and puts the changed ones
on contact sheets; and writes the hand-over file in one fixed shape
(`guardrails/tests/test_handover.py`, `test_brief.py`). Every recipe of `frontend/` and
`backend/` also exists at the root, and those folders fall back to the root's.
`tool/root_recipes.py` (in `just check`) fails only for a recipe the change itself adds
without its root line, and `--fix` writes the lines
(`guardrails/tests/test_recipes_everywhere.py`).

**The heavy queue.** `tool/heavy.py` (`just heavy <command...>`, `just heavy --status`) is a counting queue
for every heavy command: 3 at once (by the machine's memory and the measured peak of each kind of job, in
`docs/dev/running-the-work.md`, "Waiting, and the heavy queue"), the rest in order, saying where they stand at once and
every 30 seconds. A slot is a file lock no child inherits, released on any exit; the command runs in a session of its own, is
stopped with its heavy parent, and what it leaves running is stopped; each run's time and peak memory go to its history.
The recipes that run tests, builds, screens, the harness, phone-frames and phone-timing call it themselves, and
`just piece-check` and `just handover` queue their heavy steps (`heavy.wrap`); inside a heavy command it runs at once
(`HEAVY_SLOT`), on GitHub (`CI`) it does nothing. `guardrails/tests/test_heavy.py` holds the queue (the count, the order, no
inherited slot, `kill -9`, nesting), that every heavy command in a justfile goes through it, and that every script that
boots the backend stops its whole process group on any exit (`phone-timing` did not until now).

**As GitHub's backend job runs it.** That job has no Flutter, so `just test-guardrails` runs its tests with Flutter and Dart
off PATH (`tool/path_without.py`; `guardrails/tests/test_path_without.py`): a test that runs them fails on a builder's
machine too, not only on the pull request (the first run of the heavy-queue change did, in a brief of a screen).

**A rule holds per change.** A check that reads the whole tree can be passed by two pull
requests separately and fail once both are merged, for a builder who did neither. So a rule
compares a change with the main it was built on (`tool/change_base.py`, or the merge base in
a Dart test) and fails only for what that change did: file sizes, guard edits, root recipes,
the to-do list of unswept states, raw values, removed assets. What cannot be made so (two
changes that break each other's code or re-record the same samples) is caught by main's own
run after each merge, and said: `.github/workflows/main-red.yml` (`tool/main_red.py`) opens
one issue, "main is red", naming the check and the merge, adds to it while it is red, and
closes it when main's newest runs have all passed (`guardrails/tests/test_workflows.py`).

**The built web app, once.** `frontend/tool/web_build_cached.sh` gives a tool the folder of a finished web build and builds again only when what goes into it changed.
`guardrails/tests/test_web_build_cached.py` holds that with a stand-in for the build: built once, again on a changed source or argument, nothing left by a failed build, the newest four kept.

**Lines of the notes.** `tool/doc_lines.py` finds prose lines over 200 characters in the tracked `*.md` files
(two branches that add a word to one such line clash) and `--fix` reflows them, one sentence to a line, changing line breaks only
(`guardrails/tests/test_doc_lines.py`: every tracked note keeps every word in order).
It runs in `just check`. Left alone: front matter, the owner's words (`docs/dev/owner-feedback.md`), recorded samples and the skills under `.claude/skills/`.

**The fast check.** `just piece-check` (`tool/piece_check.py`) is what a builder runs between
edits: the fast checks, every backend test on every core (about a minute and a half: choosing
among them does not pay, the modules all lead to each other), and for the app only the test
files nearest the change, found by following imports from each test (`--far`: every test that
can see it; `--list`: the plan only). It renders only the screen states that draw what
changed, strict at 360 and 390 (at 390 only when more than 60 states are reached, unless
`--both-widths`; `--no-screens` for a change to logic only): `tool/piece_screens.py` walks every catalogue state's widget
tree (about a minute, reused until the app changes), reads which file declares each widget
class, and follows a file that draws nothing to the files that use it. Nothing is listed by hand
(`guardrails/tests/test_piece_check.py`).
A change to what the server sends (a recorded sample) or to the harness itself also runs the end-to-end harness, the one test that reads both sides at once;
a red harness run ends with the failed tests' names (`tool/failed_tests.py`).
It ends with the lines the pull request's description must carry (a guard file edited, words added), since only GitHub can read the description and fails
without them. It is never silent: the plan gives each step's rough
time and the total before anything runs, and a step that prints nothing says it is still
running every 30 seconds. GitHub still runs everything.

`guardrails/tests/test_checkout_whole.py` keeps a fresh checkout working as it stands: every
shell script parses (`bash -n`), the lint and type tools in recipes and hooks are run as
`uv run --group lint <tool>` (the version in `uv.lock`, never one from PATH), and
`tool/ensure_env.sh` writes a missing `backend/.env` and leaves an existing one alone
(the harness's backend recipe calls it too, and reads what it wrote).

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

Every hook command starts from `$CLAUDE_PROJECT_DIR`, never a relative path:
a session whose shell sits in `backend/` or `frontend/` must still find the script.
The Bash guard does nothing when its script is missing (the git hooks are the gate).

| Event | Script | Does |
|---|---|---|
| PreToolUse Agent, Task, Workflow | `guardrails/runner.py` | Blocks a subagent not pinned to `opus`, `sonnet` or `haiku` (on trial) with an effort, and forks. |
| PreToolUse Bash | `hooks/git_guard.py` | Stops the mistakes and shortcuts that would skip the commit gate. Its reading of shell text (here-documents, `$(...)`, line ends, the words of each simple command) is `hooks/shell_text.py`, which knows nothing of git. It is not a wall (the wall is GitHub): it reads one Bash command as text, so a script file, a `just` recipe or another program that calls git is not read. Blocks a commit unless `core.hooksPath` is the git hooks; blocks `--no-verify` (and its shortened spellings), `commit -n`, hooksPath changes (by `git config` or `-c`), an alias or include set from the command, `git config --edit`, `git commit-tree`, `GIT_*=` variables that redirect git, HUSKY/SKIP/`GATE_*` switches on a git call, cherry-pick/revert without `--no-commit`, rebase and am (git runs no commit hooks for those). Blocks any push that writes `live-server` or `live-app` (a refspec's destination, `:branch` and `--delete`, a bare branch name, the current branch and its `@{push}` when no refspec or `HEAD` is given, a matching pattern, `:`, `--all`, `--branches`, `--mirror`; `hooks/push_rules.py`): only the release job moves them. It reads the command as the shell would: only a `git` in command position counts, so a message, a search pattern, a comment or a here-document that merely contains those words goes on (`SKIP=slow pytest` too); and it looks inside `bash -c`, `eval`, `trap`, `$(...)`, backticks, `$'...'`, a here-document fed to a shell, a function body, wrappers such as `env`, `xargs` and `find -exec`, and the clone's git aliases. A shell fed by a pipe in a command that names a committing git call is blocked, since it cannot be read. Tests: `guardrails/tests/test_git_guard.py` (about 230 commands in both directions, a clone on a live branch and one whose upstream is one, every line of the recipes, workflows and hook scripts that names git, a fuzz for crashes, and counts of the work big input costs, with no clock). |
| SessionStart startup, resume, compact | `hooks/session-start.sh` | Sets `core.hooksPath` to the git hooks if it is anything else and makes the hooks executable; starts Postgres when it is installed and down; silent, one line if it cannot set the gate, never fails the session. A fresh container's tools come from `tool/bootstrap_container.sh` (`docs/dev/environment.md`), not from this hook. |
| PreToolUse Bash | `hooks/poll_guard.py` | Refuses a command whose whole purpose is a sleep loop on another job: an `until`, `while` or `for` with a `sleep` in it that looks at a process (`pgrep`, `ps`, `kill -0`), a log or marker file (`tail`, `grep`, `cat`, `test -f`), the queue (`heavy`, `flock`) or GitHub (`gh`). The message says what to do: start the job once with `run_in_background`, end the turn, and you are woken when it exits. Left alone: a loop that waits for a service just started (`curl`, `wget`, `nc`), a loop without a sleep, a sleep alone, and words that only mention it (a commit message, a search, a here-document), read as the shell reads them (`shell_text.py`; `bash -c '...'` is read inside). It is a reminder, not a wall, and fails open. Tests, both ways: `guardrails/tests/test_poll_guard.py`. |
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
