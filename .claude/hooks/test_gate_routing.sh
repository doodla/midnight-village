#!/usr/bin/env bash
# Tests the commit gate: routing (which checks a commit's paths run), renames,
# the commit-subject check, the Bash guard, the "already passed on this content"
# record, failing closed when the gate is broken, that the gate runs only the
# fast checks (never a test suite) while `just gate-full` runs everything, and
# the git hooks end to end in a throwaway repository. Run by `just test-guardrails`.
set -uo pipefail
# A hook (or a test run from one) inherits git's variables: never let them
# point the throwaway repositories below at this one.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_PREFIX
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HOOKS/../.." && pwd)"
# shellcheck source=lib/gate.sh
source "$HOOKS/lib/gate.sh"
fails=0
fail() { echo "FAIL $*"; fails=$((fails + 1)); }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---- routing: paths -> blocks ----
route() { printf '%s\n' "$@" | gate_route | tr '\n' ' ' | sed 's/ $//'; }
expect_route() {  # expect_route "<blocks>" path...
  local want="$1"; shift
  local got; got="$(route "$@")"
  [ "$got" = "$want" ] || fail "route [$*]: want '$want', got '$got'"
}
expect_route ""                         docs/dev/status.md
expect_route ""                         CLAUDE.md backend/CLAUDE.md frontend/CLAUDE.md
expect_route ""                         backend/apps/onuw/README.md frontend/test/README.md
expect_route ""                         docs/dev/models/phone/night/PhoneNight.tla docs/design/mocks/01-join.png
expect_route ""                         .claude/skills/flutter-testing-apps/SKILL.md
expect_route "guardrails"               tool/check_instruction_links.sh tool/setup_env.sh
expect_route "backend"                  backend/apps/onuw/services.py
expect_route "backend"                  backend/pyproject.toml backend/uv.lock
expect_route "backend"                  docs/specs/onuw/recommended-setups.md
expect_route "frontend"                 frontend/lib/main.dart
expect_route "frontend"                 frontend/pubspec.yaml frontend/CLAUDE.md
expect_route "backend frontend"         contract_samples/index.json
expect_route "backend frontend"         backend/apps/core/views.py frontend/lib/main.dart
expect_route "guardrails"               .claude/settings.json
expect_route "guardrails"               .claude/agents/frontend-code-reviewer.md
expect_route "guardrails"               .claude/hooks/git/pre-commit .claude/hooks/git_guard.py
expect_route "backend frontend guardrails" justfile
expect_route "guardrails"               .github/workflows/flutter-tests.yml
expect_route "guardrails"               docs/dev/main-ruleset.json
expect_route "backend frontend"         .gitignore

# ---- a throwaway repository with this repo's hooks ----
R="$TMP/repo"
mkdir -p "$R/backend" "$R/frontend/lib" "$R/docs" "$R/contract_samples" "$R/tool" "$R/.claude"
cp -r "$HOOKS" "$R/.claude/hooks"
printf '#!/bin/sh\nexit 0\n' > "$R/tool/check_instruction_links.sh"; chmod +x "$R/tool/check_instruction_links.sh"
cp "$REPO/tool/check_file_sizes.py" "$R/tool/check_file_sizes.py"
cp "$REPO/tool/change_base.py" "$R/tool/change_base.py"
echo a > "$R/backend/x.py"; echo b > "$R/frontend/lib/y.dart"; echo c > "$R/docs/z.md"
(
  # the copied hooks hold a long file: it is in the first commit, so the size check (which
  # compares with what is committed) starts clean
  cd "$R" && git init -q -b main && git config user.email t@t && git config user.name t \
    && git add -A && git commit -q --no-verify -m "chore: init" \
    && git config core.hooksPath .claude/hooks/git
) || { echo "FAIL could not make a temp repo"; exit 1; }
staged() { (cd "$R" && gate_staged_paths | gate_route | tr '\n' ' ' | sed 's/ $//'); }

