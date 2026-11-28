| moment | s | frames | >16 ms | >50 ms | worst ms | long tasks | LT ms | content ms | tap: first change ms | tap: final ms | tap: server ms | before the server? |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| transition first screen by a link (join) | 28.5 | 360 | 48 | 48 | 2602.3 | 50 | 11126 | 10135 |  |  |  |  |
| screen join screen | 3.01 | 6 | 6 | 6 | 206.6 | 6 | 1108 |  |  |  |  |  |
| tap Join (by link) -> 02 | 27.15 | 58 | 58 | 58 | 874.3 | 58 | 10397 |  | 297 | 913 | - | no request |
| screen 02 table as a guest | 3.01 | 6 | 6 | 6 | 208.9 | 6 | 1115 |  |  |  |  |  |
| transition first screen 01 (cold) | 28.88 | 366 | 48 | 48 | 3180.1 | 49 | 13368 | 11212 |  |  |  |  |
| screen 01 first screen | 3.01 | 6 | 6 | 6 | 238.5 | 6 | 1307 |  |  |  |  |  |
| tap Start a table -> 02 | 5.65 | 14 | 14 | 14 | 1059.6 | 15 | 5043 |  | 423 | 3807 | 851 | True |
| screen 02 table, alone | 3.0 | 0 | 0 | 0 | 0 | 0 | 0 |  |  |  |  |  |
| transition 02 Bea joins (socket) | 30.14 | 2 | 2 | 2 | 571.8 | 2 | 945 | 632 |  |  |  |  |
| transition 02 Cal joins (socket) | 1.5 | 3 | 3 | 3 | 577.8 | 3 | 1295 | 1008 |  |  |  |  |
| transition 02 Dan joins (socket) | 30.3 | 2 | 2 | 2 | 699.8 | 2 | 1181 | 754 |  |  |  |  |
| screen 02 table, four seated | 3.01 | 0 | 0 | 0 | 0 | 0 | 0 |  |  |  |  |  |
| tap Edit -> 03 set-up | 4.29 | 6 | 6 | 6 | 1392.7 | 6 | 4187 |  | 4244 | 4244 | - | no request |
| screen 03 set-up | 3.01 | 0 | 0 | 0 | 0 | 0 | 0 |  |  |  |  |  |
| tap 03 add a Minion | 2.08 | 3 | 3 | 3 | 1245.4 | 3 | 1925 |  | 892 | 892 | 293 | False |
| tap 03 take it out | 1.56 | 2 | 2 | 2 | 743.9 | 2 | 1428 |  | 795 | 795 | 265 | False |
| tap Done -> 02 | 3.65 | 6 | 6 | 6 | 1990.1 | 6 | 3441 |  | 507 | 3491 | - | no request |
| tap g1 Drunk: Start the game -> deal -> 04 | 6.38 | 11 | 11 | 11 | 1018.5 | 11 | 6096 |  | 516 | 5066 | 1115 | True |
| screen g1 Drunk: 04 your card | 3.11 | 5 | 5 | 5 | 664.3 | 5 | 3095 |  |  |  |  |  |
| tap g1 Drunk: 04 hold the card | 5.99 | 12 | 12 | 12 | 1068.7 | 12 | 5909 |  | 1171 | 5504 | - | no request |
| tap g1 Drunk: 04 Ready | 2.17 | 4 | 4 | 4 | 1186 | 4 | 2112 |  | 516 | 1716 | 1229 | True |
| transition g1 Drunk: 04 -> night (others ready) | 4.09 | 6 | 6 | 6 | 790.8 | 6 | 3961 | 3075 |  |  |  |  |
| screen g1 Drunk: night Drunk | 2.51 | 3 | 3 | 3 | 499.3 | 3 | 1420 |  |  |  |  |  |
| tap g1 Drunk: night pick Left | 2.39 | 4 | 4 | 4 | 1188.3 | 4 | 2336 |  | 1063 | 2396 | - | no request |
| tap g1 Drunk: night Swap | 3.12 | 5 | 5 | 5 | 1942.4 | 5 | 3067 |  | 1237 | 2570 | 2016 | True |
| transition g1 Drunk: night -> talk (window closes) | 30.06 | 32 | 32 | 32 | 398.9 | 32 | 10528 | 1044 |  |  |  |  |
| screen g1 Drunk: 08 talk | 4.01 | 4 | 4 | 4 | 387.2 | 4 | 1345 |  |  |  |  |  |
| tap g1 Drunk: 08 hold My night | 2.23 | 4 | 4 | 4 | 510.3 | 4 | 1471 |  | 532 | 932 | - | no request |
| tap g1 Drunk: 08 Ready to vote | 2.45 | 6 | 6 | 6 | 676.4 | 6 | 1960 |  | 355 | 1355 | 816 | True |
| transition g1 Drunk: 08 -> 09 vote (others ready) | 2.19 | 5 | 5 | 5 | 524.1 | 5 | 1968 | 1461 |  |  |  |  |
| screen g1 Drunk: 09 vote | 3.01 | 3 | 3 | 3 | 332.1 | 3 | 926 |  |  |  |  |  |
| tap g1 Drunk: 09 pick Bea | 2.08 | 5 | 5 | 5 | 1024.8 | 5 | 1713 |  | 659 | 1409 | 834 | True |
| tap g1 Drunk: 09 Lock in | 2.49 | 6 | 6 | 6 | 677.8 | 6 | 2102 |  | 399 | 1416 | 851 | True |
| transition g1 Drunk: 09 -> end board reveal | 3.08 | 6 | 6 | 6 | 785.7 | 6 | 2913 | 2502 |  |  |  |  |
| screen g1 Drunk: 12 end board | 3.01 | 1 | 1 | 1 | 304 | 1 | 303 |  |  |  |  |  |
| tap g1 Drunk: Play again -> 02 | 4.95 | 12 | 12 | 12 | 766.4 | 12 | 4577 |  | 379 | 4129 | 851 | True |
| screen g1 Drunk: 02 table again | 2.01 | 0 | 0 | 0 | 0 | 0 | 0 |  |  |  |  |  |
