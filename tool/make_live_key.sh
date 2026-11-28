#!/usr/bin/env bash
# Makes the key the release job pushes the live branches with (docs/dev/rulesets/README.md).
# Prints two blocks: the first goes into GitHub's Deploy keys, the second into the secret
# LIVE_DEPLOY_KEY of the environment `live`. Both files are deleted when it ends: no copy
# stays on this computer (a lost key is replaced by running this again).
set -euo pipefail

if ! command -v ssh-keygen >/dev/null; then
  echo "This computer has no ssh-keygen. On a Mac it is built in; on Windows, run this in Git Bash." >&2
  exit 1
fi
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
ssh-keygen -q -t ed25519 -N "" -C "midnight-village release job" -f "$dir/key"

echo "===== Block 1: Settings, Deploy keys, Add deploy key (tick \"Allow write access\") ====="
cat "$dir/key.pub"
echo
echo "===== Block 2: Settings, Environments, live, secret LIVE_DEPLOY_KEY (all of it) ====="
cat "$dir/key"
echo
echo "Done. Both copies are deleted now."
