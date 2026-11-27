---------------------------- MODULE PhoneDay ----------------------------
(* ONE phone from the talk to the next game: the ready and vote lanes of    *)
(* the Outbox, /me/ and /me/table/, the results, play again.                *)
(* Modelled from protocol_two_game.dart (_submit, _send, _next, refresh,    *)
(* _accept, _armHealing, _loadOutcome, apply), outbox.dart, table_screen.   *)
(* dart (tableScreen), screen_table.dart (screenFor), where_am_i_provider.  *)
(* Game 1: 0 talk, 1 vote, 2 results; then play again (table waiting) and   *)
(* game 2 dealt (its first stage only: "night").                            *)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS MaxFaults, MaxTaps, FIX_HEAL,
          HOST_MOVES_ON, \* the host eventually plays again and deals (else the table may stay at the results)
          FIX_ASKED, \* a ready or a vote carries the time of its tap (`asked`) and the server answers
                    \* 409 stale_request to one older than the newest it applied for that lane (#16,
                    \* the server's half; the phone does not send it yet, so FALSE is today's phone)
          FIX_ASKLESS, \* branch ask-less: a stage change carries this phone's own view (`me`, sent
                    \* before the table's event, the results with it at the end): applied when its
                    \* stage is later, nothing read; the event reads /me/ only when the phone is
                    \* behind it. A taken ready or lock's answer is put on the held /me/. An event
                    \* is lost only with the socket (a drop), which comes back and reads /me/ and
                    \* /me/table/; the slow table poll runs only while it is down.
          ZOMBIE, \* the socket can die without closing (a phone that slept, a network changed
                  \* under it): it looks up, delivers nothing, and the poll stays off
          FIX_BEAT \* the server's beat: every socket hears a frame each heartbeat; one silent
                   \* for 2.5 beats is dropped by the phone (and opened again, as any drop)

Lanes == {"ready", "vote"}
NoTab == [status |-> "none", game |-> 0, phase |-> 0]
NoReq == [lane |-> "-", st |-> 9, val |-> "-", lock |-> FALSE, tap |-> 0]

VARIABLES
  sv, sReady, sVote, sLocked, sLast, badOrder, table,   \* server
  reqs, reps,                                          \* lane requests and answers in flight
  snap, cur, que, conts,                               \* phone: /me/ of game 1, outbox, awaits
  fq, fv, again,                                       \* /me/ fetch loop of game 1
  tq, tv, tab,                                         \* /me/table/: in flight, read value, held value
  oq, outcome,                                         \* GET results/
  ev, tev, taps, faults,
  evView, sock                                         \* FIX_ASKLESS: the view with ev; the socket

vars == <<sv, sReady, sVote, sLocked, sLast, badOrder, table, reqs, reps, snap, cur, que, conts,
          fq, fv, again, tq, tv, tab, oq, outcome, ev, tev, taps, faults, evView, sock>>
srvVars == <<sv, sReady, sVote, sLocked, sLast, badOrder, table>>
phoneVars == <<snap, cur, que, conts, fq, fv, again, tq, tv, tab, oq, outcome>>

\* what /me/ says; what /me/table/ says
MeView == [st |-> sv, ready |-> sReady, vote |-> sVote, locked |-> sLocked]
TableView == table

