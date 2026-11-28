| moment | s | frames | >16 ms | >50 ms | worst ms | long tasks | LT ms | content ms | tap: first change ms | tap: final ms | tap: server ms | before the server? |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| transition first screen by a link (join) | 28.79 | 358 | 49 | 48 | 2958.2 | 50 | 11954 | 10277 |  |  |  |  |
| screen join screen | 3.02 | 6 | 6 | 6 | 215.5 | 6 | 1134 |  |  |  |  |  |
| tap Join (by link) -> 02 | 26.95 | 57 | 57 | 57 | 445.1 | 57 | 10918 |  | 331 | 998 | - | no request |
| screen 02 table as a guest | 3.0 | 6 | 6 | 6 | 195.2 | 6 | 1067 |  |  |  |  |  |
| transition first screen 01 (cold) | 28.87 | 363 | 47 | 47 | 3262.2 | 49 | 13716 | 11283 |  |  |  |  |
| screen 01 first screen | 3.0 | 6 | 6 | 6 | 261.7 | 6 | 1363 |  |  |  |  |  |
| tap Start a table -> 02 | 5.51 | 13 | 13 | 13 | 876.1 | 15 | 4943 |  | 354 | 3854 | 770 | True |
| screen 02 table, alone | 3.01 | 0 | 0 | 0 | 0 | 0 | 0 |  |  |  |  |  |
| transition 02 Bea joins (socket) | 30.14 | 2 | 2 | 2 | 545.5 | 2 | 874 | 613 |  |  |  |  |
| transition 02 Cal joins (socket) | 1.23 | 2 | 2 | 2 | 706.2 | 2 | 1132 | 1226 |  |  |  |  |
| transition 02 Dan joins (socket) | 30.21 | 2 | 2 | 2 | 612.2 | 2 | 1032 | 688 |  |  |  |  |
| screen 02 table, four seated | 3.01 | 0 | 0 | 0 | 0 | 0 | 0 |  |  |  |  |  |
| tap Edit -> 03 set-up | 4.94 | 6 | 6 | 6 | 1379 | 6 | 4680 |  | 4745 | 4745 | 4911 | True |
| screen 03 set-up | 3.01 | 0 | 0 | 0 | 0 | 0 | 0 |  |  |  |  |  |
| tap 03 add a Minion | 1.75 | 2 | 2 | 2 | 1006.9 | 2 | 1605 |  | 1141 | 1141 | 301 | False |
| tap 03 take it out | 1.0 | 1 | 1 | 1 | 894.7 | 1 | 889 |  | 1003 | 1003 | 271 | False |
| tap Done -> 02 | 3.53 | 6 | 6 | 6 | 1000.7 | 6 | 3322 |  | 575 | 3375 | - | no request |
| tap g1 Drunk: Start the game -> deal -> 04 | 6.94 | 11 | 11 | 11 | 1034 | 11 | 6675 |  | 536 | 5469 | 1208 | True |
| screen g1 Drunk: 04 your card | 3.59 | 5 | 5 | 5 | 775.2 | 5 | 3062 |  |  |  |  |  |
| tap g1 Drunk: 04 hold the card | 5.55 | 10 | 10 | 10 | 899 | 10 | 5462 |  | 859 | 5109 | - | no request |
| tap g1 Drunk: 04 Ready | 3.27 | 6 | 6 | 6 | 1172 | 6 | 3175 |  | 486 | 1653 | 1176 | True |
| transition g1 Drunk: 04 -> night (others ready) | 3.87 | 5 | 5 | 5 | 955.1 | 5 | 3577 | 3334 |  |  |  |  |
| screen g1 Drunk: night Drunk | 2.51 | 3 | 3 | 3 | 606.2 | 3 | 1574 |  |  |  |  |  |
| tap g1 Drunk: night pick Left | 2.57 | 4 | 4 | 4 | 1347.6 | 4 | 2528 |  | 1203 | 1986 | - | no request |
| tap g1 Drunk: night Swap | 7.0 | 11 | 11 | 11 | 1424.5 | 11 | 6447 |  | 648 | 6232 | 1499 | True |
| transition g1 Drunk: night -> talk (window closes) | 30.14 | 30 | 30 | 30 | 398.8 | 30 | 9980 | - |  |  |  |  |
| screen g1 Drunk: 08 talk | 4.01 | 4 | 4 | 4 | 398.8 | 4 | 1412 |  |  |  |  |  |
| tap g1 Drunk: 08 hold My night | 1.84 | 3 | 3 | 3 | 583.3 | 3 | 1311 |  | 598 | 1065 | - | no request |
| tap g1 Drunk: 08 Ready to vote | 3.37 | 8 | 8 | 8 | 1025.2 | 8 | 2712 |  | 351 | 1384 | 814 | True |
| transition g1 Drunk: 08 -> 09 vote (others ready) | 2.65 | 6 | 6 | 6 | 464.7 | 6 | 2229 | 1905 |  |  |  |  |
| screen g1 Drunk: 09 vote | 3.01 | 3 | 3 | 3 | 342.6 | 3 | 948 |  |  |  |  |  |
| tap g1 Drunk: 09 pick Bea | 2.8 | 6 | 6 | 6 | 440.8 | 6 | 2230 |  | 682 | 1499 | 861 | True |
| tap g1 Drunk: 09 Lock in | 2.62 | 6 | 6 | 6 | 728.6 | 6 | 2327 |  | 447 | 1564 | 907 | True |
| transition g1 Drunk: 09 -> end board reveal | 2.39 | 6 | 6 | 6 | 564.1 | 6 | 2049 | 1810 |  |  |  |  |
| screen g1 Drunk: 12 end board | 3.01 | 6 | 6 | 6 | 594.7 | 6 | 2637 |  |  |  |  |  |
| tap g1 Drunk: Play again -> 02 | 5.14 | 11 | 11 | 11 | 1131.6 | 11 | 4732 |  | 384 | 4268 | 916 | True |
| screen g1 Drunk: 02 table again | 2.01 | 0 | 0 | 0 | 0 | 0 | 0 |  |  |  |  |  |
