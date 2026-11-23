#!/usr/bin/env bash
# Make sure this checkout has a backend/.env, so a fresh worktree can run the
# database commands (`just test`, `just samples`, ...) with no step by hand.
# Does nothing when the file is there. Otherwise writes it from
# backend/.env.example: the local Postgres login, no DJANGO_SETTINGS_MODULE (it
# makes the tests run under dev settings), and a development database named
# after the checkout's folder (or the name given). Each test run builds its own
# database beside it (backend/config/test_database.py).
#
# usage: tool/ensure_env.sh [db_name]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$root/backend/.env"
[ -f "$env_file" ] && [ $# -eq 0 ] && exit 0

if [ $# -gt 0 ]; then
  db="$1"
else
  # letters, digits and _ only; short enough for Postgres to keep a run's process id
  db="mv_$(basename "$root" | tr -c 'A-Za-z0-9_\n' '_' | cut -c1-36)"
fi
if [[ ! "$db" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "ensure_env: the database name may hold only letters, digits and _, got '$db'" >&2
  exit 2
fi
# test_<name>_<process id> is what a test run calls its own database, and Postgres
# cuts a name at 63 characters.
if [[ "$db" == test_* || ${#db} -gt 40 ]]; then
  echo "ensure_env: the database name may not start with test_ or be longer than 40 characters, got '$db'" >&2
  exit 2
fi

if [ ! -f "$env_file" ]; then
  sed -e 's/^DB_USER=.*/DB_USER=postgres/' \
      -e 's/^DB_PASSWORD=.*/DB_PASSWORD=postgres/' \
      "$root/backend/.env.example" > "$env_file"
  echo "ensure_env: wrote backend/.env (development database: $db)" >&2
fi
sed -i -e "s/^DB_NAME=.*/DB_NAME=$db/" -e '/^DJANGO_SETTINGS_MODULE=/d' "$env_file"
