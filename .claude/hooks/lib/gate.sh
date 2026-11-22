#!/usr/bin/env bash
# The commit gate's logic, shared by the git hooks in .claude/hooks/git/, the
# Stop hook (.claude/hooks/verify-done.sh) and `just gate-full`
# (.claude/hooks/gate-full.sh): which checks a set of paths needs, how to run
# them, and a record of what already passed. Sourced, not run.
# Tested by .claude/hooks/test_gate_routing.sh.
#
# Two modes. "fast" is the commit gate: format, lint, types, analyze and the
# hook tests, seconds in all. "full" adds the test suites and the extra checks
# GitHub runs; it is `just gate-full`, on demand. GitHub runs everything on a
# pull request and nothing merges on red, so a commit only has to catch the
# embarrassing things.

# Paths outside backend/ and frontend/ that a suite reads. A change to one runs
# that suite even though the file is documentation.
BACKEND_TEST_INPUTS="docs/specs/onuw/recommended-setups.md"   # tests/onuw/test_auto_deck.py

# The functions a hook needs; a hook that sourced this file checks they exist
# (gate_require) and blocks if not, so a broken gate never lets a commit through.
GATE_FUNCTIONS="gate_route gate_staged_paths gate_inputs gate_hash gate_passed gate_block_passed gate_record gate_run_blocks gate_check_commit gate_full"

gate_require() {
  local f
  for f in $GATE_FUNCTIONS; do
    declare -F "$f" >/dev/null || return 1
  done
}