# renames out of code still run that code's suite
(cd "$R" && git mv frontend/lib/y.dart docs/y.dart)
[ "$(staged)" = "frontend" ] || fail "rename out of frontend/: want frontend, got '$(staged)'"
(cd "$R" && git reset -q --hard)
(cd "$R" && git mv backend/x.py docs/x.py)
[ "$(staged)" = "backend" ] || fail "rename out of backend/: want backend, got '$(staged)'"
(cd "$R" && git reset -q --hard)

# ---- the record of a passed run follows the content, not the commit ----
hash_of() { (cd "$R" && gate_hash "$1"); }
h1=$(hash_of backend); f1=$(hash_of frontend)
echo c > "$R/frontend/lib/y.dart"
[ "$(hash_of backend)" = "$h1" ] || fail "backend hash moved on a frontend edit"
[ "$(hash_of frontend)" != "$f1" ] || fail "frontend hash ignored an unstaged edit"
echo n > "$R/backend/new.py"
[ "$(hash_of backend)" != "$h1" ] || fail "backend hash ignored an untracked file"
rm "$R/backend/new.py"
[ "$(hash_of backend)" = "$h1" ] || fail "backend hash not back after the undo"
echo "DB_NAME=x" > "$R/backend/.env"; printf 'backend/.env\n' > "$R/.gitignore"
h2=$(hash_of backend)
echo "DB_NAME=y" > "$R/backend/.env"
[ "$(hash_of backend)" != "$h2" ] || fail "backend hash ignored backend/.env"
echo "x:" > "$R/justfile"
[ "$(hash_of guardrails)" != "$(cd "$R" && rm justfile && gate_hash guardrails)" ] \
  || fail "guardrails hash ignored the root justfile"
(cd "$R" && git checkout -q -- . && rm -f .gitignore backend/.env)
(cd "$R" && gate_record "backend-tests-$h1" && gate_passed "backend-tests-$h1") || fail "record not found"
(cd "$R" && ! gate_passed "frontend-tests-$f1") || fail "unrecorded run found"
old="$R/$(cd "$R" && gate_stamp_dir)/backend-tests-old"
touch -d '20 days ago' "$old" || fail "could not make an old record"
(cd "$R" && gate_record "backend-tests-new")
[ ! -e "$old" ] || fail "a record older than 14 days was kept"

