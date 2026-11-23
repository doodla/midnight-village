#!/usr/bin/env bash
# One command for a fresh cloud container (run as root, once): installs what
# docs/dev/environment.md lists (just, Flutter 3.38.10 in /opt/flutter, both
# linked into /usr/local/bin), starts Postgres and sets its password to
# `postgres`, then runs tool/setup_env.sh for this checkout. Safe to run again:
# it skips what is already there. About three minutes the first time (the
# Flutter download is 1.4 GB).
#
# usage: tool/bootstrap_container.sh [db_name]     (default: midnight_village_dev)
set -euo pipefail
FLUTTER_VERSION="3.38.10"
db="${1:-midnight_village_dev}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PATH="$HOME/.local/bin:$PATH"
command -v just >/dev/null || uv tool install rust-just
ln -sf "$(command -v just)" /usr/local/bin/just

if [ ! -x /opt/flutter/bin/flutter ]; then
  archive="$(mktemp --suffix=.tar.xz)"
  curl -fsSL -o "$archive" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar -xJf "$archive" -C /opt
  rm -f "$archive"
fi
ln -sf /opt/flutter/bin/flutter /opt/flutter/bin/dart /usr/local/bin/
git config --global --add safe.directory /opt/flutter

service postgresql start
su postgres -c "psql -qc \"ALTER USER postgres PASSWORD 'postgres'\""

cd "$root"
tool/setup_env.sh "$db"
echo "Ready: just check, just test, just flutter-test, just screens."
