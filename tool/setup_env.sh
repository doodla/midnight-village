#!/usr/bin/env bash
# Get a checkout (the main one or an agent's worktree) ready to test:
# Postgres running, backend/.env with this checkout's own database name and no
# DJANGO_SETTINGS_MODULE, git's commit hooks on (.claude/hooks/git), backend and
# frontend dependencies installed.
# Assumes just, uv, Flutter and Postgres are installed (docs/dev/environment.md).
#
# usage: tool/setup_env.sh <db_name>     e.g. tool/setup_env.sh mv_agent_board
set -euo pipefail

db="${1:?usage: tool/setup_env.sh <db_name>}"
if [[ ! "$db" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "setup_env: the database name may hold only letters, digits and _, got '$db'" >&2
  exit 2
fi
root="$(git rev-parse --show-toplevel)"
env_file="$root/backend/.env"

service postgresql start

if [ ! -f "$env_file" ]; then
  sed -e 's/^DB_USER=.*/DB_USER=postgres/' \
      -e 's/^DB_PASSWORD=.*/DB_PASSWORD=postgres/' \
      "$root/backend/.env.example" > "$env_file"
fi
# Every checkout has its own database; DJANGO_SETTINGS_MODULE makes the tests
# run under dev settings, so it never belongs here.
sed -i -e "s/^DB_NAME=.*/DB_NAME=$db/" -e '/^DJANGO_SETTINGS_MODULE=/d' "$env_file"

# The commit gate is git's own hooks (core.hooksPath, shared by every worktree).
"$root/.claude/hooks/session-start.sh" "$root"

(cd "$root/backend" && just install)
(cd "$root/frontend" && flutter pub get)
