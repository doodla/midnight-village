#!/bin/sh
# Runs every configuration of PhoneLobby and checks each ends as recorded:
# every cfg but known_*.cfg holds its rules; each known_*.cfg is a KNOWN gap (README.md) and
# must still break its rule. Exit 1 when any run ends otherwise (a gap closed:
# rename it rule_<name>.cfg; a new break: a finding). TLC logs go to a
# temporary folder; the summary to stdout.
# usage: TLA2TOOLS=/path/to/tla2tools.jar ./runlobby.sh [name...]
J=${TLA2TOOLS:?set TLA2TOOLS to the path of tla2tools.jar}
cd "$(dirname "$0")" || exit 1
out=$(mktemp -d)
names=${*:-"lobby lobby3 late try heal converge known_late"}
bad=0
for n in $names; do
  s=$(date +%s)
  # one worker for a known gap: the same shortest trace every run (as README.md gives it)
  case $n in known_*) w=1 ;; *) w=4 ;; esac
  timeout 3600 java -XX:+UseParallelGC -cp "$J" tlc2.TLC -noGenerateSpecTE -workers $w -metadir "$out/$n.states" \
    -config "$n.cfg" PhoneLobby.tla > "$out/$n.out" 2>&1
  e=$(date +%s)
  # the run's states are gigabytes and never read again: only its log stays
  rm -rf "${out:?}/$n.states"
  broke=$(grep -E 'is violated' "$out/$n.out" | sort -u | tr '\n' ' ')
  states=$(grep 'distinct states found' "$out/$n.out" | tail -1)
  case $n in
    known_*) rule=$(awk '$1 == "INVARIANT" || $1 == "PROPERTY" {print $2}' "$n.cfg")
      grep -Eq "(Invariant|Temporal property) $rule (is|was) violated" "$out/$n.out" && verdict="ok (known gap)" ||
        { verdict="UNEXPECTED: $rule not broken $broke"; bad=1; } ;;
    *) grep -q 'No error has been found' "$out/$n.out" && verdict="ok (holds)" || { verdict="UNEXPECTED: $broke"; bad=1; } ;;
  esac
  echo "== $n ($((e - s))s): $verdict $broke $states"
done
echo "TLC logs: $out"
exit $bad
