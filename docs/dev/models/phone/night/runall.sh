#!/bin/sh
# Re-runs every configuration of PhoneNight; summary in runs.txt
J=${TLA2TOOLS:-../../statechart-trial/dl-tla/tla2tools.jar}
B='SENDS_CHOSEN = TRUE FIXED_SERVER = TRUE ANSWER_CARRIES = FALSE MaxFaults = 2 MaxRestarts = 1 MaxTaps = 3'
INV='INVARIANT StoredAsIntended OnePerTurn NoChosenForUnusedTurn'
run(){ name=$1; printf 'SPECIFICATION Spec\nCONSTANTS %s\n%s\n' "$2" "$3" > $name.cfg
  s=$(date +%s); timeout 900 java -XX:+UseParallelGC -cp $J tlc2.TLC -workers 4 -config $name.cfg PhoneNight.tla > $name.out 2>&1
  e=$(date +%s); echo "== $name ($((e-s))s): $(grep -E 'violated' $name.out | sort -u | tr '\n' ' ') $(grep -E 'distinct states found' $name.out | tail -1)" >> runs.txt; }
: > runs.txt
run v_robber_fix   "ROLE = \"dopp\" COPY = \"Robber\" FIX_RETRY = TRUE FIX_TURN = FALSE $B" "$INV
PROPERTY FollowUpArmed ChosenNotForever Converges"
run v_minion       "ROLE = \"dopp\" COPY = \"Minion\" FIX_RETRY = FALSE FIX_TURN = FALSE $B" "INVARIANT NoChosenForUnusedTurn"
run v_minion_fix   "ROLE = \"dopp\" COPY = \"Minion\" FIX_RETRY = TRUE FIX_TURN = TRUE $B" "$INV
PROPERTY FollowUpArmed ChosenNotForever Converges"
run v_villager     "ROLE = \"dopp\" COPY = \"Villager\" FIX_RETRY = FALSE FIX_TURN = FALSE $B" "$INV
PROPERTY ChosenNotForever Converges"
run v_actor        "ROLE = \"actor\" COPY = \"Villager\" FIX_RETRY = FALSE FIX_TURN = FALSE $B" "$INV
PROPERTY ChosenNotForever Converges"
run v_sleeper      "ROLE = \"sleeper\" COPY = \"Villager\" FIX_RETRY = FALSE FIX_TURN = FALSE $B" "$INV
PROPERTY ChosenNotForever Converges"
run v_oldserver    "ROLE = \"dopp\" COPY = \"Robber\" FIX_RETRY = FALSE FIX_TURN = FALSE SENDS_CHOSEN = FALSE FIXED_SERVER = FALSE ANSWER_CARRIES = FALSE MaxFaults = 2 MaxRestarts = 1 MaxTaps = 3" "INVARIANT StoredAsIntended OnePerTurn"
