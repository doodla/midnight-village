---------------------------- MODULE PhoneLobby ----------------------------
(* The host's phone in the lobby: the settings lane (settings and practice  *)
(* in ONE queue), the lobby reads, the socket, "Not sent." and "Try again"  *)
(* with the deal. Modelled from frontend/lib/features/lobby/:               *)
(*   domain/settings_lane.dart (SettingsLane: every lane transition)         *)
(*   presentation/lobby_taps.dart (_change _send retry deal _dealAfterLane)  *)
(*   presentation/lobby_notifier.dart (_showServer _putBase refreshLobby     *)
(*     _refreshOnce _applyHeld _replayBuffered _onLobbyUpdate, the socket)   *)
(* core/websocket/read_on_drop.dart (a read when the socket drops and when  *)
(* it is back), lobby_state.dart (settling = pendingKeys not empty: Deal    *)
(* waits), backend/apps/core/views.py (PATCH and practice: apply, answer    *)
(* the whole lobby, broadcast lobby_update of that same lobby; a join to a  *)
(* full table takes a practice player's seat, practice.make_room).          *)
(* Every lobby body carries the server's revision `rev`, which rises with   *)
(* every change the server tells anyone; the phone never shows a body older *)
(* than the newest it has shown (equal is shown). Pending changes, a lost   *)
(* change "Try again" would still send, and a refused value until the next  *)
(* server lobby lie over it.                                                *)
(* A key's value is the number of the tap that asked it (0: the table's     *)
(* own; also what make_room leaves on "prac"), so for the host's own keys   *)
(* "older" is "smaller". Practice is one key ("prac"); how several practice *)
(* asks fold (PracticeAsk.then) is left to the unit tests.                  *)
(* Left out: the notifier going away, a deal that reached the server though *)
(* its answer was lost, the host role coming back to this phone.            *)
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS MaxTaps, MaxFaults, MaxJoins, MaxDeals,
          LATE,     \* a request that got no answer in time may still reach the server later (#16)
          FIX_ASKED \* every change carries the time of its tap (`asked`) and the server drops a
                    \* key whose stored ask is newer (#16, the server's half; the phone does not
                    \* send it yet, so FALSE is the phone of today)

Keys == {"deck", "seats", "prac"}
\* one tap: the seats; a custom deck with its seats (startCustomDeck); practice
TapKeys == {{"seats"}, {"deck", "seats"}, {"prac"}}
\* the keys only the host writes (make_room, the second writer, writes "prac")
HostOnly == {"deck", "seats"}
Zero == [k \in Keys |-> 0]
None == [n |-> 0, keys |-> {}, v |-> 0]

VARIABLES
  sv, sask, srev, badOrder,        \* server: the lobby's values, the newest host ask stored per key, its revision, an older ask over a newer
  sDealt, shost, stid, roomAt,     \* dealt; host moves so far (this phone hosts at 0); the table (a reused code: a new one); the rev make_room wrote "prac" at (0: never)
  reqs, rep, evq, sock, joins,     \* lane requests in flight, the answer, socket events, socket up/down, second-writer events
  q, phase,                        \* phone: the lane's queue (pending; its head is out in phase "out"), its step
  base, srn, phost, btid,          \* the server lobby under the screen (the newest shown), its rev, its host, its table
  unsent, asked, askedAt,          \* the lost changes, the tap count, the newest ask per key
  refC, dealHeld, guest,           \* the refused change still on screen ({} or {c}); the deal not sent; a 403 met
  rq, rv, again, buf,              \* refreshLobby: the read, its body, _refreshAgain, _buffered
  dq, pDealt, deals, dealView, dealMoved, \* the deal: its state, the game opened, deal taps, the screen at the tap, the keys another writer changed that the phone could not have shown
  flick, hostBack, hidden, ghost, stranded, dealBad, \* history for the rules
  taps, faults, tried              \* tried: the step before was a "Try again"

vars == <<sv, sask, srev, badOrder, sDealt, shost, stid, roomAt, reqs, rep, evq, sock, joins, q,
          phase, base, srn, phost, btid, hostBack, unsent, asked, askedAt, refC, dealHeld, guest, rq, rv, again, buf, dq, pDealt,
          deals, dealView, dealMoved, flick, hidden, ghost, stranded, dealBad, taps, faults, tried>>
servVars == <<sv, sask, srev, badOrder, sDealt, shost, stid, roomAt>>
readVars == <<rq, rv, again, buf>>
laneVars == <<q, unsent, asked, askedAt, refC, dealHeld, guest>>
screenVars == <<base, srn, phost, btid, flick, hostBack>>
histVars == <<hidden, ghost, stranded, dealBad>>
dealVars == <<dq, pDealt, deals, dealView, dealMoved>>

Max(S) == CHOOSE x \in S : \A y \in S : y <= x
Vals(s) == {s[i].v : i \in 1..Len(s)}
Range(s) == {s[i] : i \in 1..Len(s)}
\* a lobby body (and host_changed): the values, the rev, the host, the table
Body == [v |-> sv, rev |-> srev, host |-> shost, tid |-> stid]
NoBody == [v |-> Zero, rev |-> 0, host |-> 0, tid |-> 0]
\* the host role is this phone's only before the first move
moved == shost > 0

(* ---------------- what the screen shows (SettingsLane.over) ---------------- *)
\* a lost or refused change lies over the server's lobby on the keys no newer change asked for
Newest(c) == {k \in c.keys : askedAt[k] = c.n}
\* every layer over the server's lobby: the refused value (until a server lobby is shown),
\* the lost changes "Try again" would still send (E: the screen shows what will go), the
\* pending changes; per key the newest ask wins
Layers == {[n |-> c.n, keys |-> Newest(c), v |-> c.v] : c \in refC \cup Range(unsent)}
          \cup Range(q)
Over(b) == [k \in Keys |-> LET L == {c \in Layers : k \in c.keys}
                           IN IF L = {} THEN b[k]
                              ELSE (CHOOSE c \in L : \A d \in L : d.n <= c.n).v]
Shown == Over(base)
\* the keys another writer changed that the phone could not show as they will be dealt:
\* make_room's "prac" after the lobby on screen, or while the host's own practice change is
\* still on its way (the server may apply make_room after it: the answer, older, is not
\* shown, and the deal deals the server's order), or every key of a new table at the same
\* code not heard of yet
PracPending == \E i \in 1..Len(q) : "prac" \in q[i].keys
Unseen == (IF roomAt > srn \/ (roomAt > 0 /\ PracPending) THEN {"prac"} ELSE {})
          \cup (IF stid # btid THEN Keys ELSE {})

(* ---------------- (b) "Not sent." is derived ---------------- *)
\* a lost change Try again would still send: a key no newer change asked for
WaitingIn(U, A) == \E i \in 1..Len(U) : \E k \in U[i].keys : A[k] = U[i].n
NS(U, A, dh) == WaitingIn(U, A) \/ dh
NotSent == NS(unsent, askedAt, dealHeld)
Waiting == WaitingIn(unsent, askedAt)

(* ---------------- the one compare (SettingsLane.admit) ---------------- *)
\* The events E arriving in this step, in order: a lobby body ("upd": an answer, a read, a
\* lobby_update) is shown when its rev is not lower than the newest shown, and host_changed
\* ("host") counts as shown at its rev; a lower one is ignored. The newest is per table: a
\* body of another table (a reused code) starts again. A body shown takes the refused value
\* off the screen.
Adm(c, b) == b.tid # c.tid \/ b.rev >= c.rev
Step1(c, e) ==
  IF e.t = "upd" /\ Adm(c, e.lob)
  THEN [v |-> e.lob.v, rev |-> e.lob.rev, host |-> e.lob.host, tid |-> e.lob.tid, body |-> TRUE,
        fl |-> c.fl \/ (e.lob.tid = c.tid /\ \E k \in HostOnly : e.lob.v[k] < c.v[k]),
        hb |-> c.hb \/ (e.lob.tid = c.tid /\ e.lob.host < c.host)]
  ELSE IF e.t = "host" /\ Adm(c, e.lob)
  THEN [c EXCEPT !.rev = e.lob.rev, !.host = e.lob.host, !.tid = e.lob.tid,
                 !.hb = c.hb \/ (e.lob.tid = c.tid /\ e.lob.host < c.host)]
  ELSE c
RECURSIVE Fold(_, _)
Fold(c, E) == IF E = <<>> THEN c ELSE Fold(Step1(c, Head(E)), Tail(E))
Apply(E) ==
  LET c == Fold([v |-> base, rev |-> srn, host |-> phost, tid |-> btid, body |-> FALSE,
                 fl |-> flick, hb |-> hostBack], E) IN
  /\ base' = c.v /\ srn' = c.rev /\ phost' = c.host /\ btid' = c.tid
  /\ flick' = c.fl /\ hostBack' = c.hb
  /\ refC' = IF c.body THEN {} ELSE refC
Show(b) == Apply(<<[t |-> "upd", lob |-> b]>>)
HasJoin(B) == \E i \in 1..Len(B) : B[i].t = "join"

(* refreshLobby: a call while a read is out runs once more after it *)
Refresh == IF rq # "none" THEN again' = TRUE /\ UNCHANGED <<rq, buf>>
           ELSE rq' = "sent" /\ again' = FALSE /\ buf' = <<>>
\* the read loop goes again, or ends; a _send waiting on it (phase "reading") goes on
EndRead(ag) ==
  /\ buf' = <<>> /\ again' = FALSE /\ rv' = NoBody
  /\ IF ag THEN rq' = "sent" /\ UNCHANGED phase
     ELSE rq' = "none" /\ phase' = IF phase = "reading" THEN "idle" ELSE phase

(* ---------------- server ---------------- *)
Answer(r, ans, lob) == rep' = IF r.live THEN {[n |-> r.n, ans |-> ans, lob |-> lob]} ELSE rep
\* PATCH / practice: applied and broadcast (after a deal: 409, nothing stored; the host
\* role moved: 403)
SApply(r) ==
  /\ reqs' = reqs \ {r}
  /\ IF moved THEN Answer(r, "forbidden", NoBody) /\ UNCHANGED <<sv, sask, srev, badOrder, roomAt, evq>>
     ELSE IF sDealt THEN Answer(r, "refused", NoBody) /\ UNCHANGED <<sv, sask, srev, badOrder, roomAt, evq>>
     ELSE \* a host value IS the order it was asked in (v), so "the stored ask is newer" is
          \* sask[k] > r.v; all keys stale: 409 stale_request, nothing stored, nothing broadcast
          LET keep == IF FIX_ASKED THEN {k \in r.keys : r.v >= sask[k]} ELSE r.keys
              nb == [Body EXCEPT !.v = [k \in Keys |-> IF k \in keep THEN r.v ELSE sv[k]],
                                 !.rev = srev + 1] IN
          IF keep = {} THEN Answer(r, "refused", NoBody) /\ UNCHANGED <<sv, sask, srev, badOrder, roomAt, evq>>
          ELSE /\ sv' = nb.v /\ srev' = srev + 1 /\ Answer(r, "taken", nb)
               /\ sask' = [k \in Keys |-> IF k \in keep THEN r.v ELSE sask[k]]
               /\ badOrder' = (badOrder \/ \E k \in keep : r.v < sask[k])
               /\ evq' = IF sock = "up" THEN Append(evq, [t |-> "upd", lob |-> nb]) ELSE evq
               /\ UNCHANGED roomAt
  /\ UNCHANGED <<sDealt, shost, stid, sock, joins, phase, laneVars, screenVars, readVars, dealVars,
                 histVars, taps, faults>>
\* a 4xx: the table moved under the change (someone joined, the seats filled)
SRefuse(r) ==
  /\ faults < MaxFaults /\ faults' = faults + 1
  /\ reqs' = reqs \ {r} /\ Answer(r, "refused", NoBody)
  /\ UNCHANGED <<servVars, evq, sock, joins, phase, laneVars, screenVars, readVars, dealVars,
                 histVars, taps>>
\* the second writer, numbered like every change: a presence change (lobby_update), someone
\* sitting down (lobby_update, then player_joined: the phone reads again), or someone sitting
\* down at a full table in a practice player's seat (make_room writes "prac")
SOther ==
  /\ joins < MaxJoins /\ joins' = joins + 1 /\ ~sDealt
  /\ \E kind \in {"presence", "join", "room"} :
       /\ kind = "room" => sv["prac"] # 0
       /\ LET nb == [Body EXCEPT !.v = IF kind = "room" THEN [sv EXCEPT !["prac"] = 0] ELSE sv,
                                  !.rev = srev + 1] IN
          /\ sv' = nb.v /\ srev' = srev + 1
          /\ roomAt' = IF kind = "room" THEN srev + 1 ELSE roomAt
          \* a deal tapped and not served yet: the phone could not have shown it
          /\ dealMoved' = IF kind = "room" /\ dq \in {"queued", "sent"}
                          THEN dealMoved \cup {"prac"} ELSE dealMoved
          /\ evq' = IF sock = "down" THEN evq
                    ELSE IF kind = "presence" THEN Append(evq, [t |-> "upd", lob |-> nb])
                    ELSE evq \o <<[t |-> "upd", lob |-> nb], [t |-> "join", lob |-> NoBody]>>
  /\ UNCHANGED <<sask, badOrder, sDealt, shost, stid, reqs, rep, sock, phase, laneVars,
                 screenVars, readVars, dq, pDealt, deals, dealView, histVars, taps, faults>>
\* the table closed and a new one opened at the same code: its revs start again (bounded
\* to a moment with nothing of the old table in flight); its first lobby_update
SNewTable ==
  /\ joins < MaxJoins /\ joins' = joins + 1 /\ ~sDealt
  /\ reqs = {} /\ rep = {} /\ evq = <<>> /\ rq = "none" /\ dq = "none" /\ phase = "idle"
  /\ q = <<>>
  /\ sv' = Zero /\ sask' = Zero /\ srev' = 1 /\ shost' = 0 /\ stid' = 1 - stid /\ roomAt' = 0
  /\ evq' = IF sock = "up"
            THEN <<[t |-> "upd", lob |-> [v |-> Zero, rev |-> 1, host |-> 0, tid |-> 1 - stid]]>>
            ELSE evq
  /\ UNCHANGED <<badOrder, sDealt, reqs, rep, sock, phase, laneVars, screenVars, readVars,
                 dealVars, histVars, taps, faults>>
\* the host role moves to someone else (a handover): told to the table; this phone learns
\* it from a 403
SMove ==
  /\ ~sDealt /\ faults < MaxFaults /\ faults' = faults + 1
  /\ shost' = shost + 1 /\ srev' = srev + 1
  /\ evq' = IF sock = "up"
            THEN Append(evq, [t |-> "host", lob |-> [Body EXCEPT !.rev = srev + 1, !.host = shost + 1]])
            ELSE evq
  /\ UNCHANGED <<sv, sask, badOrder, sDealt, stid, roomAt, reqs, rep, sock, joins, phase,
                 laneVars, screenVars, readVars, dealVars, histVars, taps>>

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

\* SettingsLane.ask. A tap while a deal waits behind the lane keeps the deal back (B: it
\* would not deal what was shown at its tap): "Not sent.", Try again deals.
Tap(ks) ==
  /\ taps < MaxTaps /\ ~pDealt /\ ~guest
  /\ LET c == [n |-> asked + 1, keys |-> ks, v |-> asked + 1]
         A2 == [k \in Keys |-> IF k \in ks THEN c.n ELSE askedAt[k]]
         held == dealHeld \/ dq = "queued" IN
     /\ asked' = asked + 1 /\ q' = Append(q, c) /\ askedAt' = A2
     /\ dealHeld' = held /\ dq' = IF dq = "queued" THEN "none" ELSE dq
     \* "Not sent." goes only when no lost change is left to send
     /\ hidden' = IF NotSent /\ ~NS(unsent, A2, held) THEN hidden \cup Vals(unsent) ELSE hidden
  /\ taps' = taps + 1
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, phase, unsent, refC, guest, screenVars,
                 readVars, pDealt, deals, dealView, dealMoved, ghost, stranded, dealBad, faults>>
\* SettingsLane.sendNext: the next change goes when the one before is done; a change asked
\* while the deal is out goes after its answer (the deal is on the settings queue)
Send ==
  /\ phase = "idle" /\ q # <<>> /\ dq \notin {"sent", "taken"} /\ phase' = "out"
  /\ reqs' = reqs \cup {Head(q) @@ [live |-> TRUE]}
  /\ UNCHANGED <<servVars, rep, evq, sock, joins, laneVars, screenVars, readVars, dealVars,
                 histVars, taps, faults>>
\* the answer: taken (shown if not older than the screen's lobby), refused (dropped; the
\* refused value stays until a server lobby; a deal behind it does not go), or 403 (the
\* host role moved: the lane forgets what it would send again and any held deal, D)
Reply ==
  /\ phase = "out" /\ rep # {}
  /\ LET a == CHOOSE x \in rep : TRUE c == Head(q) IN
     /\ rep' = {}
     /\ CASE a.ans = "taken" ->
             /\ q' = Tail(q) /\ phase' = "idle" /\ Show(a.lob)
             /\ UNCHANGED <<rq, again, buf, dq, dealHeld, unsent, guest>>
          [] a.ans = "refused" ->
             /\ q' = Tail(q) /\ phase' = "reading" /\ Refresh /\ refC' = {c}
             /\ IF dq = "queued" THEN dq' = "none" /\ dealHeld' = TRUE ELSE UNCHANGED <<dq, dealHeld>>
             /\ UNCHANGED <<screenVars, unsent, guest>>
          [] a.ans = "forbidden" ->
             /\ q' = <<>> /\ unsent' = <<>> /\ dealHeld' = FALSE /\ guest' = TRUE
             /\ phase' = "reading" /\ Refresh
             /\ dq' = IF dq = "queued" THEN "none" ELSE dq
             /\ UNCHANGED <<screenVars, refC>>
  /\ UNCHANGED <<servVars, reqs, evq, sock, joins, asked, askedAt, rv, pDealt, deals, dealView,
                 dealMoved, histVars, taps, faults>>
\* SettingsLane.lose: no answer in time (offline, 5xx, 10 s): kept for "Try again" ("Not
\* sent."), its value over the screen while it would still be sent; a deal behind it does
\* not go
Timeout ==
  /\ phase = "out" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ LET c == Head(q) IN
     /\ q' = Tail(q) /\ unsent' = Append(unsent, c)
     /\ rep' = {}
     /\ reqs' = IF LATE THEN {IF r.n = c.n THEN [r EXCEPT !.live = FALSE] ELSE r : r \in reqs}
                ELSE {r \in reqs : r.n # c.n}
  /\ IF dq = "queued" THEN dq' = "none" /\ dealHeld' = TRUE ELSE UNCHANGED <<dq, dealHeld>>
  /\ phase' = "reading" /\ Refresh
  /\ UNCHANGED <<servVars, evq, sock, joins, asked, askedAt, refC, guest, screenVars, rv,
                 pDealt, deals, dealView, dealMoved, histVars, taps>>

(* ---------------- phone: reads and the socket ---------------- *)
ReadServe ==
  /\ rq = "sent" /\ rq' = "served" /\ rv' = Body
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, phase, laneVars, screenVars, again, buf,
                 dealVars, histVars, taps, faults, refC>>
\* _replayBuffered over the read: the read and every lobby_update held meanwhile, each shown
\* if not older; then the read is no longer out
ReadApply ==
  /\ rq = "served"
  /\ Apply(<<[t |-> "upd", lob |-> rv]>> \o buf)
  /\ EndRead(again \/ HasJoin(buf))
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, q, unsent, asked, askedAt, dealHeld,
                 guest, dealVars, histVars, taps, faults>>
\* _applyHeld: the events held meanwhile, over what is shown
ReadFail ==
  /\ rq # "none" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ Apply(buf)
  /\ EndRead(again \/ HasJoin(buf))
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, q, unsent, asked, askedAt, dealHeld,
                 guest, dealVars, histVars, taps>>
\* held while a read is out; else lobby_update is the server's lobby, player_joined a read
EvDeliver ==
  /\ evq # <<>> /\ evq' = Tail(evq)
  /\ LET e == Head(evq) IN
     IF rq # "none"
     THEN buf' = Append(buf, e) /\ UNCHANGED <<screenVars, refC, rq, again, phase>>
     ELSE IF e.t \in {"upd", "host"}
          THEN Apply(<<e>>) /\ UNCHANGED <<buf, rq, again, phase>>
          ELSE Refresh /\ UNCHANGED <<screenVars, refC, phase>>
  /\ UNCHANGED <<servVars, reqs, rep, sock, joins, q, unsent, asked, askedAt, dealHeld, guest,
                 rv, dealVars, histVars, taps, faults>>
\* readOnDrop: a read when it drops; events meanwhile are lost; a read when it is back
SockDrop ==
  /\ sock = "up" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ sock' = "down" /\ evq' = <<>> /\ Refresh
  /\ UNCHANGED <<servVars, reqs, rep, joins, phase, laneVars, screenVars, rv, dealVars,
                 histVars, taps>>
SockUp ==
  /\ sock = "down" /\ sock' = "up" /\ Refresh
  /\ UNCHANGED <<servVars, reqs, rep, evq, joins, phase, laneVars, screenVars, rv, dealVars,
                 histVars, taps, faults>>

(* ---------------- phone: the deal and "Try again" ---------------- *)
\* Deal waits while anything is pending (settling). A refused value still on screen: the
\* deal does not go ("Not sent.", Try again). Lost changes (on screen, "Not sent."): sent
\* again first, the deal behind them. What is dealt is the screen at the tap (E).
DealTap ==
  /\ ~pDealt /\ ~guest /\ dq = "none" /\ q = <<>> /\ deals < MaxDeals /\ deals' = deals + 1
  /\ IF refC # {}
     THEN dealHeld' = TRUE /\ UNCHANGED <<dq, dealView, dealMoved, unsent, asked, askedAt, q, ghost>>
     ELSE LET R == Resend(unsent, askedAt, asked, q, {}) IN
          /\ unsent' = <<>>
          /\ askedAt' = R.a /\ asked' = R.n /\ q' = R.q
          /\ dealView' = Shown /\ dealMoved' = Unseen
          /\ dq' = (IF R.q = <<>> THEN "sent" ELSE "queued")
          /\ dealHeld' = FALSE
          /\ ghost' = (ghost \/ R.sent \cap hidden # {})
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, phase, refC, guest, screenVars,
                 readVars, pDealt, hidden, stranded, dealBad, taps, faults>>
\* the deal behind the lane goes when every change before it is answered (_dealAfterLane)
DealGo ==
  /\ dq = "queued" /\ q = <<>> /\ phase = "idle" /\ dq' = "sent"
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, phase, laneVars, screenVars, readVars,
                 pDealt, deals, dealView, dealMoved, histVars, taps, faults>>
\* the server deals (what it holds), or answers 403 (the role moved: the phone is a guest,
\* nothing held)
DealServe ==
  /\ dq = "sent" /\ dealView' = Zero /\ dealMoved' = {}
  /\ IF moved
     THEN /\ dq' = "none" /\ guest' = TRUE /\ unsent' = <<>> /\ dealHeld' = FALSE /\ q' = <<>>
          /\ UNCHANGED <<sDealt, dealBad>>
     ELSE /\ dq' = "taken" /\ sDealt' = TRUE
          \* a key make_room wrote after the screen's lobby at the tap: the phone could not show it
          /\ dealBad' = (dealBad \/ \E k \in Keys \ dealMoved : sv[k] # dealView[k])
          /\ UNCHANGED <<guest, unsent, dealHeld, q>>
  /\ UNCHANGED <<sv, sask, srev, badOrder, shost, stid, roomAt, reqs, rep, evq, sock, joins, phase,
                 asked, askedAt, refC, screenVars, readVars, pDealt, deals,
                 hidden, ghost, stranded, taps, faults>>
DealRefuse ==
  /\ dq = "sent" /\ faults < MaxFaults /\ faults' = faults + 1 /\ dq' = "refused"
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, phase, laneVars, screenVars, readVars,
                 pDealt, deals, dealView, dealMoved, histVars, taps>>
\* SettingsLane.dealLost: no answer: "Not sent.", Try again redoes it
DealLoss ==
  /\ dq = "sent" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ dq' = "none" /\ dealHeld' = TRUE
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, phase, q, unsent, asked, askedAt, refC,
                 guest, screenVars, readVars, pDealt, deals, dealView, dealMoved, histVars, taps>>
DealTaken ==
  /\ dq = "taken" /\ dq' = "done" /\ pDealt' = TRUE /\ dealHeld' = FALSE
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, phase, q, unsent, asked, askedAt, refC,
                 guest, screenVars, readVars, deals, dealView, dealMoved, histVars, taps, faults>>
\* a refused deal (an answer, its own words): not held; the lobby read again
DealRefused ==
  /\ dq = "refused" /\ dq' = "none" /\ dealHeld' = FALSE /\ Refresh
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, phase, q, unsent, asked, askedAt, refC,
                 guest, screenVars, rv, pDealt, deals, dealView, dealMoved, histVars, taps, faults>>

\* "Try again" (shown with "Not sent."): every lost change again, oldest first, then the deal
\* if it was not sent, behind them. A refused value still on screen: the lobby is read (C),
\* and the deal stays back until a Try again on what the read shows.
Retry ==
  /\ NotSent /\ ~pDealt /\ ~guest
  /\ LET R == Resend(unsent, askedAt, asked, q, {})
         go == dealHeld /\ refC = {} IN
     /\ unsent' = <<>> /\ askedAt' = R.a /\ asked' = R.n /\ q' = R.q
     /\ ghost' = (ghost \/ R.sent \cap hidden # {})
     /\ dq' = IF go THEN "queued" ELSE dq
     /\ dealHeld' = (dealHeld /\ ~go)
     /\ dealView' = IF go THEN Shown ELSE dealView
     /\ dealMoved' = IF go THEN Unseen ELSE dealMoved
     /\ IF refC # {} THEN Refresh ELSE UNCHANGED <<rq, again, buf>>
     \* nothing left behind: a waiting lost change is sent, a held deal goes or the lobby is read
     /\ stranded' = (stranded \/ (Waiting /\ R.sent = {}) \/ (dealHeld /\ ~go /\ refC = {}))
  /\ UNCHANGED <<servVars, reqs, rep, evq, sock, joins, phase, refC, guest, screenVars, rv,
                 pDealt, deals, hidden, dealBad, taps, faults>>

Init ==
  /\ sv = Zero /\ sask = Zero /\ srev = 0 /\ badOrder = FALSE /\ sDealt = FALSE
  /\ shost = 0 /\ stid = 0 /\ roomAt = 0
  /\ reqs = {} /\ rep = {} /\ evq = <<>> /\ sock = "up" /\ joins = 0
  /\ q = <<>> /\ phase = "idle" /\ base = Zero /\ srn = 0 /\ phost = 0 /\ btid = 0 /\ hostBack = FALSE
  /\ unsent = <<>> /\ asked = 0 /\ askedAt = Zero /\ refC = {} /\ dealHeld = FALSE /\ guest = FALSE
  /\ rq = "none" /\ rv = NoBody /\ again = FALSE /\ buf = <<>>
  /\ dq = "none" /\ pDealt = FALSE /\ deals = 0 /\ dealView = Zero /\ dealMoved = {}
  /\ flick = FALSE /\ hidden = {} /\ ghost = FALSE /\ stranded = FALSE
  /\ dealBad = FALSE /\ taps = 0 /\ faults = 0 /\ tried = FALSE

\* nothing out, nothing held: the table sits (or the game opened)
Done ==
  /\ reqs = {} /\ rep = {} /\ evq = <<>> /\ sock = "up" /\ q = <<>> /\ phase = "idle"
  /\ rq = "none" /\ dq \in {"none", "done"} /\ UNCHANGED vars

SApplyStep == \E r \in reqs : SApply(r)
Step ==
  \/ SApplyStep \/ (\E r \in reqs : SRefuse(r)) \/ SOther \/ SNewTable \/ SMove
  \/ (\E ks \in TapKeys : Tap(ks)) \/ Send \/ Reply \/ Timeout
  \/ ReadServe \/ ReadApply \/ ReadFail \/ EvDeliver \/ SockDrop \/ SockUp
  \/ DealTap \/ DealGo \/ DealServe \/ DealRefuse \/ DealLoss \/ DealTaken \/ DealRefused
Next ==
  \/ Done
  \/ Retry /\ tried' = TRUE
  \/ Step /\ tried' = FALSE

\* every variable but `tried`, which no step reads (the invariant runs' VIEW)
View == <<sv, sask, srev, badOrder, sDealt, shost, stid, roomAt, reqs, rep, evq, sock, joins, q,
          phase, base, srn, phost, btid, hostBack, unsent, asked, askedAt, refC, dealHeld, guest, rq, rv, again, buf, dq, pDealt,
          deals, dealView, dealMoved, flick, hidden, ghost, stranded, dealBad, taps, faults>>

\* the network and the phone's own steps are fair; taps, faults and joins are not
Fair(A) == WF_vars(A /\ tried' = FALSE)
Spec == Init /\ [][Next]_vars
        /\ Fair(SApplyStep) /\ Fair(Send) /\ Fair(Reply) /\ Fair(ReadServe)
        /\ Fair(ReadApply) /\ Fair(EvDeliver) /\ Fair(SockUp)
        /\ Fair(DealGo) /\ Fair(DealServe) /\ Fair(DealTaken) /\ Fair(DealRefused)

(* ---------------- rules ---------------- *)
\* the server never writes a key's older ask over a newer one (lane order; Try again never undoes)
NeverOlder == ~badOrder
\* (A) the host's own keys never show a value older than one a server lobby already showed
\* (the second writer, make_room, writes only "prac": its order is the rev's, which is the compare)
\* (the server's values on them only rise, LATE aside, so: no lobby shown takes one back,
\* and nothing laid over the lobby is older than it)
NoFlickerBack == ~flick /\ \A k \in HostOnly : Shown[k] >= base[k]
\* (R0) a host_changed (or a lobby) older than the newest shown never puts an older host back
HostNeverBack == ~hostBack
\* (R1) a lost change that "Try again" would still send is said so on the screen
LostFlagged == Waiting => NotSent
\* (R1) "Try again" never sends a lost value after "Not sent." stopped showing for it
NoHiddenResend == ~ghost
\* (R2) "Try again" leaves nothing behind: every lost change is sent again, and a deal not
\* sent goes after them (or the lobby is read first when a refused value is on screen)
RetryCoversAll == ~stranded
\* (R2, E) what is dealt is what the screen showed when Deal (or its Try again) was tapped,
\* on every key but one make_room wrote after the lobby on screen then
DealAsShown == ~dealBad
\* (D) a phone that met a 403 is a guest's: no "Not sent." on it
GuestQuiet == guest => ~NotSent
\* (C) "Try again" always does something: a request goes out, or "Not sent." goes
Out == q # <<>> \/ phase # "idle" \/ rq # "none" \/ dq \in {"queued", "sent"}
TryAgainActs == tried ~> (Out \/ ~NotSent)
\* the screen ends where the server is, or says "Not sent."
Converges == <>[](pDealt \/ NotSent \/ Shown = sv)
=============================================================================
