---------------------------- MODULE PhoneLobby ----------------------------
(* The host's phone in the lobby: the settings lane (settings and practice  *)
(* in ONE queue), the lobby reads, the socket, "Not sent." and "Try again"  *)
(* with the deal. Modelled from frontend/lib/features/lobby/:               *)
(*   domain/settings_lane.dart (SettingsLane: every lane transition)         *)
(*   presentation/lobby_taps.dart (_change _send retry deal)                 *)
(*   presentation/lobby_notifier.dart (_show refreshLobby _refreshOnce       *)
(*     _applyHeld _replayBuffered _onLobbyUpdate, the socket's state)        *)
(* core/websocket/read_on_drop.dart (a read when the socket drops and when  *)
(* it is back), lobby_state.dart (settling = pendingKeys not empty: Deal    *)
(* waits), backend/apps/core/views.py (PATCH and practice: apply, answer    *)
(* the whole lobby, broadcast lobby_update of that same lobby).             *)
(* First written from 7821a42 (the gaps a, b, b2, c as KNOWN); this is the  *)
(* fixed design: an answered change stays laid over the screen until        *)
(* nothing older can land (a); "Not sent." is derived from the lane (b,     *)
(* b2); "Try again" redoes every lost change and then a lost deal, and a    *)
(* deal goes behind the lane (c).                                           *)
(* A key's value is the number of the tap that asked it (0: the table's     *)
(* own), so "older" is "smaller". The phone sees a value, not a tap         *)
(* number: with COLLIDE two taps can carry the same value (seats 5, 6, 5).  *)
(* Practice is one key ("prac"); how several practice asks fold             *)
(* (PracticeAsk.then) is left to the unit tests.                            *)
(* Left out: the host role moving (403), the notifier going away, a deal    *)
(* that reached the server though its answer was lost.                      *)
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS MaxTaps, MaxFaults, MaxJoins, MaxDeals,
          LATE,     \* a request that got no answer in time may still reach the server later (#16)
          COLLIDE   \* two taps may set the same value: the phone cannot tell them apart

Keys == {"deck", "seats", "prac"}
\* one tap: the seats; a custom deck with its seats (startCustomDeck); practice
TapKeys == {{"seats"}, {"deck", "seats"}, {"prac"}}
Zero == [k \in Keys |-> 0]
\* what the phone can see of a value
Look(x) == IF COLLIDE THEN x % 2 ELSE x

VARIABLES
  sv, badOrder, sDealt,            \* server: the lobby's values; an older value written over a newer
  reqs, rep, evq, sock, joins,     \* lane requests in flight, the answer, socket events, socket up/down
  q, phase, shown,                 \* phone: the lane's queue (pending), its step, the screen
  conf, outSeen,                   \* answered (and lost) changes whose update may come; the update of the one out heard
  unsent, asked, askedAt,          \* the lost changes (each: still on screen?), the tap count, the newest ask per key
  refShown, dealHeld,              \* a refused value still on screen; the deal not sent ("Not sent.")
  rq, rv, again, buf,              \* refreshLobby: the read, its value, _refreshAgain, _buffered
  dq, pDealt, deals, dealView,     \* the deal: its request, the game opened, deal taps, the screen it was tapped on
  seen, hidden, ghost, stranded, dealBad,   \* history for the rules
  unsure,                          \* keys of a lost change that got through all the same (the phone cannot know)
  taps, faults

vars == <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, phase, shown, conf,
          outSeen, unsent, asked, askedAt, refShown, dealHeld, rq, rv, again, buf, dq, pDealt,
          deals, dealView, seen, hidden, ghost, stranded, dealBad, unsure, taps, faults>>
readVars == <<rq, rv, again, buf>>
laneVars == <<q, conf, outSeen, unsent, asked, askedAt, refShown, dealHeld>>
histVars == <<seen, hidden, ghost, stranded, dealBad, unsure>>
dealVars == <<dq, pDealt, deals, dealView>>

Max(S) == CHOOSE x \in S : \A y \in S : y <= x
Min(S) == CHOOSE x \in S : \A y \in S : x <= y
Vals(s) == {s[i].v : i \in 1..Len(s)}

(* SettingsLane.over: the server's lobby with every laid change over it, in order *)
\* a lost change waits in conf for its update (it may have got through) but is not laid
Laid(e) == "lay" \notin DOMAIN e \/ e.lay
Over(base, Q) ==
  [k \in Keys |-> LET I == {i \in 1..Len(Q) : k \in Q[i].keys /\ Laid(Q[i])}
                  IN IF I = {} THEN base[k] ELSE Q[Max(I)].v]
HasUpd(B) == \E i \in 1..Len(B) : B[i].t = "upd"
LastUpd(B) == B[Max({i \in 1..Len(B) : B[i].t = "upd"})].lob
HasJoin(B) == \E i \in 1..Len(B) : B[i].t = "join"
\* _replayBuffered: lobby_update carries the whole lobby, so the last one wins
Replay(base, B) == IF HasUpd(B) THEN LastUpd(B) ELSE base

(* ---------------- (a) answered changes stay laid over ---------------- *)
\* A taken change joins conf, laid over every lobby shown. due: its own
\* lobby_update may still come (the socket was up from its send to its answer
\* and the update has not been heard). It goes once it is not due and no lobby
\* read is out (a read asked before its answer may be older, and the events
\* held meanwhile are not applied yet): Keep runs only then.
Keep(C) == SelectSeq(C, LAMBDA e : e.due)
KeepIdle(C) == IF rq # "none" THEN C ELSE Keep(C)
Like(U, e) == \A k \in e.keys : Look(U[k]) = Look(e.v)
\* SettingsLane.heard: a lobby_update is the update of the oldest change still
\* waiting for one that it looks like (or newer): that one and every older one
\* has had its update (the socket keeps order).
Mark(C, U) ==
  LET J == {j \in 1..Len(C) : C[j].due /\ Like(U, C[j])}
  IN IF J = {} THEN C
     ELSE [i \in 1..Len(C) |-> IF i <= Min(J) THEN [C[i] EXCEPT !.due = FALSE] ELSE C[i]]
\* conf with the change out at its end (its update can come before its answer)
WithOut == conf \o (IF phase = "out" THEN <<Head(q) @@ [due |-> ~outSeen, lay |-> TRUE]>> ELSE <<>>)
Split(L) == [conf |-> SubSeq(L, 1, Len(conf)),
             outSeen |-> IF phase = "out" THEN ~L[Len(L)].due ELSE outSeen]
NoDue(C) == [i \in 1..Len(C) |-> [C[i] EXCEPT !.due = FALSE]]

(* ---------------- (b) "Not sent." is derived ---------------- *)
\* a lost change Try again would still send: a key no newer change asked for
WaitingIn(U, A) == \E i \in 1..Len(U) : \E k \in U[i].keys : A[k] = U[i].n
NS(U, A, dh) == WaitingIn(U, A) \/ dh
NotSent == NS(unsent, askedAt, dealHeld)
Waiting == WaitingIn(unsent, askedAt)

(* refreshLobby: a call while a read is out runs once more after it *)
Refresh == IF rq # "none" THEN again' = TRUE /\ UNCHANGED <<rq, buf>>
           ELSE rq' = "sent" /\ again' = FALSE /\ buf' = <<>>
\* the read loop goes again, or ends; a _send waiting on it (phase "reading") goes on
EndRead(ag) ==
  /\ buf' = <<>> /\ again' = FALSE
  /\ IF ag THEN rq' = "sent" /\ UNCHANGED phase
     ELSE rq' = "none" /\ phase' = IF phase = "reading" THEN "idle" ELSE phase

(* ---------------- server ---------------- *)
Answer(r, ans, lob) == rep' = IF r.live THEN {[n |-> r.n, ans |-> ans, lob |-> lob]} ELSE rep
\* PATCH / practice: applied and broadcast (after a deal: 409, nothing stored)
SApply(r) ==
  /\ reqs' = reqs \ {r}
  /\ IF sDealt THEN Answer(r, "refused", sv) /\ UNCHANGED <<sv, badOrder, evq>>
     ELSE LET nv == [k \in Keys |-> IF k \in r.keys THEN r.v ELSE sv[k]] IN
          /\ sv' = nv /\ Answer(r, "taken", nv)
          /\ badOrder' = (badOrder \/ \E k \in r.keys : r.v < sv[k])
          /\ evq' = IF sock = "up" THEN Append(evq, [t |-> "upd", lob |-> nv]) ELSE evq
  /\ UNCHANGED <<sDealt, sock, joins, phase, shown, laneVars, readVars, dealVars, histVars,
                 taps, faults>>
\* a 4xx: the table moved under the change (someone joined, the seats filled)
SRefuse(r) ==
  /\ faults < MaxFaults /\ faults' = faults + 1
  /\ reqs' = reqs \ {r} /\ Answer(r, "refused", sv)
  /\ UNCHANGED <<sv, badOrder, sDealt, evq, sock, joins, phase, shown, laneVars, readVars,
                 dealVars, histVars, taps>>
\* someone sits down: player_joined (the phone reads the lobby again)
SJoin ==
  /\ joins < MaxJoins /\ joins' = joins + 1
  /\ evq' = IF sock = "up" THEN Append(evq, [t |-> "join", lob |-> sv]) ELSE evq
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, sock, phase, shown, laneVars, readVars,
                 dealVars, histVars, taps, faults>>

(* ---------------- phone: the lane (_change, _send) ---------------- *)
\* "Try again" (and a deal on a lost value still shown): the lost changes U
\* again, oldest first, each with only the keys no newer change asked for
RECURSIVE Resend(_, _, _, _, _)
Resend(U, A, N, Q, S) ==
  IF U = <<>> THEN [a |-> A, n |-> N, q |-> Q, sent |-> S]
  ELSE LET c == Head(U) keep == {k \in c.keys : A[k] = c.n} IN
       IF keep = {} THEN Resend(Tail(U), A, N, Q, S)
       ELSE Resend(Tail(U), [k \in Keys |-> IF k \in keep THEN N + 1 ELSE A[k]], N + 1,
                   Append(Q, [n |-> N + 1, keys |-> keep, v |-> c.v]), S \cup {c.v})

Tap(ks) ==
  /\ taps < MaxTaps /\ ~pDealt /\ dq = "none"
  /\ LET c == [n |-> asked + 1, keys |-> ks, v |-> asked + 1]
         A2 == [k \in Keys |-> IF k \in ks THEN c.n ELSE askedAt[k]] IN
     /\ asked' = asked + 1 /\ q' = Append(q, c) /\ askedAt' = A2
     /\ shown' = Over(shown, conf \o Append(q, c))
     \* "Not sent." goes only when no lost change is left to send
     /\ hidden' = IF NotSent /\ ~NS(unsent, A2, dealHeld) THEN hidden \cup Vals(unsent) ELSE hidden
  /\ taps' = taps + 1
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, conf, outSeen,
                 unsent, refShown, dealHeld, readVars, dealVars, seen, ghost, stranded, dealBad,
                 unsure, faults>>
\* SettingsLane.sendNext: the next change goes when the one before is done
Send ==
  /\ phase = "idle" /\ q # <<>> /\ phase' = "out"
  /\ reqs' = reqs \cup {Head(q) @@ [live |-> TRUE]}
  /\ outSeen' = FALSE
  /\ UNCHANGED <<sv, badOrder, sDealt, rep, evq, sock, joins, q, shown, conf, unsent, asked,
                 askedAt, refShown, dealHeld, readVars, dealVars, histVars, taps, faults>>
\* the answer: taken (the server's lobby, conf and the rest of the queue over
\* it), or refused (dropped; the refused value stays until the read; a deal
\* behind it does not go)
Reply ==
  /\ phase = "out" /\ rep # {}
  /\ LET a == CHOOSE x \in rep : TRUE c == Head(q) IN
     /\ rep' = {} /\ q' = Tail(q)
     /\ IF a.ans = "taken"
        THEN LET C2 == KeepIdle(Append(conf, c @@ [due |-> ~outSeen, lay |-> TRUE]))
             IN /\ conf' = C2 /\ shown' = Over(a.lob, C2 \o Tail(q)) /\ phase' = "idle"
                /\ seen' = [k \in Keys |-> IF k \in c.keys /\ c.v > seen[k] THEN c.v ELSE seen[k]]
                /\ unsure' = unsure \ c.keys
                /\ refShown' = FALSE
                /\ UNCHANGED <<readVars, dq, dealHeld, unsent>>
        ELSE /\ phase' = "reading" /\ Refresh /\ refShown' = TRUE
             /\ IF dq = "queued" THEN dq' = "none" /\ dealHeld' = TRUE ELSE UNCHANGED <<dq, dealHeld>>
             /\ UNCHANGED <<shown, conf, seen, rv, unsent, unsure>>
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, evq, sock, joins, outSeen, asked, askedAt,
                 pDealt, deals, dealView, hidden, ghost, stranded, dealBad, taps, faults>>
\* SettingsLane.lose: no answer in time (offline, 5xx, 10 s): kept for "Try
\* again" ("Not sent."), on screen until a server lobby comes; a deal behind it does not go
Timeout ==
  /\ phase = "out" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ LET c == Head(q) IN
     /\ q' = Tail(q) /\ unsent' = Append(unsent, c)
     \* it may have got through: its update, if any, must not pass for a newer one's
     /\ conf' = KeepIdle(Append(conf, c @@ [due |-> ~outSeen, lay |-> FALSE]))
     /\ shown' = Over(shown, conf \o Tail(q))     \* the lost value stays until the read
     /\ rep' = {}
     /\ reqs' = IF LATE THEN {IF r.n = c.n THEN [r EXCEPT !.live = FALSE] ELSE r : r \in reqs}
                ELSE {r \in reqs : r.n # c.n}
  /\ IF dq = "queued" THEN dq' = "none" /\ dealHeld' = TRUE ELSE UNCHANGED <<dq, dealHeld>>
  /\ phase' = "reading" /\ Refresh
  /\ unsure' = IF \E x \in rep : x.ans = "taken" THEN unsure \cup Head(q).keys ELSE unsure
  /\ UNCHANGED <<sv, badOrder, sDealt, evq, sock, joins, outSeen, asked, askedAt,
                 refShown, rv, pDealt, deals, dealView, seen, hidden, ghost, stranded, dealBad, taps>>

(* ---------------- phone: reads and the socket ---------------- *)
ReadServe ==
  /\ rq = "sent" /\ rq' = "served" /\ rv' = sv
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, shown, laneVars,
                 again, buf, dealVars, histVars, taps, faults>>
\* _show(_replayBuffered(_adopt(read))): the held events over the read, every
\* laid change over all; then the read is no longer out
ReadApply ==
  /\ rq = "served"
  /\ shown' = Over(Replay(rv, buf), conf \o q)
  /\ conf' = Keep(conf)
  /\ refShown' = FALSE
  /\ EndRead(again \/ HasJoin(buf))
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, outSeen, unsent, asked,
                 askedAt, dealHeld, rv, dealVars, histVars, taps, faults>>
\* _applyHeld: the held events over what is shown
ReadFail ==
  /\ rq # "none" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ shown' = Over(Replay(shown, buf), conf \o q)
  /\ conf' = Keep(conf)
  /\ IF HasUpd(buf) THEN refShown' = FALSE ELSE UNCHANGED refShown
  /\ EndRead(again \/ HasJoin(buf))
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, outSeen, unsent, asked, askedAt,
                 dealHeld, rv, dealVars, histVars, taps>>
\* SettingsLane.heard, as each lobby_update arrives (held or not): the socket's
\* order is the order heard. Then held while a read is out; else lobby_update
\* is the server's lobby, player_joined a read.
EvDeliver ==
  /\ evq # <<>> /\ evq' = Tail(evq)
  /\ LET e == Head(evq)
         S == IF e.t = "upd" THEN Split(Mark(WithOut, e.lob)) ELSE [conf |-> conf, outSeen |-> outSeen] IN
     /\ outSeen' = S.outSeen
     /\ IF rq # "none"
        THEN buf' = Append(buf, e) /\ conf' = S.conf
             /\ UNCHANGED <<shown, rq, again, phase, refShown>>
        ELSE IF e.t = "upd"
             THEN /\ conf' = Keep(S.conf)
                  /\ shown' = Over(e.lob, Keep(S.conf) \o q)
                  /\ refShown' = FALSE
                  /\ UNCHANGED <<buf, rq, again, phase>>
             ELSE Refresh /\ UNCHANGED <<shown, phase, conf, refShown>>
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, sock, joins, q, unsent, asked, askedAt, dealHeld, rv,
                 dealVars, histVars, taps, faults>>
\* readOnDrop: a read when it drops; events meanwhile are lost (so no
\* answered change waits for its update any more); a read when it is back
SockDrop ==
  /\ sock = "up" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ sock' = "down" /\ evq' = <<>> /\ Refresh
  /\ conf' = KeepIdle(NoDue(conf))
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, joins, q, phase, shown, outSeen, unsent, asked,
                 askedAt, refShown, dealHeld, rv, dealVars, histVars, taps>>
SockUp ==
  /\ sock = "down" /\ sock' = "up" /\ Refresh
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, joins, phase, shown, laneVars, rv,
                 dealVars, histVars, taps, faults>>

(* ---------------- phone: the deal and "Try again" ---------------- *)
\* Deal waits while anything is pending (settling). A refused value still on
\* screen: the deal does not go ("Not sent.", Try again). Lost changes ("Not
\* sent." showing): sent again first, shown at once, the deal behind them (the
\* phone cannot know whether a lost change got through, so a deal past one
\* could deal what the screen did not show). Else the deal goes.
DealTap ==
  /\ ~pDealt /\ dq = "none" /\ q = <<>> /\ deals < MaxDeals /\ deals' = deals + 1
  /\ IF refShown
     THEN dealHeld' = TRUE /\ UNCHANGED <<dq, dealView, q, unsent, asked, askedAt, shown, ghost>>
     ELSE LET R == Resend(unsent, askedAt, asked, q, {}) IN
          /\ unsent' = <<>>
          /\ askedAt' = R.a /\ asked' = R.n /\ q' = R.q
          /\ shown' = Over(shown, conf \o R.q) /\ dealView' = Over(shown, conf \o R.q)
          /\ dq' = (IF R.q = <<>> THEN "sent" ELSE "queued")
          /\ dealHeld' = FALSE
          /\ ghost' = (ghost \/ R.sent \cap hidden # {})
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, conf, outSeen,
                 refShown, readVars, pDealt, seen, hidden, stranded, dealBad, unsure, taps, faults>>
\* the deal behind the lane goes when every change before it is answered
DealGo ==
  /\ dq = "queued" /\ q = <<>> /\ phase = "idle" /\ dq' = "sent"
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, shown, laneVars,
                 readVars, pDealt, deals, dealView, histVars, taps, faults>>
DealServe ==
  /\ dq = "sent" /\ dq' = "taken" /\ sDealt' = TRUE
  /\ dealBad' = (dealBad \/ \E k \in Keys \ unsure : sv[k] # dealView[k])
  /\ UNCHANGED <<sv, badOrder, reqs, rep, evq, sock, joins, phase, shown, laneVars, readVars,
                 pDealt, deals, dealView, seen, hidden, ghost, stranded, unsure, taps, faults>>
DealRefuse ==
  /\ dq = "sent" /\ faults < MaxFaults /\ faults' = faults + 1 /\ dq' = "refused"
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, shown, laneVars,
                 readVars, pDealt, deals, dealView, histVars, taps>>
\* SettingsLane.dealLost: no answer: "Not sent.", Try again redoes it
DealLoss ==
  /\ dq = "sent" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ dq' = "none" /\ dealHeld' = TRUE
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, shown, q, conf,
                 outSeen, unsent, asked, askedAt, refShown, readVars, pDealt, deals, dealView,
                 histVars, taps>>
DealTaken ==
  /\ dq = "taken" /\ dq' = "done" /\ pDealt' = TRUE /\ dealHeld' = FALSE
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, shown, q, conf,
                 outSeen, unsent, asked, askedAt, refShown, readVars, deals, dealView, histVars,
                 taps, faults>>
\* a refused deal (an answer, its own words): not held; the lobby read again
DealRefused ==
  /\ dq = "refused" /\ dq' = "none" /\ dealHeld' = FALSE /\ Refresh
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, shown, q, conf,
                 outSeen, unsent, asked, askedAt, refShown, rv, pDealt, deals, dealView,
                 histVars, taps, faults>>

\* "Try again" (shown with "Not sent."): every lost change again, oldest first,
\* then the deal if it was not sent, behind them; a refused value still on
\* screen keeps the deal back (still "Not sent.")
Retry ==
  /\ NotSent /\ ~pDealt /\ dq = "none"
  /\ LET R == Resend(unsent, askedAt, asked, q, {})
         go == dealHeld /\ ~refShown IN
     /\ unsent' = <<>> /\ askedAt' = R.a /\ asked' = R.n /\ q' = R.q
     /\ shown' = Over(shown, conf \o R.q) /\ ghost' = (ghost \/ R.sent \cap hidden # {})
     /\ dq' = IF go THEN "queued" ELSE dq
     /\ dealHeld' = (dealHeld /\ ~go)
     /\ dealView' = IF go THEN Over(shown, conf \o R.q) ELSE dealView
     \* nothing left behind: a waiting lost change is sent, a held deal goes or still says so
     /\ stranded' = (stranded \/ (Waiting /\ R.sent = {}) \/ (dealHeld /\ ~go /\ ~refShown))
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, conf, outSeen,
                 refShown, readVars, pDealt, deals, seen, hidden, dealBad, unsure, taps, faults>>

Init ==
  /\ sv = Zero /\ badOrder = FALSE /\ sDealt = FALSE
  /\ reqs = {} /\ rep = {} /\ evq = <<>> /\ sock = "up" /\ joins = 0
  /\ q = <<>> /\ phase = "idle" /\ shown = Zero
  /\ conf = <<>> /\ outSeen = FALSE
  /\ unsent = <<>> /\ asked = 0 /\ askedAt = Zero /\ refShown = FALSE /\ dealHeld = FALSE
  /\ rq = "none" /\ rv = Zero /\ again = FALSE /\ buf = <<>>
  /\ dq = "none" /\ pDealt = FALSE /\ deals = 0 /\ dealView = Zero
  /\ unsure = {} /\ seen = Zero /\ hidden = {} /\ ghost = FALSE /\ stranded = FALSE /\ dealBad = FALSE
  /\ taps = 0 /\ faults = 0

\* nothing out, nothing held: the table sits (or the game opened)
Done ==
  /\ reqs = {} /\ rep = {} /\ evq = <<>> /\ sock = "up" /\ q = <<>> /\ phase = "idle"
  /\ rq = "none" /\ dq \in {"none", "done"} /\ UNCHANGED vars

SApplyStep == \E r \in reqs : SApply(r)
Next ==
  \/ Done
  \/ SApplyStep \/ \E r \in reqs : SRefuse(r) \/ SJoin
  \/ \E ks \in TapKeys : Tap(ks) \/ Send \/ Reply \/ Timeout
  \/ ReadServe \/ ReadApply \/ ReadFail \/ EvDeliver \/ SockDrop \/ SockUp
  \/ DealTap \/ DealGo \/ DealServe \/ DealRefuse \/ DealLoss \/ DealTaken \/ DealRefused \/ Retry

\* the network and the phone's own steps are fair; taps, faults and joins are not
Spec == Init /\ [][Next]_vars
        /\ WF_vars(SApplyStep) /\ WF_vars(Send) /\ WF_vars(Reply) /\ WF_vars(ReadServe)
        /\ WF_vars(ReadApply) /\ WF_vars(EvDeliver) /\ WF_vars(SockUp)
        /\ WF_vars(DealGo) /\ WF_vars(DealServe) /\ WF_vars(DealTaken) /\ WF_vars(DealRefused)

(* ---------------- rules ---------------- *)
\* the server never writes a key's older ask over a newer one (lane order; Try again never undoes)
NeverOlder == ~badOrder
\* (a, R3) once a change's answer is shown, its keys never show an older value
NoFlickerBack == \A k \in Keys : shown[k] >= seen[k]
\* ... and when they do, it is put right without anyone tapping
FlickerHeals == \A k \in Keys : (shown[k] < seen[k]) ~> (shown[k] >= seen[k])
\* (b, R1) a lost change that "Try again" would still send is said so on the screen
\* ("Not sent." is NotSent, derived; this checks the lane's bookkeeping says it)
LostFlagged == Waiting => NotSent
\* (b2, R1) "Try again" never sends a lost value after "Not sent." stopped showing for it
NoHiddenResend == ~ghost
\* (c, R2) "Try again" leaves nothing behind: every lost change is sent again,
\* and a deal not sent goes after them (or still says "Not sent.")
RetryCoversAll == ~stranded
\* (c, R2) what is dealt is what the screen showed when Deal (or its Try again) was
\* tapped, on every key but one whose change was lost ("Not sent.") and got
\* through all the same, until a later answer on it (the phone cannot know)
DealAsShown == ~dealBad
\* the screen ends where the server is, or says "Not sent."
Converges == <>[](pDealt \/ NotSent \/ shown = sv)
=============================================================================
