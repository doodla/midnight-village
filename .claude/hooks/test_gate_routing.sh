#!/usr/bin/env bash
# Tests the commit gate's routing (which suites a set of staged paths runs),
# its commit-subject check and its "already passed on this content" record.
# Run by `just test-guardrails`.
set -uo pipefail
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/gate.sh
source "$HOOKS/lib/gate.sh"
fails=0

route() { printf '%s\n' "$@" | gate_route | tr '\n' ' ' | sed 's/ $//'; }

expect_route() {  # expect_route "<blocks>" path...
  local want="$1"; shift
  local got; got="$(route "$@")"
  if [ "$got" != "$want" ]; then
    echo "FAIL route [$*]: want '$want', got '$got'"; fails=$((fails + 1))
  fi
}

# staged paths                                          -> blocks
expect_route ""                         docs/dev/status.md
expect_route ""                         CLAUDE.md backend/CLAUDE.md frontend/CLAUDE.md
expect_route ""                         backend/apps/onuw/README.md frontend/test/README.md
expect_route ""                         docs/dev/models/phone/night/PhoneNight.tla docs/design/mocks/01-join.png
expect_route ""                         .claude/skills/flutter-testing-apps/SKILL.md
expect_route ""                         tool/setup_env.sh
expect_route "backend"                  backend/apps/onuw/services.py
expect_route "backend"                  backend/pyproject.toml backend/uv.lock
expect_route "backend"                  docs/specs/onuw/recommended-setups.md
expect_route "frontend"                 frontend/lib/main.dart
expect_route "frontend"                 frontend/pubspec.yaml frontend/CLAUDE.md
expect_route "backend frontend"         contract_samples/index.json
expect_route "backend frontend"         backend/apps/core/views.py frontend/lib/main.dart
expect_route "guardrails"               .claude/settings.json
expect_route "guardrails"               .claude/agents/frontend-code-reviewer.md
expect_route "guardrails"               .claude/hooks/pre-commit-gate.sh
expect_route "guardrails"               .claude/guardrails/rules/subagent_model_effort.py
expect_route "backend frontend guardrails" justfile
expect_route "backend frontend"         .github/workflows/flutter-tests.yml
expect_route "backend frontend"         .pre-commit-config.yaml
expect_route "backend frontend guardrails" docs/README.md contract_samples/a.json .claude/settings.json

# commit subjects
expect_msg() {  # expect_msg <0|1> <command>
  local want="$1" cmd="$2" got
  echo "$cmd" | python3 "$HOOKS/lib/commit_msg.py" >/dev/null; got=$?
  if [ "$got" != "$want" ]; then
    echo "FAIL subject [$cmd]: want exit $want, got $got"; fails=$((fails + 1))
  fi
}
expect_msg 0 'git commit -m "docs(dev): status only"'
expect_msg 0 "git commit -m 'chore(claude): route the gate'"
expect_msg 0 'git add a && git commit -m "fix: no scope"'
expect_msg 0 'git commit -am "test(onuw): x"'
expect_msg 0 'git commit --amend --no-edit'
expect_msg 0 'git commit'
expect_msg 0 'git commit -m "Merge branch '"'"'x'"'"'"'
expect_msg 0 "git commit -m \"\$(cat <<'EOF'
feat(frontend): a board

Body line.
EOF
)\""
expect_msg 0 "git commit -q -m \"\$(cat <<'EOF'
docs(x): quotes \"inside\" the body

A \"quoted\" line.
EOF
)\""
expect_msg 1 "git commit -m \"\$(cat <<'EOF'
Docs: quotes \"inside\"
EOF
)\""
expect_msg 1 'git commit -m "update stuff"'
expect_msg 1 'git commit -m "feature(x): wrong type"'
expect_msg 1 'git commit -m "fix(x):missing space"'
expect_msg 1 "git commit -m \"\$(cat <<'EOF'
Added things

EOF
)\""

# the record of a passed run follows the content, not the commit
tmp=$(mktemp -d)
(
  cd "$tmp" && git init -q && mkdir -p backend frontend contract_samples \
    && echo a > backend/x.py && echo b > frontend/y.dart && git add -A \
    && git -c user.email=t@t -c user.name=t commit -qm init
) || { echo "FAIL could not make a temp repo"; exit 1; }
hash_of() { (cd "$tmp" && gate_hash "$1"); }
h1=$(hash_of backend); f1=$(hash_of frontend)
echo c > "$tmp/frontend/y.dart"
[ "$(hash_of backend)" = "$h1" ] || { echo "FAIL backend hash moved on a frontend edit"; fails=$((fails + 1)); }
[ "$(hash_of frontend)" != "$f1" ] || { echo "FAIL frontend hash ignored an unstaged edit"; fails=$((fails + 1)); }
echo n > "$tmp/backend/new.py"
[ "$(hash_of backend)" != "$h1" ] || { echo "FAIL backend hash ignored an untracked file"; fails=$((fails + 1)); }
rm "$tmp/backend/new.py"
[ "$(hash_of backend)" = "$h1" ] || { echo "FAIL backend hash not back after the undo"; fails=$((fails + 1)); }
(cd "$tmp" && gate_record "backend-tests-$h1" && gate_passed "backend-tests-$h1") \
  || { echo "FAIL record not found"; fails=$((fails + 1)); }
(cd "$tmp" && ! gate_passed "frontend-tests-$f1") || { echo "FAIL unrecorded run found"; fails=$((fails + 1)); }
rm -rf "$tmp"

# the instruction link check fails on a missing path or recipe
probe=$(mktemp --suffix=.md)
printf 'see `backend/no_such_file.py` and `just no-such-recipe`\n' > "$probe"
if "$HOOKS/../../tool/check_instruction_links.sh" "$probe" >/dev/null; then
  echo "FAIL link check passed a missing path and recipe"; fails=$((fails + 1))
fi
printf 'see `backend/justfile` and `just test`\n' > "$probe"
"$HOOKS/../../tool/check_instruction_links.sh" "$probe" >/dev/null \
  || { echo "FAIL link check refused real ones"; fails=$((fails + 1)); }
rm -f "$probe"

if [ $fails -ne 0 ]; then
  echo "gate routing: $fails failure(s)"; exit 1
fi
echo "gate routing: ok"
