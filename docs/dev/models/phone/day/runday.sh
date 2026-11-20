#!/bin/sh
J=${TLA2TOOLS:-../../statechart-trial/dl-tla/tla2tools.jar}
for n in day_screen day_fix; do s=$(date +%s); timeout 2400 java -XX:+UseParallelGC -cp $J tlc2.TLC -workers 3 -config $n.cfg PhoneDay.tla > $n.out 2>&1; e=$(date +%s)
echo "== $n ($((e-s))s): $(grep -E 'violated|No error' $n.out | sort -u | tr '\n' ' ') $(grep 'distinct states found' $n.out | tail -1)" >> runs.txt; done