# ---- the git hooks, end to end (suites replaced by a stub that passes) ----
commit() { (cd "$R" && GATE_BLOCK_TIMEOUT=5 git commit -q "$@" >/dev/null 2>&1); }
# docs only: no suite, subject checked
echo d >> "$R/docs/z.md"; (cd "$R" && git add docs/z.md)
commit -m "docs: fine" || fail "docs-only commit with a good subject was blocked"
echo d >> "$R/docs/z.md"; (cd "$R" && git add docs/z.md)
commit -m "update stuff" && fail "a bad subject passed commit-msg"
(cd "$R" && git reset -q --hard)
# a code commit whose suite fails is blocked (no just in the throwaway repo, so
# the suite fails): -a, a pathspec commit and a rename all reach the gate
echo e >> "$R/frontend/lib/y.dart"
commit -a -m "fix: x" && fail "commit -a with a failing frontend suite passed"
commit -m "fix: x" frontend/lib/y.dart && fail "a pathspec commit with a failing suite passed"
(cd "$R" && git checkout -q -- . && git mv frontend/lib/y.dart docs/y.dart)
commit -m "docs: move" && fail "a rename out of frontend/ skipped the frontend suite"
(cd "$R" && git reset -q --hard)
# the gate runs the fast checks and never a test suite: a stub `just` logs what
# it was asked to run (the directory, then the recipe) and passes
mkdir -p "$TMP/bin"
printf '#!/bin/sh\necho "$(basename "$PWD") $*" >> "%s/just.log"\nexit 0\n' "$TMP" > "$TMP/bin/just"
chmod +x "$TMP/bin/just"
commit_ok() { (cd "$R" && PATH="$TMP/bin:$PATH" GATE_BLOCK_TIMEOUT=5 git commit -q "$@" >/dev/null 2>&1); }
: > "$TMP/just.log"
echo h >> "$R/frontend/lib/y.dart"; echo h >> "$R/backend/x.py"
(cd "$R" && git add frontend/lib/y.dart backend/x.py)
commit_ok -m "fix: both" || fail "a commit whose fast checks pass was blocked"
grep -qx "frontend analyze" "$TMP/just.log" || fail "the gate did not run analyze for a frontend change"
grep -qx "frontend flutter-format-check" "$TMP/just.log" || fail "the gate did not run format-check for a frontend change"
grep -qx "repo check" "$TMP/just.log" || fail "the gate did not run the root check for a backend change"
grep -qE ' (test|test-guardrails|gen-check|screens)' "$TMP/just.log" && fail "the gate ran a test suite: $(tr '\n' ';' < "$TMP/just.log")"
# a commit of documentation runs no check at all
: > "$TMP/just.log"
echo i >> "$R/docs/z.md"; (cd "$R" && git add docs/z.md)
commit_ok -m "docs: only" || fail "a docs-only commit was blocked"
[ ! -s "$TMP/just.log" ] || fail "a docs-only commit ran checks: $(cat "$TMP/just.log")"
# `just gate-full` runs the suites and the extras, records the pass, and fails when a suite fails
: > "$TMP/just.log"
(cd "$R" && PATH="$TMP/bin:$PATH" gate_full >/dev/null 2>&1) || fail "gate_full failed with every step passing"
for want in "repo check" "repo test-backend" "repo previous-build-check" "frontend flutter-test" "frontend gen-check" "frontend check-release" "frontend test-harness" "frontend screens 360 strict" "frontend screens 390 strict" "repo test-guardrails"; do
  grep -qx "$want" "$TMP/just.log" || fail "gate_full did not run: $want"
done
(cd "$R" && gate_passed "backend-full-$(gate_hash backend)" && gate_passed "backend-fast-$(gate_hash backend)") \
  || fail "gate_full did not record its pass"
(cd "$R" && gate_full >/dev/null 2>&1) && fail "gate_full passed with failing suites"
(cd "$R" && gate_full nonsense >/dev/null 2>&1); [ $? -eq 2 ] || fail "gate_full took an unknown block"
# a broken gate blocks every commit
cp "$R/.claude/hooks/lib/gate.sh" "$TMP/gate.sh"
echo "this is not bash (" >> "$R/.claude/hooks/lib/gate.sh"
echo f >> "$R/docs/z.md"; (cd "$R" && git add docs/z.md)
commit -m "docs: fine" && fail "a broken gate.sh let a commit through"
printf 'gate_route() { :; }\n' > "$R/.claude/hooks/lib/gate.sh"
commit -m "docs: fine" && fail "a gate.sh missing functions let a commit through"
cp "$TMP/gate.sh" "$R/.claude/hooks/lib/gate.sh"
# the Stop hook fails closed too
printf 'gate_route() { :; }\n' > "$R/.claude/hooks/lib/gate.sh"
echo g >> "$R/backend/x.py"
printf '{"stop_hook_active": false, "cwd": "%s"}' "$R" | "$R/.claude/hooks/verify-done.sh" >/dev/null 2>&1
[ $? -eq 2 ] || fail "the Stop hook did not block with a broken gate.sh"
cp "$TMP/gate.sh" "$R/.claude/hooks/lib/gate.sh"

# ---- commit subjects ----
expect_msg() {  # expect_msg <0|1> <message>
  printf '%s\n' "$2" > "$TMP/msg"
  python3 "$HOOKS/lib/commit_msg.py" "$TMP/msg" >/dev/null
  [ "$?" = "$1" ] || fail "subject [$2]: want exit $1"
}
expect_msg 0 "docs(dev): status only"
expect_msg 0 "fix: no scope"
expect_msg 0 $'# a git comment\n\nchore(claude): after comments\n\nbody "quoted"'
expect_msg 0 "Merge branch 'ccr-2435dc07-33z3jn' into x"
expect_msg 0 'Revert "feat(x): y"'
expect_msg 1 "update stuff"
expect_msg 1 "feature(x): wrong type"
expect_msg 1 "fix(x):missing space"
expect_msg 1 ""

