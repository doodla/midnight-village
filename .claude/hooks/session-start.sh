#!/usr/bin/env bash
# SessionStart hook (and tool/setup_env.sh): turns the commit gate on, starts
# Postgres when it is installed and down (it is down after every container restart),
# and clears the build output of finished worktrees (tool/tidy.py).
# Points git at the tracked hooks (`core.hooksPath` = .claude/hooks/git, shared by
# every worktree of the clone) when it points anywhere else, and makes the hook
# files executable. Warns, one line each, when the checkout is behind origin/main
# (its hooks and instructions are old) and when a hook the settings run is missing.
# Silent otherwise, one plain line on failure, and it never fails the session: it
# always exits 0.
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
  # Every hook and guard this session runs, and every instruction it reads first, comes
  # from this checkout: behind main, they are old (it once sat 69 commits behind for four
  # days and nothing said so). Say it loudly; never move it (it may hold someone's work).
  if git -C "$root" rev-parse -q --verify refs/remotes/origin/main >/dev/null; then
    timeout 5 git -C "$root" fetch -q origin main
    behind=$(git -C "$root" rev-list --count HEAD..refs/remotes/origin/main)
    if [ "${behind:-0}" -gt 0 ]; then
      echo "WARNING: $root is $behind commits behind origin/main, so the hooks, guards and instructions of this session are that old. Work in a fresh worktree from origin/main; bring this checkout up to date (git merge --ff-only origin/main) once nothing in it is unfinished."
    fi
  fi
  # A hook the settings name but this checkout lacks would pass in silence: say which.
  if [ -f "$root/.claude/settings.json" ]; then
    for f in $(grep -o '\.claude/[A-Za-z0-9_./-]*\.\(py\|sh\)' "$root/.claude/settings.json" | sort -u); do
      [ -f "$root/$f" ] || echo "WARNING: guard missing: .claude/settings.json runs $f, which $root does not have, so that guard is off."
    done
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
