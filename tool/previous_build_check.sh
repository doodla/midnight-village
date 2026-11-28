#!/usr/bin/env bash
# The live server migrates the database while the PREVIOUS build still serves.
# This runs that build's own tests against a database built by THIS change's
# migrations: the previous code (its models, views, services) on the new schema.
# A migration that would break the serving build fails here, before it merges.
#
# Does nothing when the change has no migration. The previous build is the main
# this change was built on (tool/change_base.py), or the ref given.
#
# usage: tool/previous_build_check.sh [<previous ref>] [-- <pytest arguments>]
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
previous=""
if [ $# -gt 0 ] && [ "$1" != "--" ]; then previous="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
# The build that is serving when this one goes live: the main this change was built on.
[ -n "$previous" ] || previous="$("$root/tool/change_base.py")"
if [ -z "$previous" ]; then
  echo "previous-build check: no main to compare with; nothing checked."
  exit 0
fi

changed="$( { git -C "$root" diff --name-only "$previous" -- 'backend/apps/*/migrations/*.py';
              git -C "$root" ls-files --others --exclude-standard -- 'backend/apps/*/migrations/*.py'; } | sort -u)"
if [ -z "$changed" ]; then
  echo "previous-build check: no migration in this change, nothing to do."
  exit 0
fi
echo "previous-build check: migrations in this change:"
echo "$changed" | sed 's/^/  /'

work="$(mktemp -d)"
trap 'cd "$root"; git -C "$root" worktree remove --force "$work/previous" >/dev/null 2>&1 || true; rm -rf "$work"' EXIT
git -C "$root" worktree add -q --detach "$work/previous" "$previous"

# The previous build's code, this change's migrations.
for app in "$root"/backend/apps/*/; do
  name="$(basename "$app")"
  [ -d "$app/migrations" ] || continue
  # An app this change adds: the previous build does not install it, so it
  # never reads or writes its tables (the live build's own `migrate` makes
  # them). Nothing of it to put in the previous build.
  if [ ! -d "$work/previous/backend/apps/$name" ]; then
    echo "previous-build check: apps/$name is new in this change; the previous build does not install it."
    continue
  fi
  rm -rf "$work/previous/backend/apps/$name/migrations"
  cp -r "$app/migrations" "$work/previous/backend/apps/$name/migrations"
done
[ -f "$root/backend/.env" ] && cp "$root/backend/.env" "$work/previous/backend/.env"

cd "$work/previous/backend"
[ -x ../tool/ensure_env.sh ] && ../tool/ensure_env.sh
parallel=()
uv run python -c "import xdist" 2>/dev/null && parallel=(-n auto)
echo "previous-build check: $(git -C "$work/previous" log --oneline -1) on this change's schema"
# The migration tests and the check that migrations match the models are about a
# build's own migrations: here the two are from different builds on purpose.
if uv run pytest "${parallel[@]}" --migrations --create-db --no-cov -q -p no:cacheprovider \
     -m "not migration" "$@"; then
  echo "previous-build check: the previous build works on the migrated database."
else
  echo "previous-build check: the previous build FAILS on the database this change leaves." >&2
  echo "It serves while the migration runs: make the change in two pushes" >&2
  echo "(docs/dev/deploy-vercel.md, \"Deploy-safe changes\")." >&2
  exit 1
fi