# ---- the Bash guard ----
guard() {  # guard <0|2> <command> [timeout] [background]
  local want="$1" cmd="$2" t="${3:-600000}" bg="${4:-false}" got
  jq -n --arg c "$cmd" --arg d "$R" --argjson t "$t" --argjson b "$bg" \
    '{tool_input:{command:$c, timeout:$t, run_in_background:$b}, cwd:$d}' \
    | python3 "$HOOKS/git_guard.py" 2>/dev/null
  got=$?
  [ "$got" = "$want" ] || fail "guard [$cmd timeout=$t bg=$bg]: want $want, got $got"
}
guard 0 'git commit -m "docs: x"'
guard 0 'git commit -m "$MSG"'
guard 0 'git commit -m x -a'
guard 0 'git -C backend --no-pager commit -am "fix: y"'
guard 0 'git merge --ff-only main' 120000
guard 0 'git status' 120000
guard 0 'git commit -m "no n flag here"'
guard 2 'git commit --no-verify -m x'
guard 2 'git commit -n -m x'
guard 2 'git commit -anm x'
guard 2 'git -c core.hooksPath=/dev/null commit -m x'
guard 2 'git config core.hooksPath /tmp/none' 120000
guard 2 'git config --unset core.hooksPath' 120000
guard 2 'GIT_DIR=/tmp/other/.git git commit -m x'
guard 0 'GIT_INDEX_FILE=/tmp/i git add -A'
guard 2 'HUSKY=0 git commit -m x'
guard 2 'git cherry-pick abc123'
guard 0 'git cherry-pick --no-commit abc123'
guard 2 'git rebase main' 120000
guard 0 'git commit -m "docs: x"' 120000
guard 0 'git commit -m "docs: x"' 120000 true
guard 0 'git commit -m "docs: x"' 0
guard 0 'git -c core.hooksPath=.claude/hooks/git commit -m x'
guard 0 'git config --get core.hooksPath' 120000
# a commit is blocked while core.hooksPath is unset or elsewhere, unless the
# command itself names the hooks; other git commands go on
(cd "$R" && git config --unset core.hooksPath)
guard 2 'git commit -m "docs: x"'
guard 2 'cd x && git merge main'
guard 0 'git -c core.hooksPath=.claude/hooks/git commit -m "docs: x"'
guard 0 'git status' 120000
(cd "$R" && git config core.hooksPath /tmp/none)
guard 2 'git commit -m "docs: x"'
(cd "$R" && git config core.hooksPath .claude/hooks/git)

# ---- session-start.sh turns the gate on, silently, and never fails ----
(cd "$R" && git config --unset core.hooksPath)
out=$("$HOOKS/session-start.sh" "$R" 2>&1); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] || fail "session-start: want silent exit 0, got $rc '$out'"
[ "$(cd "$R" && git config core.hooksPath)" = ".claude/hooks/git" ] || fail "session-start did not set core.hooksPath"
(cd "$R" && git config core.hooksPath /tmp/none)
"$HOOKS/session-start.sh" "$R" >/dev/null 2>&1
[ "$(cd "$R" && git config core.hooksPath)" = ".claude/hooks/git" ] || fail "session-start did not replace a wrong core.hooksPath"
chmod -x "$R/.claude/hooks/git/pre-commit"
"$HOOKS/session-start.sh" "$R" >/dev/null 2>&1
[ -x "$R/.claude/hooks/git/pre-commit" ] || fail "session-start did not make the hooks executable"
mkdir -p "$TMP/plain"
out=$("$HOOKS/session-start.sh" "$TMP/plain" 2>&1); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] || fail "session-start outside a repository: want silent exit 0"
(cd "$R" && git config core.hooksPath /tmp/none)
touch "$R/.git/config.lock"   # git cannot write its config while this exists
out=$(CLAUDE_PROJECT_DIR="$R" "$HOOKS/session-start.sh" 2>&1); rc=$?
rm -f "$R/.git/config.lock"
[ "$rc" = 0 ] || fail "session-start failed the session when it could not write the config"
[ "$(printf '%s\n' "$out" | wc -l)" = 1 ] && [ -n "$out" ] || fail "session-start: want one line when it fails, got '$out'"
(cd "$R" && git config core.hooksPath .claude/hooks/git)

