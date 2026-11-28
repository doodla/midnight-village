#!/bin/sh
# Runs every configuration of PhoneDay and checks each ends as recorded
# (../README.md): a run named in BREAKS must still break its rule (the finding
# it records, or a gap not closed yet); every other run must hold. Exit 1 when
# any ends otherwise. TLC logs go to a temporary folder; the summary to stdout.
# usage: TLA2TOOLS=/path/to/tla2tools.jar ./runday.sh [name...]
J=${TLA2TOOLS:?set TLA2TOOLS to the path of tla2tools.jar}
cd "$(dirname "$0")" || exit 1
out=$(mktemp -d)
# day_outcome: F5 (OutcomeLoads). day_screen: F6 (ScreenConverges). Both fixed in the app
# (FIX_HEAL); the runs keep the finding. day_late: #16 until the phone sends `asked`.
# day_zombie: a socket that dies open strands the screen without the beat (day_beat: with it).
BREAKS="day_outcome day_screen day_late day_zombie"
names=${*:-"day_fix day_asked day_askless day_askless_order day_beat day_zombie day_outcome day_screen day_late"}
bad=0
for n in $names; do
  s=$(date +%s)
  # one worker for a run that breaks: the same shortest trace every time
  case " $BREAKS " in *" $n "*) w=1 ;; *) w=3 ;; esac
  timeout 2400 java -XX:+UseParallelGC -cp "$J" tlc2.TLC -noGenerateSpecTE -workers $w -metadir "$out/$n.states" \
    -config "$n.cfg" PhoneDay.tla > "$out/$n.out" 2>&1
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
