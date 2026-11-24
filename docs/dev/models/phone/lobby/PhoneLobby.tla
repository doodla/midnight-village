---------------------------- MODULE PhoneLobby ----------------------------
(* The host's phone in the lobby, as it is at 7821a42: the settings lane    *)
(* (settings and practice in ONE queue), the lobby reads, the socket, and   *)
(* the one "Try again" slot it shares with the deal. Modelled from          *)
(* frontend/lib/features/lobby/presentation/lobby_notifier.dart:            *)
(*   _pending _settingsQueue _asked _askedAt _unsent _retry   (143-164)     *)
(*   _show _withPending                                        (166-191)     *)
(*   refreshLobby _refreshLoop _refreshOnce _applyHeld         (321-375)     *)
(*   _replayBuffered (222-237), _onLobbyUpdate (447-464)                     *)
(*   _change _send _resendUnsent retry deal                    (552-694)     *)
(* core/websocket/read_on_drop.dart (a read when the socket drops and when  *)
(* it is back), lobby_state.dart (settling = pendingKeys not empty: Deal    *)
(* waits), backend/apps/core/views.py (PATCH and practice: apply, answer    *)
(* the whole lobby, broadcast lobby_update).                                *)
(* A key's value is the number of the tap that asked it (0: the table's     *)
(* own), so "older" is "smaller". Practice is one key ("prac"); how several *)
(* practice asks fold (PracticeAsk.then) is left to the unit tests.         *)
(* Left out: the host role moving (403), the notifier going away, a deal    *)
(* that reached the server though its answer was lost.                      *)
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS MaxTaps, MaxFaults, MaxJoins, MaxDeals,
          LATE, \* a request that got no answer in time may still reach the server later (#16)
          FIX_ASKED \* every change carries the time of its tap (`asked`) and the server drops a
                   \* key whose stored ask is newer (#16, the server's half; the phone does not
                   \* send it yet, so FALSE is the phone of today)

Keys == {"deck", "seats", "prac"}
\* one tap: the seats; a custom deck with its seats (startCustomDeck); practice
TapKeys == {{"seats"}, {"deck", "seats"}, {"prac"}}
Zero == [k \in Keys |-> 0]

VARIABLES
  sv, badOrder, sDealt,            \* server: the lobby's values; an older value written over a newer
  reqs, rep, evq, sock, joins,     \* lane requests in flight, the answer, socket events, socket up/down
  q, phase, shown, notSent,        \* phone: _pending (= the lane's queue), the lane's step, the screen
  unsent, retry, asked, askedAt,   \* _unsent, _retry, _asked, _askedAt
  rq, rv, again, buf,              \* refreshLobby: the read, its value, _refreshAgain, _buffered
  dq, pDealt, deals,               \* the deal: its request, the game opened, deal taps
  seen, hidden, ghost, stranded,   \* history for the rules
  taps, faults

vars == <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, phase, shown, notSent,
          unsent, retry, asked, askedAt, rq, rv, again, buf, dq, pDealt, deals,
          seen, hidden, ghost, stranded, taps, faults>>
readVars == <<rq, rv, again, buf>>
laneVars == <<q, unsent, retry, asked, askedAt>>
histVars == <<seen, hidden, ghost, stranded>>

Max(S) == CHOOSE x \in S : \A y \in S : y <= x
Vals(s) == {s[i].v : i \in 1..Len(s)}

(* _withPending: the server's lobby with every pending change over it, in order *)
Over(base, Q) ==
  [k \in Keys |-> LET I == {i \in 1..Len(Q) : k \in Q[i].keys}
                  IN IF I = {} THEN base[k] ELSE Q[Max(I)].v]
HasUpd(B) == \E i \in 1..Len(B) : B[i].t = "upd"
LastUpd(B) == B[Max({i \in 1..Len(B) : B[i].t = "upd"})].lob
HasJoin(B) == \E i \in 1..Len(B) : B[i].t = "join"
\* _replayBuffered: lobby_update carries the whole lobby, so the last one wins
Replay(base, B) == IF HasUpd(B) THEN LastUpd(B) ELSE base

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
     ELSE \* a value here IS the order it was asked in (v), so "the stored ask is newer" is
          \* sv[k] > r.v; all keys stale: 409 stale_request, nothing stored, nothing broadcast
          LET keep == IF FIX_ASKED THEN {k \in r.keys : r.v >= sv[k]} ELSE r.keys
              nv == [k \in Keys |-> IF k \in keep THEN r.v ELSE sv[k]] IN
          IF keep = {} THEN Answer(r, "refused", sv) /\ UNCHANGED <<sv, badOrder, evq>>
          ELSE /\ sv' = nv /\ Answer(r, "taken", nv)
               /\ badOrder' = (badOrder \/ \E k \in keep : r.v < sv[k])
               /\ evq' = IF sock = "up" THEN Append(evq, [t |-> "upd", lob |-> nv]) ELSE evq
  /\ UNCHANGED <<sDealt, sock, joins, q, phase, shown, notSent, laneVars, readVars,
                 dq, pDealt, deals, histVars, taps, faults>>
\* a 4xx: the table moved under the change (someone joined, the seats filled)
SRefuse(r) ==
  /\ faults < MaxFaults /\ faults' = faults + 1
  /\ reqs' = reqs \ {r} /\ Answer(r, "refused", sv)
  /\ UNCHANGED <<sv, badOrder, sDealt, evq, sock, joins, q, phase, shown, notSent,
                 laneVars, readVars, dq, pDealt, deals, histVars, taps>>
\* someone sits down: player_joined (the phone reads the lobby again)
SJoin ==
  /\ joins < MaxJoins /\ joins' = joins + 1
  /\ evq' = IF sock = "up" THEN Append(evq, [t |-> "join", lob |-> sv]) ELSE evq
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, sock, q, phase, shown, notSent,
                 laneVars, readVars, dq, pDealt, deals, histVars, taps, faults>>

(* ---------------- phone: the lane (_change, _send) ---------------- *)
Tap(ks) ==
  /\ taps < MaxTaps /\ ~pDealt /\ dq = "none"
  /\ LET c == [n |-> asked + 1, keys |-> ks, v |-> asked + 1] IN
     /\ asked' = asked + 1 /\ q' = Append(q, c)
     /\ askedAt' = [k \in Keys |-> IF k \in ks THEN c.n ELSE askedAt[k]]
     /\ shown' = Over(shown, Append(q, c))
  /\ taps' = taps + 1 /\ notSent' = FALSE            \* _show(lobby.copyWith(notSent: false))
  /\ hidden' = IF notSent THEN hidden \cup Vals(unsent) ELSE hidden
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, unsent, retry,
                 readVars, dq, pDealt, deals, seen, ghost, stranded, faults>>
\* _settingsQueue.then: the next change goes when the one before is done
Send ==
  /\ phase = "idle" /\ q # <<>> /\ phase' = "out"
  /\ reqs' = reqs \cup {Head(q) @@ [live |-> TRUE]}
  /\ UNCHANGED <<sv, badOrder, sDealt, rep, evq, sock, joins, q, shown, notSent, unsent, retry,
                 asked, askedAt, readVars, dq, pDealt, deals, histVars, taps, faults>>
\* the answer: taken (the server's lobby, the rest of the queue over it), or refused
Reply ==
  /\ phase = "out" /\ rep # {}
  /\ LET a == CHOOSE x \in rep : TRUE c == Head(q) IN
     /\ rep' = {} /\ q' = Tail(q)
     /\ IF a.ans = "taken"
        THEN /\ shown' = Over(a.lob, Tail(q)) /\ phase' = "idle"
             /\ seen' = [k \in Keys |-> IF k \in c.keys /\ c.v > seen[k] THEN c.v ELSE seen[k]]
             /\ UNCHANGED readVars
        ELSE \* dropped, the lobby read again, the queue waits for the read
             /\ phase' = "reading" /\ Refresh /\ UNCHANGED <<shown, seen, rv>>
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, evq, sock, joins, notSent, unsent, retry, asked,
                 askedAt, dq, pDealt, deals, hidden, ghost, stranded, taps, faults>>
\* no answer in time (offline, 5xx, 10 s): "Not sent.", kept for "Try again", read again
Timeout ==
  /\ phase = "out" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ LET c == Head(q) IN
     /\ q' = Tail(q) /\ unsent' = Append(unsent, c) /\ retry' = "resend" /\ notSent' = TRUE
     /\ shown' = Over(shown, Tail(q))       \* _withPending(now): the lost value stays until the read
     /\ rep' = {}
     /\ reqs' = IF LATE THEN {IF r.n = c.n THEN [r EXCEPT !.live = FALSE] ELSE r : r \in reqs}
                ELSE {r \in reqs : r.n # c.n}
  /\ phase' = "reading" /\ Refresh
  /\ UNCHANGED <<sv, badOrder, sDealt, evq, sock, joins, asked, askedAt, rv, dq, pDealt, deals,
                 histVars, taps>>

(* ---------------- phone: reads and the socket ---------------- *)
ReadServe ==
  /\ rq = "sent" /\ rq' = "served" /\ rv' = sv
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, phase, shown, notSent,
                 unsent, retry, asked, askedAt, again, buf, dq, pDealt, deals, histVars, taps, faults>>
\* _show(_replayBuffered(_adopt(read))): the held events over the read, pending over all
ReadApply ==
  /\ rq = "served" /\ shown' = Over(Replay(rv, buf), q) /\ EndRead(again \/ HasJoin(buf))
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, notSent, laneVars, rv,
                 dq, pDealt, deals, histVars, taps, faults>>
\* _applyHeld: the held events over what is shown
ReadFail ==
  /\ rq # "none" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ shown' = Over(Replay(shown, buf), q) /\ EndRead(again \/ HasJoin(buf))
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, notSent, laneVars, rv,
                 dq, pDealt, deals, histVars, taps>>
\* held while a read is out; else lobby_update is the server's lobby, player_joined a read
EvDeliver ==
  /\ evq # <<>> /\ evq' = Tail(evq)
  /\ LET e == Head(evq) IN
     IF rq # "none" THEN buf' = Append(buf, e) /\ UNCHANGED <<shown, rq, again, phase>>
     ELSE IF e.t = "upd" THEN shown' = Over(e.lob, q) /\ UNCHANGED <<buf, rq, again, phase>>
     ELSE Refresh /\ UNCHANGED <<shown, phase>>
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, sock, joins, q, notSent, laneVars, rv,
                 dq, pDealt, deals, histVars, taps, faults>>
\* readOnDrop: a read when it drops; events meanwhile are lost; a read when it is back
SockDrop ==
  /\ sock = "up" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ sock' = "down" /\ evq' = <<>> /\ Refresh
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, joins, q, phase, shown, notSent, laneVars, rv,
                 dq, pDealt, deals, histVars, taps>>
SockUp ==
  /\ sock = "down" /\ sock' = "up" /\ Refresh
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, joins, q, phase, shown, notSent, laneVars,
                 rv, dq, pDealt, deals, histVars, taps, faults>>

(* ---------------- phone: the deal and "Try again" ---------------- *)
\* Deal waits while anything is pending (settling)
DealTap ==
  /\ ~pDealt /\ dq = "none" /\ q = <<>> /\ deals < MaxDeals /\ deals' = deals + 1 /\ dq' = "sent"
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, phase, shown, notSent,
                 laneVars, readVars, pDealt, histVars, taps, faults>>
DealServe ==
  /\ dq = "sent" /\ dq' = "taken" /\ sDealt' = TRUE
  /\ UNCHANGED <<sv, badOrder, reqs, rep, evq, sock, joins, q, phase, shown, notSent, laneVars,
                 readVars, pDealt, deals, histVars, taps, faults>>
DealRefuse ==
  /\ dq = "sent" /\ faults < MaxFaults /\ faults' = faults + 1 /\ dq' = "refused"
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, phase, shown, notSent,
                 laneVars, readVars, pDealt, deals, histVars, taps>>
\* no answer: "Not sent.", and "Try again" is the deal (_retry = deal)
DealLoss ==
  /\ dq = "sent" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ dq' = "none" /\ retry' = "deal" /\ notSent' = TRUE
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, phase, shown, unsent,
                 asked, askedAt, readVars, pDealt, deals, histVars, taps>>
DealTaken ==
  /\ dq = "taken" /\ dq' = "done" /\ pDealt' = TRUE /\ retry' = "none"
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, phase, shown, notSent,
                 unsent, asked, askedAt, readVars, deals, histVars, taps, faults>>
\* a refused deal: _retry = null, no "Not sent.", the lobby read again
DealRefused ==
  /\ dq = "refused" /\ dq' = "none" /\ retry' = "none" /\ notSent' = FALSE /\ Refresh
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, q, phase, shown, unsent,
                 asked, askedAt, rv, pDealt, deals, histVars, taps, faults>>

(* _resendUnsent: each unsent change again with only the keys no newer change asked for *)
RECURSIVE Resend(_, _, _, _, _)
Resend(U, A, N, Q, S) ==
  IF U = <<>> THEN [a |-> A, n |-> N, q |-> Q, sent |-> S]
  ELSE LET c == Head(U) keep == {k \in c.keys : A[k] = c.n} IN
       IF keep = {} THEN Resend(Tail(U), A, N, Q, S)
       ELSE Resend(Tail(U), [k \in Keys |-> IF k \in keep THEN N + 1 ELSE A[k]], N + 1,
                   Append(Q, [n |-> N + 1, keys |-> keep, v |-> c.v]), S \cup {c.v})
\* "Try again" (shown with "Not sent."): whatever the one slot holds
Retry ==
  /\ notSent /\ ~pDealt /\ dq = "none" /\ notSent' = FALSE /\ retry' = "none"
  /\ IF retry = "resend"
     THEN LET R == Resend(unsent, askedAt, asked, q, {}) IN
          /\ unsent' = <<>> /\ askedAt' = R.a /\ asked' = R.n /\ q' = R.q
          /\ shown' = Over(shown, R.q) /\ ghost' = (ghost \/ R.sent \cap hidden # {})
          /\ UNCHANGED <<dq, stranded>>
     ELSE /\ dq' = IF retry = "deal" THEN "sent" ELSE dq
          /\ stranded' = (stranded \/ unsent # <<>>)
          /\ UNCHANGED <<unsent, askedAt, asked, q, shown, ghost>>
  /\ UNCHANGED <<sv, badOrder, sDealt, reqs, rep, evq, sock, joins, phase, readVars, pDealt,
                 deals, seen, hidden, taps, faults>>

Init ==
  /\ sv = Zero /\ badOrder = FALSE /\ sDealt = FALSE
  /\ reqs = {} /\ rep = {} /\ evq = <<>> /\ sock = "up" /\ joins = 0
  /\ q = <<>> /\ phase = "idle" /\ shown = Zero /\ notSent = FALSE
  /\ unsent = <<>> /\ retry = "none" /\ asked = 0 /\ askedAt = Zero
  /\ rq = "none" /\ rv = Zero /\ again = FALSE /\ buf = <<>>
  /\ dq = "none" /\ pDealt = FALSE /\ deals = 0
  /\ seen = Zero /\ hidden = {} /\ ghost = FALSE /\ stranded = FALSE /\ taps = 0 /\ faults = 0

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
  \/ DealTap \/ DealServe \/ DealRefuse \/ DealLoss \/ DealTaken \/ DealRefused \/ Retry

\* the network and the phone's own steps are fair; taps, faults and joins are not
Spec == Init /\ [][Next]_vars
        /\ WF_vars(SApplyStep) /\ WF_vars(Send) /\ WF_vars(Reply) /\ WF_vars(ReadServe)
        /\ WF_vars(ReadApply) /\ WF_vars(EvDeliver) /\ WF_vars(SockUp)
        /\ WF_vars(DealServe) /\ WF_vars(DealTaken) /\ WF_vars(DealRefused)

(* ---------------- rules ---------------- *)
\* the server never writes a key's older ask over a newer one (lane order; Try again never undoes)
NeverOlder == ~badOrder
\* (a) once a change's answer is shown, its keys never show an older value
NoFlickerBack == \A k \in Keys : shown[k] >= seen[k]
\* ... and when they do, it is put right without anyone tapping
FlickerHeals == \A k \in Keys : (shown[k] < seen[k]) ~> (shown[k] >= seen[k])
\* (b) a lost change that "Try again" would still send (a key nothing newer asked for) is said so
Waiting == \E i \in 1..Len(unsent) : \E k \in unsent[i].keys : askedAt[k] = unsent[i].n
LostFlagged == Waiting => notSent
\* (b) "Try again" never sends a change whose "Not sent." a later tap took away
NoHiddenResend == ~ghost
\* (c) "Try again" sends every change that did not get through
RetryCoversAll == ~stranded
\* the screen ends where the server is, or says "Not sent."
Converges == <>[](pDealt \/ notSent \/ shown = sv)
=============================================================================
