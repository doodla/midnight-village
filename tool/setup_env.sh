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
root="$(git rev-parse --show-toplevel)"

service postgresql start

# backend/.env with this name (and the rules for a name: tool/ensure_env.sh)
"$root/tool/ensure_env.sh" "$db"

# The commit gate is git's own hooks (core.hooksPath, shared by every worktree).
"$root/.claude/hooks/session-start.sh" "$root"

(cd "$root/backend" && just install)
(cd "$root/frontend" && flutter pub get)