# gate_route: paths on stdin (one per line) -> the blocks they need, one per
# line, sorted: backend, frontend, guardrails. Documentation needs none.
gate_route() {
  local path
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    case " $BACKEND_TEST_INPUTS " in *" $path "*) echo backend; continue ;; esac
    case "$path" in
      contract_samples/*) echo backend; echo frontend ;;
      backend/*.md | frontend/*.md) ;;
      backend/*) echo backend ;;
      frontend/*) echo frontend ;;
      .claude/skills/*) ;;
      .claude/*) echo guardrails ;;
      justfile) echo backend; echo frontend; echo guardrails ;;
      tool/*) echo guardrails ;;           # the link check and its test
      .github/*) echo guardrails ;;        # the workflow test: recipes they call exist
      docs/dev/main-ruleset.json) echo guardrails ;;   # the workflow test: its checks are the jobs
      *.md | docs/*) ;;
      *) echo backend; echo frontend ;;   # anything else: be safe, run both
    esac
  done | sort -u
}

# gate_staged_paths: every path the commit being made changes, as git will
# record it (the index git hands the hook, which is a temporary one for
# `git commit <paths>`). A rename is its old and its new path (--no-renames),
# so moving a file out of backend/ or frontend/ still runs that suite.
gate_staged_paths() {
  git diff --cached --no-renames --name-only 2>/dev/null
}

# gate_inputs <block>: the tracked paths whose content decides a block's result.
gate_inputs() {
  case "$1" in
    backend) echo "backend contract_samples justfile $BACKEND_TEST_INPUTS" ;;
    frontend) echo "frontend contract_samples justfile" ;;
    guardrails) echo ".claude .github justfile tool docs/dev/main-ruleset.json" ;;
  esac
}

# gate_extra <block>: what else a block's result depends on, as text: ignored
# files it reads and the tool versions it runs on.
gate_extra() {
  local flutter_root
  case "$1" in
    backend)
      [ -f backend/.env ] && git hash-object backend/.env
      uv --version 2>/dev/null
      backend/.venv/bin/python --version 2>/dev/null ;;
    frontend)
      flutter_root="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)" 2>/dev/null)")")"
      cat "$flutter_root/bin/cache/flutter.version.json" 2>/dev/null
      cat "$flutter_root/bin/cache/dart-sdk/version" 2>/dev/null ;;
    guardrails)
      python3 --version 2>/dev/null ;;
  esac
}

# gate_hash <block>: a hash of what the block's result depends on: the working
# tree's content of its inputs (staged, unstaged and untracked, minus ignored
# files) plus gate_extra. NOT included: environment variables, the Postgres
# server, system packages, and ignored files other than backend/.env (the
# installed .venv and .dart_tool are covered only through the lockfiles and
# the tool versions). Records are named <block>-<mode>-<hash>.
gate_hash() {
  local block="$1" idx tree p ids=""
  # A fresh index, so every file is hashed: a copied index would trust its
  # cached stat data and miss a same-size edit made within the same second.
  idx="$(mktemp -u)"
  for p in $(gate_inputs "$block"); do
    GIT_INDEX_FILE="$idx" git add -A -- "$p" >/dev/null 2>&1
  done
  tree="$(GIT_INDEX_FILE="$idx" git write-tree 2>/dev/null)"
  rm -f "$idx"
  for p in $(gate_inputs "$block"); do
    ids="$ids $(git rev-parse -q --verify "$tree:$p" 2>/dev/null || echo none)"
  done
  { echo "$ids"; gate_extra "$block"; } | git hash-object --stdin
}

gate_stamp_dir() { git rev-parse --git-path claude-gate; }

# gate_passed <key>: true if a run with this key already passed here.
gate_passed() { [ -f "$(gate_stamp_dir)/$1" ]; }

# gate_block_passed <block> <hash>: the fast checks passed on this content (a
# full run counts: it holds the fast checks too).
gate_block_passed() { gate_passed "$1-fast-$2" || gate_passed "$1-full-$2"; }

# gate_record <key>: remember a pass; records older than 14 days are dropped.
gate_record() {
  local dir; dir="$(gate_stamp_dir)"
  mkdir -p "$dir" && touch "$dir/$1"
  find "$dir" -type f -mtime +14 -delete 2>/dev/null
  return 0
}

# gate_run_blocks <root> <out_dir> <mode> <block>...: runs each block once, in
# parallel, each block's steps in order, one log per block in <out_dir>, and
# writes <out_dir>/<block>.status (0 = passed) and <block>.secs. Nothing is retried.
# mode "fast": the commit gate (seconds). mode "full": the suites and the extra
# checks too (minutes).
# A block is stopped after GATE_BLOCK_TIMEOUT seconds (default 100 for fast, 1500
# for full; killed 30 s later if it ignores that), which counts as a failure.
# Steps run without the GIT_* variables git sets for hooks, so a test that makes
# its own repository cannot write into this one.
gate_run_blocks() {
  local root="$1" out="$2" mode="$3" block
  shift 3
  local limit="${GATE_BLOCK_TIMEOUT:-100}"
  [ "$mode" = full ] && limit="${GATE_BLOCK_TIMEOUT:-1500}"
  for block in "$@"; do
    (
      local steps dir started=$SECONDS
      case "$block:$mode" in
        backend:fast) steps="just check" ; dir=backend ;;
        backend:full) steps="just check && just test" ; dir=backend ;;
        frontend:fast) steps="just analyze && just format-check" ; dir=frontend ;;
        # the extras are what GitHub also runs without a browser or a backend:
        # generated code current, every screen clean at 360 and 390 wide
        frontend:full) steps="just analyze && just format-check && just test && just gen-check && just screens 360 strict && just screens 390 strict" ; dir=frontend ;;
        guardrails:*) steps="just test-guardrails" ; dir=. ;;
        *) echo 1 > "$out/$block.status"; exit 0 ;;
      esac
      cd "$root/$dir" || { echo 1 > "$out/$block.status"; exit 0; }
      env -u GIT_DIR -u GIT_INDEX_FILE -u GIT_WORK_TREE -u GIT_PREFIX \
        timeout -k 30 "$limit" bash -c "$steps" > "$out/$block.log" 2>&1
      echo $? > "$out/$block.status"
      echo $((SECONDS - started)) > "$out/$block.secs"
    ) &
  done
  wait
}

# gate_check_commit: everything the git pre-commit hook checks, on the commit
# git is about to make. Prints why it blocks; returns non-zero to block.
gate_check_commit() {
  local root failed=0 block hash status out
  root="$(git rev-parse --show-toplevel)" || return 1
  cd "$root" || return 1

  if ! out=$(tool/check_instruction_links.sh --staged 2>&1); then
    echo "BLOCKED: an instruction file names a path or recipe that does not exist." >&2
    echo "$out" | tail -20 >&2
    failed=1
  fi

  local -a to_run=()
  local -A key_fast=()
  for block in $(gate_staged_paths | gate_route); do
    hash=$(gate_hash "$block")
    key_fast[$block]="$block-fast-$hash"
    if gate_block_passed "$block" "$hash"; then
      echo "gate: $block already passed on this content" >&2
    else
      to_run+=("$block")
    fi
  done

  if [ ${#to_run[@]} -gt 0 ]; then
    out=$(mktemp -d)
    echo "gate: checking ${to_run[*]} (seconds; GitHub runs the full suites on the pull request)" >&2
    gate_run_blocks "$root" "$out" fast "${to_run[@]}"
    for block in "${to_run[@]}"; do
      status=$(cat "$out/$block.status" 2>/dev/null || echo 1)
      if [ "$status" = "0" ]; then
        gate_record "${key_fast[$block]}"
      else
        [ "$status" = "124" ] || [ "$status" = "137" ] && echo "BLOCKED: $block checks ran out of time." >&2
        echo "BLOCKED: $block checks are failing. Fix them before committing." >&2
        echo "" >&2
        tail -25 "$out/$block.log" >&2
        failed=1
      fi
    done
    rm -rf "$out"
  fi
  return $failed
}

# gate_full [block...]: the whole local suite, on demand (`just gate-full`): the
# link check, then every block (all three unless named) in full mode, in
# parallel. Prints what ran, with times; returns non-zero if anything failed. A
# pass is recorded, so a commit on the same content skips its fast checks.
gate_full() {
  local root failed=0 block hash status out
  root="$(git rev-parse --show-toplevel)" || return 1
  cd "$root" || return 1
  local -a blocks=("$@")
  [ ${#blocks[@]} -eq 0 ] && blocks=(backend frontend guardrails)
  for block in "${blocks[@]}"; do
    case "$block" in
      backend | frontend | guardrails) ;;
      *) echo "gate-full: unknown block '$block' (backend, frontend, guardrails)" >&2; return 2 ;;
    esac
  done
  if out=$(tool/check_instruction_links.sh 2>&1); then
    echo "ok   links"
  else
    echo "FAIL links"; echo "$out" | tail -20; failed=1
  fi
  out=$(mktemp -d)
  echo "gate-full: ${blocks[*]} in parallel (minutes)" >&2
  gate_run_blocks "$root" "$out" full "${blocks[@]}"
  for block in "${blocks[@]}"; do
    status=$(cat "$out/$block.status" 2>/dev/null || echo 1)
    if [ "$status" = "0" ]; then
      hash=$(gate_hash "$block")
      gate_record "$block-fast-$hash"
      gate_record "$block-full-$hash"
      echo "ok   $block ($(cat "$out/$block.secs" 2>/dev/null || echo ?) s)"
    else
      echo "FAIL $block ($(cat "$out/$block.secs" 2>/dev/null || echo ?) s)"
      tail -25 "$out/$block.log"
      failed=1
    fi
  done
  rm -rf "$out"
  return $failed
}
