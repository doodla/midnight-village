# PhoneNight

TLC reached 17,050 states, more than the chart budget of 500, so the chart draws only the bug paths: 3 states and 4 arrows.

## FollowUpArmed breaks
TLC's counterexample is in tlc-FollowUpArmed.out. It has 8 steps:
0. Loading
1. the stage ends (timer): Loading
2. the server reads /me/: Loading
3. a /me/ answer lands: Window 1: look armed
4. she taps Choose: Window 1: look shows Chosen
5. the server takes a request: Window 1: look shows Chosen
6. a socket event is dropped: Window 1: look shows Chosen
7. the answer arrives: Window 1: look shows Chosen
8. a /me/ fetch fails: Window 1: look shows Chosen
The run stops in "Window 1: look shows Chosen" forever.

## Rules that hold
StoredAsIntended, OnePerTurn, NoChosenForUnusedTurn, NoDeadlock, ChosenNotForever, Converges
