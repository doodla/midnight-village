#!/bin/sh
J=${TLA2TOOLS:-../../statechart-trial/dl-tla/tla2tools.jar}
for n in r_follow v_robber_fix v_minion_fix; do
  s=$(date +%s); timeout 1500 java -XX:+UseParallelGC -cp $J tlc2.TLC -workers 2 -config $n.cfg PhoneNight.tla > $n.out 2>&1
  e=$(date +%s); echo "== $n refined ($((e-s))s): $(grep -E 'violated' $n.out | sort -u | tr '\n' ' ') $(grep -E 'distinct states found' $n.out | tail -1)" >> runs.txt
done
