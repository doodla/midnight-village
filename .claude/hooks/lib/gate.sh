#!/usr/bin/env bash
# Shared by pre-commit-gate.sh and verify-done.sh: which checks a set of paths
# needs, how to run them, and a record of what already passed.
# Sourced, not run. The routing table is tested by .claude/hooks/test_gate_routing.sh.

# Paths outside backend/ and frontend/ that a suite reads. A change to one runs
# that suite even though the file is documentation.
BACKEND_TEST_INPUTS="docs/specs/onuw/recommended-setups.md"   # tests/onuw/test_auto_deck.py

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
      *.md | docs/* | tool/*) ;;
      *) echo backend; echo frontend ;;   # anything else: be safe, run both
    esac
  done | sort -u
}

# gate_inputs <block>: the repo paths whose content decides a block's result.
gate_inputs() {
  case "$1" in
    backend) echo "backend contract_samples $BACKEND_TEST_INPUTS" ;;
    frontend) echo "frontend contract_samples" ;;
    guardrails) echo ".claude" ;;
  esac
}

# gate_hash <block>: a hash of the working tree's content of the block's inputs
# (staged, unstaged and untracked, minus ignored files), so a passed run is
# recorded against exactly what it tested. Records are named <block>-<kind>-<hash>.
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
  echo "$ids" | git hash-object --stdin
}

gate_stamp_dir() { git rev-parse --git-path claude-gate; }

# gate_passed <key>: true if a run with this key already passed here.
gate_passed() { [ -f "$(gate_stamp_dir)/$1" ]; }

gate_record() { mkdir -p "$(gate_stamp_dir)" && touch "$(gate_stamp_dir)/$1"; }

# gate_run_blocks <root> <out_dir> <mode> <block>...: runs each block's commands
# in parallel, each block's steps in order, one log per block in <out_dir>.
# mode "commit": checks and tests; mode "tests": tests only.
# Writes <out_dir>/<block>.status (0 = passed). Every block is cut off after
# GATE_BLOCK_TIMEOUT seconds (default 1500), which counts as a failure.
gate_run_blocks() {
  local root="$1" out="$2" mode="$3" block
  shift 3
  local limit="${GATE_BLOCK_TIMEOUT:-1500}"
  for block in "$@"; do
    (
      cd "$root" || exit 1
      case "$block:$mode" in
        backend:commit) steps="just check && just test" ; dir=backend ;;
        backend:tests) steps="just test" ; dir=backend ;;
        frontend:commit) steps="just analyze && just format-check && just test" ; dir=frontend ;;
        frontend:tests) steps="just test" ; dir=frontend ;;
        guardrails:*) steps="just test-guardrails" ; dir=. ;;
      esac
      cd "$dir" && timeout "$limit" bash -c "$steps" > "$out/$block.log" 2>&1
      echo $? > "$out/$block.status"
    ) &
  done
  wait
}
