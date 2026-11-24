#!/usr/bin/env bash
# SessionStart hook (and tool/setup_env.sh): turns the commit gate on, starts
# Postgres when it is installed and down (it is down after every container restart),
# and clears the build output of finished worktrees (tool/tidy.py).
# Points git at the tracked hooks (`core.hooksPath` = .claude/hooks/git, shared by
# every worktree of the clone) when it points anywhere else, and makes the hook
# files executable. Silent on success, one plain line on failure, and it never
# fails the session: it always exits 0.
# usage: .claude/hooks/session-start.sh [checkout]   (default: $CLAUDE_PROJECT_DIR, else here)
dir="${1:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
want=".claude/hooks/git"
{
  root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0  # not a git checkout
  [ -d "$root/$want" ] || exit 0  # a checkout from before the git hooks
  chmod +x "$root/$want"/* "$root/.claude/hooks/"*.sh 2>/dev/null
  if [ "$(git -C "$root" config --get core.hooksPath 2>/dev/null)" != "$want" ]; then
    git -C "$root" config core.hooksPath "$want" 2>/dev/null \
      || echo "Could not turn on the commit gate: run 'git config core.hooksPath $want' in $root."
  fi
  if command -v pg_isready >/dev/null && command -v service >/dev/null && ! pg_isready -q; then
    service postgresql start >/dev/null || true
  fi
  # Worktrees gone quiet (no source change for hours, no process in them) lose their build
  # output, about a gigabyte each: in the background, so the session does not wait for it.
  if [ -x "$root/tool/tidy.py" ]; then
    (cd "$root" && tool/tidy.py --quiet >/dev/null 2>&1 &)
  fi
} 2>/dev/null
exit 0
