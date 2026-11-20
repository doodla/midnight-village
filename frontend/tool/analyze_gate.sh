#!/usr/bin/env bash
# `just analyze`: static analysis that fails on every issue, with one
# exception. The old look's libraries are marked @Deprecated('OLD LOOK: ...'),
# so each use of them is reported; a use in a file listed in
# tool/old_look_users.txt (the files that used the old look when it was
# marked, tracked by the removal checklist in docs/dev/old-look-removal.md) is counted
# and shown, not failed. A use anywhere else fails: no new code may take up
# the old look. A listed file that no longer uses it fails too, so the list
# only shrinks: delete its line.
set -euo pipefail
cd "$(dirname "$0")/.."

list=tool/old_look_users.txt
out=$(dart analyze --format=machine . 2>&1 || true)
if ! grep -q '|' <<<"$out" && ! grep -q 'No issues found' <<<"$out"; then
  echo "$out" >&2
  echo "just analyze: the analyzer did not run" >&2
  exit 2
fi

root=$(pwd)
failed=0
tracked=0
declare -A users=()
while IFS='|' read -r severity _type code file line col _len message; do
  [[ -z "$code" ]] && continue
  rel=${file#"$root"/}
  if [[ "$code" == DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE && "$message" == *"OLD LOOK"* ]] &&
    grep -qxF "$rel" "$list"; then
    tracked=$((tracked + 1))
    users[$rel]=1
    continue
  fi
  echo "$severity $code $rel:$line:$col $message"
  failed=1
done < <(grep '|' <<<"$out")

while read -r rel; do
  [[ -z "$rel" || "$rel" == \#* ]] && continue
  if [[ -z "${users[$rel]:-}" ]]; then
    echo "$list: $rel no longer uses the old look; delete its line"
    failed=1
  fi
done <"$list"

echo "Old look: $tracked tracked uses in ${#users[@]} files (tool/old_look_users.txt)."
if [[ $failed -ne 0 ]]; then
  echo "just analyze: issues found (above)" >&2
  exit 1
fi
echo "No other issues found."