# ---- session-start.sh says so when the checkout is behind main, or a guard is missing ----
git init -q --bare -b main "$TMP/origin.git"
(cd "$R" && git remote add origin "$TMP/origin.git" && git push -q origin HEAD:main 2>/dev/null && git fetch -q origin)
git clone -q "$TMP/origin.git" "$TMP/ahead" 2>/dev/null
(cd "$TMP/ahead" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "chore: newer" && git push -q origin HEAD:main 2>/dev/null)
out=$("$HOOKS/session-start.sh" "$R" 2>&1); rc=$?
[ "$rc" = 0 ] || fail "session-start failed the session when behind main"
case "$out" in *"1 commits behind origin/main"*) ;; *) fail "session-start: want a warning when behind main, got '$out'" ;; esac
(cd "$R" && git merge -q --ff-only origin/main)
out=$("$HOOKS/session-start.sh" "$R" 2>&1)
[ -z "$out" ] || fail "session-start: want silence once up to date with main, got '$out'"
printf '{"hooks": {"x": "f=.claude/hooks/no_such_guard.py; exec python3 $f"}}\n' > "$R/.claude/settings.json"
out=$("$HOOKS/session-start.sh" "$R" 2>&1)
case "$out" in *"guard missing"*no_such_guard.py*) ;; *) fail "session-start: want a warning for a missing guard, got '$out'" ;; esac
rm -f "$R/.claude/settings.json"
(cd "$R" && git remote remove origin)

# ---- the link check reads what is staged when asked (the pre-commit hook) ----
cp "$REPO/tool/check_instruction_links.sh" "$R/tool/links_real.sh"; cp "$REPO/tool/check_instruction_links.py" "$R/tool/check_instruction_links.py"
printf 'see `docs/z.md`\n' > "$R/CLAUDE.md"; (cd "$R" && git add CLAUDE.md)
printf 'see `docs/no_such.md`\n' > "$R/CLAUDE.md"
"$R/tool/links_real.sh" --staged CLAUDE.md >/dev/null 2>&1 || fail "staged link check read the working tree"
"$R/tool/links_real.sh" CLAUDE.md >/dev/null 2>&1 && fail "working-tree link check missed a bad path"
printf 'see `docs/no_such.md`\n' > "$R/CLAUDE.md"; (cd "$R" && git add CLAUDE.md)
printf 'see `docs/z.md`\n' > "$R/CLAUDE.md"
"$R/tool/links_real.sh" --staged CLAUDE.md >/dev/null 2>&1 && fail "staged link check missed a staged bad path"
(cd "$R" && git reset -q CLAUDE.md && rm -f CLAUDE.md tool/links_real.sh)

# ---- the instruction link check ----
probe="$TMP/probe.md"
printf 'see `backend/no_such_file.py` and `just no-such-recipe`\n' > "$probe"
"$REPO/tool/check_instruction_links.sh" "$probe" >/dev/null && fail "link check passed a missing path and recipe"
printf 'see `backend/justfile`, `just test` and `backend/.env`\n' > "$probe"
"$REPO/tool/check_instruction_links.sh" "$probe" >/dev/null || fail "link check refused real or ignored ones"

if [ $fails -ne 0 ]; then
  echo "gate tests: $fails failure(s)"; exit 1
fi
echo "gate tests: ok"