(* Outbox.on, for the vote and ready lanes: the latest tap of its stage *)
Shown(l) == IF que[l] # NoReq THEN que[l] ELSE cur[l].req
Me ==
  LET r == Shown("ready") v == Shown("vote") IN
  [st |-> snap.st,
   ready |-> IF r # NoReq /\ r.st = snap.st THEN r.val = "on" ELSE snap.ready,
   vote |-> IF v # NoReq /\ v.st = snap.st THEN v.val ELSE snap.vote,
   locked |-> IF v # NoReq /\ v.st = snap.st THEN v.lock ELSE snap.locked]

(* screenFor: table first, then /me/ of the table's game *)
Screen ==
  IF tab = NoTab THEN "loading"
  ELSE IF tab.status = "waiting" THEN "02 table"
  ELSE IF tab.game = 2 THEN "06 night (game 2)"
  ELSE LET ph == IF snap.st >= tab.phase THEN snap.st ELSE tab.phase IN
       CASE ph = 0 -> "08 talk" [] ph = 1 -> "09 vote" [] OTHER -> "10 count"
Truth ==
  IF table.status = "waiting" THEN "02 table"
  ELSE IF table.game = 2 THEN "06 night (game 2)"
  ELSE CASE sv = 0 -> "08 talk" [] sv = 1 -> "09 vote" [] OTHER -> "10 count"

Refresh == IF fq # "none" THEN again' = TRUE /\ UNCHANGED fq ELSE fq' = "sent" /\ again' = FALSE
\* ref.invalidate(myTableProvider): a new fetch; an older one's answer is ignored
InvalidateTable == tq' = "sent"

(* ---------------- server ---------------- *)
\* the talk / vote ends on its timer (or everyone is ready / locked)
SAdvance ==
  /\ table.game = 1 /\ sv < 2 /\ sv' = sv + 1 /\ ev' = TRUE
  /\ table' = [table EXCEPT !.phase = sv + 1, !.status = IF sv + 1 = 2 THEN "finished" ELSE "game"]
  /\ IF sv = 0 THEN sVote' = "none" /\ sLocked' = FALSE ELSE UNCHANGED <<sVote, sLocked>>
  /\ UNCHANGED <<sReady, sLast, badOrder, reqs, reps, phoneVars, tev, taps, faults>>
\* the host plays again (table waiting), then deals game 2
SPlayAgain ==
  /\ sv = 2 /\ table.status = "finished" /\ table' = [table EXCEPT !.status = "waiting"] /\ tev' = TRUE
  /\ UNCHANGED <<sv, sReady, sVote, sLocked, sLast, badOrder, reqs, reps, phoneVars, ev, taps, faults>>
SDeal ==
  /\ table.status = "waiting" /\ table' = [status |-> "game", game |-> 2, phase |-> 0] /\ tev' = TRUE
  /\ UNCHANGED <<sv, sReady, sVote, sLocked, sLast, badOrder, reqs, reps, phoneVars, ev, taps, faults>>

SProcess(r) ==
  LET ok == r.st = sv /\ table.game = 1 /\ ~(FIX_ASKED /\ r.tap < sLast[r.lane])
      ans == IF ~ok THEN "stale"
             ELSE IF r.lane = "vote" /\ sLocked THEN (IF r.lock /\ r.val = sVote THEN "taken" ELSE "stale")
             ELSE "taken"
      store == ok /\ ~(r.lane = "vote" /\ sLocked)
  IN /\ reqs' = reqs \ {r}
     /\ IF store /\ r.lane = "ready" THEN sReady' = (r.val = "on") ELSE UNCHANGED sReady
     /\ IF store /\ r.lane = "vote" THEN sVote' = r.val /\ sLocked' = r.lock ELSE UNCHANGED <<sVote, sLocked>>
     /\ IF store THEN /\ sLast' = [sLast EXCEPT ![r.lane] = IF r.tap > @ THEN r.tap ELSE @]
                      /\ badOrder' = (badOrder \/ r.tap < sLast[r.lane])
        ELSE UNCHANGED <<sLast, badOrder>>
     /\ reps' = IF r.live THEN reps \cup {[lane |-> r.lane, tap |-> r.tap, ans |-> ans]} ELSE reps
     /\ UNCHANGED <<sv, table, phoneVars, ev, tev, taps, faults>>

(* ---------------- phone: fetches ---------------- *)
FetchServe == fq = "sent" /\ fq' = "served" /\ fv' = MeView
              /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, again, tq, tv, tab, oq, outcome, ev, tev, taps, faults>>
\* _accept: drop an older stage; afterFetch drops taps of other stages and
\* confirmed ones; the results load the outcome; queued taps go
AfterFetch(c, v) == IF c.req # NoReq /\ (c.req.st # v.st \/ c.leg = "conf") THEN [req |-> NoReq, leg |-> "none"] ELSE c
FetchApply ==
  /\ fq = "served"
  /\ IF fv.st < snap.st THEN UNCHANGED <<snap, cur, que, oq>>
     ELSE /\ snap' = fv
          /\ cur' = [l \in Lanes |-> AfterFetch(cur[l], fv)]
          /\ que' = [l \in Lanes |-> IF que[l] # NoReq /\ que[l].st # fv.st THEN NoReq ELSE que[l]]
          /\ oq' = IF fv.st = 2 /\ outcome = "none" /\ oq = "none" THEN "sent" ELSE oq
  /\ IF again THEN fq' = "sent" /\ again' = FALSE ELSE fq' = "none" /\ UNCHANGED again
  /\ UNCHANGED <<srvVars, reqs, reps, conts, fv, tq, tv, tab, outcome, ev, tev, taps, faults>>
FetchFail ==
  /\ fq # "none" /\ faults < MaxFaults /\ faults' = faults + 1
  /\ IF again THEN fq' = "sent" /\ again' = FALSE ELSE fq' = "none" /\ UNCHANGED again
  /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fv, tq, tv, tab, oq, outcome, ev, tev, taps>>
\* _armHealing: after the stage's deadline (talk and vote have one; the results none)
Heal ==
  /\ snap.st < 2 /\ snap.st < sv /\ fq = "none" /\ Refresh
  /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fv, tq, tv, tab, oq, outcome, ev, tev, taps, faults>>
\* proposed: while at the results (no deadline), poll /me/table/ slowly
PollTable ==
  /\ FIX_HEAL /\ tab # NoTab /\ (snap.st = 2 \/ tab.status = "waiting")
  /\ tq = "none" /\ tab # table /\ InvalidateTable
  /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fq, fv, again, tv, tab, oq, outcome, ev, tev, taps, faults>>
EvDeliver ==   \* phase_change / progress etc. of game 1: fetch
  /\ ev /\ ev' = FALSE /\ Refresh
  /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fv, tq, tv, tab, oq, outcome, tev, taps, faults>>
TevDeliver ==  \* table_moved / play again: /me/table/ again (and /me/)
  /\ tev /\ tev' = FALSE /\ InvalidateTable /\ Refresh
  /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fv, tv, tab, oq, outcome, ev, taps, faults>>
EvDrop == \/ ev /\ ev' = FALSE /\ UNCHANGED <<srvVars, reqs, reps, phoneVars, tev, taps, faults>>
          \/ tev /\ tev' = FALSE /\ UNCHANGED <<srvVars, reqs, reps, phoneVars, ev, taps, faults>>
TableServe == tq = "sent" /\ tq' = "served" /\ tv' = TableView
              /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fq, fv, again, tab, oq, outcome, ev, tev, taps, faults>>
\* the held value is kept while it is fetched again (tableScreen)
TableApply ==
  /\ tq = "served" /\ tq' = "none" /\ tab' = tv /\ tv' = NoTab
  \* _compareTable: the table is ahead of /me/: fetch /me/ once
  /\ IF tv.game = 1 /\ tv.phase > snap.st THEN Refresh ELSE UNCHANGED <<fq, again>>
  /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fv, oq, outcome, ev, tev, taps, faults>>
\* a failed /me/table/ read; with FIX_ASKLESS it is read again (myTable's retryForever, the
\* app's own, whatever the socket: with no poll standing in for it, the model says so)
TableFail == tq # "none" /\ faults < MaxFaults /\ faults' = faults + 1 /\ tv' = NoTab
             /\ tq' = (IF FIX_ASKLESS THEN "sent" ELSE "none")
             /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fq, fv, again, tab, oq, outcome, ev, tev, taps>>
OutcomeOk == oq = "sent" /\ sv = 2 /\ oq' = "none" /\ outcome' = "loaded"
             /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fq, fv, again, tq, tv, tab, ev, tev, taps, faults>>
OutcomeFail == oq = "sent" /\ faults < MaxFaults /\ faults' = faults + 1 /\ oq' = (IF FIX_HEAL THEN "sent" ELSE "none")
               /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fq, fv, again, tq, tv, tab, outcome, ev, tev, taps>>

(* ---------------- phone: taps through the outbox ---------------- *)
Send(l, r) == /\ cur' = [cur EXCEPT ![l] = [req |-> r, leg |-> "flight"]]
              /\ reqs' = reqs \cup {[r EXCEPT !.lane = l] @@ [live |-> TRUE]}
Submit(l, r) ==
  IF cur[l].leg = "flight"
  THEN que' = [que EXCEPT ![l] = r] /\ UNCHANGED <<cur, reqs>>
  ELSE Send(l, r) /\ que' = [que EXCEPT ![l] = NoReq]

TapReady ==   \* 08 "Ready to vote", a toggle
  /\ tab # NoTab /\ Screen = "08 talk" /\ snap.st = 0 /\ taps < MaxTaps /\ taps' = taps + 1
  /\ Submit("ready", [lane |-> "ready", st |-> 0, val |-> IF Me.ready THEN "off" ELSE "on", lock |-> FALSE, tap |-> taps + 1])
  /\ UNCHANGED <<srvVars, reps, snap, conts, fq, fv, again, tq, tv, tab, oq, outcome, ev, tev, faults>>
TapVote(val, lock) ==   \* 09: pick a row, or lock in the one shown
  /\ tab # NoTab /\ Screen = "09 vote" /\ snap.st = 1 /\ ~Me.locked /\ taps < MaxTaps /\ taps' = taps + 1
  /\ lock => Me.vote # "none"
  /\ Submit("vote", [lane |-> "vote", st |-> 1, val |-> IF lock THEN Me.vote ELSE val, lock |-> lock, tap |-> taps + 1])
  /\ UNCHANGED <<srvVars, reps, snap, conts, fq, fv, again, tq, tv, tab, oq, outcome, ev, tev, faults>>
TapVoteStep == \/ TapVote("A", FALSE) \/ TapVote("B", FALSE) \/ TapVote("-", TRUE)

\* _send's answer; then _next sends the queued tap (unless it asks for what
\* was just confirmed)
Next1(l, c2) ==
  IF que[l] # NoReq /\ c2.leg # "flight"
  THEN IF c2.leg = "conf" /\ c2.req = que[l] THEN que' = [que EXCEPT ![l] = NoReq] /\ cur' = [cur EXCEPT ![l] = c2] /\ UNCHANGED reqs
       ELSE /\ cur' = [cur EXCEPT ![l] = [req |-> que[l], leg |-> "flight"]] /\ que' = [que EXCEPT ![l] = NoReq]
            /\ reqs' = (reqs \ {}) \cup {que[l] @@ [live |-> TRUE]}
  ELSE cur' = [cur EXCEPT ![l] = c2] /\ UNCHANGED <<que, reqs>>
Answer(l, tap, ans) ==
  LET match == cur[l].req # NoReq /\ cur[l].req.tap = tap /\ cur[l].leg = "flight"
      c2 == IF ~match THEN cur[l]
            ELSE CASE ans \in {"taken", "stale"} -> [cur[l] EXCEPT !.leg = "conf"]
                   [] OTHER -> [cur[l] EXCEPT !.leg = "unsent"]
  IN /\ Next1(l, c2)
     /\ IF match /\ ans = "stale" THEN Refresh ELSE UNCHANGED <<fq, again>>
Reply ==
  \E r \in reps : /\ reps' = reps \ {r} /\ Answer(r.lane, r.tap, r.ans)
                  /\ UNCHANGED <<srvVars, snap, conts, fv, tq, tv, tab, oq, outcome, ev, tev, taps, faults>>
\* no answer in time: notSent ("Try again"); the request may still arrive later
Timeout ==
  \E l \in Lanes :
    /\ cur[l].leg = "flight" /\ faults < MaxFaults /\ faults' = faults + 1
    /\ LET t == cur[l].req.tap IN
       /\ reps' = {x \in reps : ~(x.lane = l /\ x.tap = t)}
       /\ Answer(l, t, "notSent")
       /\ \* the request's answer, if it ever comes, goes nowhere
          TRUE
    /\ UNCHANGED <<srvVars, snap, conts, fv, tq, tv, tab, oq, outcome, ev, tev, taps>>
\* (a timed-out request still in reqs keeps live = TRUE here; its answer
\* matches no item in flight and changes nothing, as in _send)

(* ---------------- FIX_ASKLESS (branch ask-less) ---------------- *)
\* the server's stage change carries this phone's own view (the state just after it)
SAdvanceA == SAdvance /\ evView' = MeView' /\ UNCHANGED sock
\* the view first, then the table's event: applied when of a later stage (the
\* afterFetch of a push: taps of an ended stage go, confirming ones stay); the
\* results come in the same batch (on game_results); the event itself then reads
\* nothing (the view is as new)
AfterView(c, v) == IF c.req # NoReq /\ c.req.st # v.st THEN [req |-> NoReq, leg |-> "none"] ELSE c
EvDeliverA ==
  /\ ev /\ sock = "up" /\ ev' = FALSE
  /\ IF evView.st > snap.st
     THEN /\ snap' = evView
          /\ cur' = [l \in Lanes |-> AfterView(cur[l], evView)]
          /\ que' = [l \in Lanes |-> IF que[l] # NoReq /\ que[l].st # evView.st THEN NoReq ELSE que[l]]
          /\ outcome' = IF evView.st = 2 THEN "loaded" ELSE outcome
     ELSE UNCHANGED <<snap, cur, que, outcome>>
  /\ UNCHANGED <<srvVars, reqs, reps, conts, fq, fv, again, tq, tv, tab, oq, tev, taps, faults, evView, sock>>
TevDeliverA == sock = "up" /\ TevDeliver /\ UNCHANGED <<evView, sock>>
\* an event is lost only with its socket: down until it comes back
EvDropA == sock # "dead" /\ EvDrop /\ sock' = "down" /\ UNCHANGED evView
\* ZOMBIE: the socket dies open ("dead"): the phone still counts it up, so nothing reads
Zombie == ZOMBIE /\ sock = "up" /\ faults < MaxFaults /\ faults' = faults + 1 /\ sock' = "dead"
          /\ UNCHANGED <<srvVars, reqs, reps, phoneVars, ev, tev, taps, evView>>
\* FIX_BEAT: no frame for 2.5 beats, so the phone drops it (then Reconnect, as for any drop)
Beat == FIX_BEAT /\ sock = "dead" /\ sock' = "down"
        /\ UNCHANGED <<srvVars, reqs, reps, phoneVars, ev, tev, taps, faults, evView>>
\* back: everything is read again (_healEverything: /me/table/ and /me/)
Reconnect ==
  /\ sock = "down" /\ sock' = "up" /\ ev' = FALSE /\ tev' = FALSE /\ InvalidateTable /\ Refresh
  /\ UNCHANGED <<srvVars, reqs, reps, snap, cur, que, conts, fv, tv, tab, oq, outcome, taps, faults, evView>>
\* the slow table poll heals a socket that is down, never a healthy one
PollTableA == sock = "down" /\ PollTable /\ UNCHANGED <<evView, sock>>
\* a taken ready or lock's answer says what was stored: put on the held /me/
Fold(l, tap, ans) ==
  LET c == cur[l].req IN
  IF ans = "taken" /\ c # NoReq /\ c.tap = tap /\ cur[l].leg = "flight" /\ c.st = snap.st
  THEN CASE l = "ready" -> [snap EXCEPT !.ready = (c.val = "on")]
         [] c.lock -> [snap EXCEPT !.vote = c.val, !.locked = TRUE]
         [] OTHER -> snap
  ELSE snap
ReplyA ==
  \E r \in reps : /\ reps' = reps \ {r} /\ Answer(r.lane, r.tap, r.ans)
                  /\ snap' = Fold(r.lane, r.tap, r.ans)
                  /\ UNCHANGED <<srvVars, conts, fv, tq, tv, tab, oq, outcome, ev, tev, taps, faults, evView, sock>>

Done == table.game = 2 /\ tab # NoTab /\ tab.game = 2 /\ reqs = {} /\ reps = {} /\ fq = "none" /\ tq = "none"
        /\ oq = "none" /\ ~ev /\ ~tev /\ UNCHANGED vars

Init ==
  /\ sv = 0 /\ sReady = FALSE /\ sVote = "none" /\ sLocked = FALSE
  /\ sLast = [l \in Lanes |-> 0] /\ badOrder = FALSE
  /\ table = [status |-> "game", game |-> 1, phase |-> 0]
  /\ reqs = {} /\ reps = {}
  /\ snap = MeView /\ cur = [l \in Lanes |-> [req |-> NoReq, leg |-> "none"]] /\ que = [l \in Lanes |-> NoReq]
  /\ conts = {} /\ fq = "none" /\ fv = MeView /\ again = FALSE
  /\ tq = "none" /\ tv = NoTab /\ tab = table
  /\ oq = "none" /\ outcome = "none" /\ ev = FALSE /\ tev = FALSE /\ taps = 0 /\ faults = 0
  /\ evView = MeView /\ sock = "up"

SProcessStep == \E r \in reqs : SProcess(r)
SPlayAgainF == SPlayAgain
\* the actions both phones share (they leave the ask-less variables alone)
Shared ==
  \/ SPlayAgain \/ SDeal \/ SProcessStep
  \/ FetchServe \/ FetchApply \/ FetchFail \/ Heal
  \/ TableServe \/ TableApply \/ TableFail \/ OutcomeOk \/ OutcomeFail
  \/ TapReady \/ TapVoteStep \/ Timeout \/ Done
Next ==
  \/ Shared /\ UNCHANGED <<evView, sock>>
  \/ ~FIX_ASKLESS /\ (SAdvance \/ PollTable \/ EvDeliver \/ TevDeliver \/ EvDrop \/ Reply)
                  /\ UNCHANGED <<evView, sock>>
  \/ FIX_ASKLESS /\ (SAdvanceA \/ PollTableA \/ EvDeliverA \/ TevDeliverA \/ EvDropA
                     \/ Reconnect \/ ReplyA \/ Zombie \/ Beat)
\* an action that leaves the ask-less variables alone, and the phone's own
\* version of the three that differ
S(A) == A /\ UNCHANGED <<evView, sock>>
AdvanceF == IF FIX_ASKLESS THEN SAdvanceA ELSE S(SAdvance)
PollF == IF FIX_ASKLESS THEN PollTableA ELSE S(PollTable)
ReplyF == IF FIX_ASKLESS THEN ReplyA ELSE S(Reply)

\* the server's own timers and the host move the game on; phone internals are fair;
\* with FIX_ASKLESS a socket that is up delivers, and one that is down comes back;
\* with FIX_BEAT a dead one is noticed (without it, nothing brings a dead one back)
Spec == Init /\ [][Next]_vars
        /\ WF_vars(AdvanceF) /\ (HOST_MOVES_ON => WF_vars(S(SPlayAgain)) /\ WF_vars(S(SDeal)))
        /\ WF_vars(S(SProcessStep))
        /\ WF_vars(S(FetchServe)) /\ WF_vars(S(FetchApply)) /\ WF_vars(S(Heal)) /\ WF_vars(PollF)
        /\ WF_vars(S(TableServe)) /\ WF_vars(S(TableApply)) /\ WF_vars(S(OutcomeOk)) /\ WF_vars(ReplyF)
        /\ (FIX_ASKLESS => WF_vars(EvDeliverA) /\ WF_vars(TevDeliverA) /\ WF_vars(Reconnect))
        /\ (FIX_BEAT => WF_vars(Beat))

(* ---------------- rules ---------------- *)
\* the server stores this phone's taps of a lane in tap order (a lock never overtakes its pick)
TapOrder == ~badOrder
\* the screen ends where the server is, and the count has its results
ScreenConverges == <>[](Screen = Truth)
OutcomeLoads == (snap.st = 2 /\ table.game = 1 /\ table.status = "finished") ~> (outcome = "loaded" \/ table.status # "finished" \/ table.game # 1)
=============================================================================
