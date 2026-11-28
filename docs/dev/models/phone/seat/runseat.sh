#!/bin/sh
# Runs every configuration of PhoneSeat and checks each ends as recorded
# (README.md): seat.cfg is the phone of today and holds every rule; each run
# in BREAKS keeps a finding (a fix switched off) and must still break its
# rule. Exit 1 when any run ends otherwise. TLC logs go to a temporary
# folder; the summary to stdout.
# usage: TLA2TOOLS=/path/to/tla2tools.jar ./runseat.sh [name...]
J=${TLA2TOOLS:?set TLA2TOOLS to the path of tla2tools.jar}
cd "$(dirname "$0")" || exit 1
out=$(mktemp -d)
# zombie: a socket that dies open, with no beat, strands the seat (seat_beat: with it)
BREAKS="late stale noup leave today seat_drop zombie"
names=${*:-"seat seat_before seat_beat seat_drop zombie late stale noup leave today"}
bad=0
for n in $names; do
  s=$(date +%s)
  # one worker: the same shortest trace every run (as README.md gives it)
  timeout 1800 java -XX:+UseParallelGC -cp "$J" tlc2.TLC -noGenerateSpecTE -workers 1 -metadir "$out/$n.states" \
    -config "$n.cfg" PhoneSeat.tla > "$out/$n.out" 2>&1
  e=$(date +%s)
  broke=$(grep -E 'is violated|was violated' "$out/$n.out" | sort -u | tr '\n' ' ')
  states=$(grep 'distinct states found' "$out/$n.out" | tail -1)
  case " $BREAKS " in
    *" $n "*) [ -n "$broke" ] && verdict="ok (breaks, as recorded)" || { verdict="UNEXPECTED: nothing broke"; bad=1; } ;;
    *) grep -q 'No error has been found' "$out/$n.out" && verdict="ok (holds)" || { verdict="UNEXPECTED: $broke"; bad=1; } ;;
  esac
  echo "== $n ($((e - s))s): $verdict $broke $states"
done
echo "TLC logs: $out"
exit $bad
