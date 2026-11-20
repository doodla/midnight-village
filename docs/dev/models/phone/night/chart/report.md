# PhoneNight

TLC reached 11,045 states, more than the chart budget of 500, so the chart draws only the bug paths: 3 states and 4 arrows.

## FollowUpArmed breaks
TLC's counterexample is in tlc-FollowUpArmed.out. It has 10 steps:
0. Loading
1. a /me/ fetch fails: Loading
2. the stage ends (timer): Loading
3. a socket event asks for /me/: Loading
4. the server reads /me/: Loading
5. a /me/ answer lands: Window 1: look armed
6. she taps Choose: Window 1: look shows Chosen
7. the server takes a request: Window 1: look shows Chosen
8. the answer arrives: Window 1: look shows Chosen
9. the server reads /me/: Window 1: look shows Chosen
10. a /me/ answer lands: Window 1: look shows Chosen
The run stops in "Window 1: look shows Chosen" forever.

## Rules that hold
StoredAsIntended, OnePerTurn, NoChosenForUnusedTurn, NoDeadlock, ChosenNotForever, Converges
