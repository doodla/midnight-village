---------------------------- MODULE Night2 ----------------------------
(* Protocol-2 game, deal (look stage) to results, 3 phones: d Doppelganger,  *)
(* r Robber (also the host), v Villager (the phone that can drop).           *)
(* Modelled from the code (backend/apps/onuw/night2.py, services.py,         *)
(* views.py, core/timers.py), at the granularity it really has:              *)
(*  - every request handler runs in ONE transaction under the Game row lock  *)
(*    and require_stage() refuses any token but the current one, storing     *)
(*    nothing: so a late request is a no-op and only requests naming the     *)
(*    current stage are steps here (one atomic step each);                  *)
(*  - timer schedule/cancel run AFTER commit (on_commit): a pending batch    *)
(*    applied by a later, separate step, in any order with other batches;    *)
(*  - timers.fire locks the row, checks its token, deletes it and runs the   *)
(*    job in that transaction: a late / duplicate / stale delivery is a      *)
(*    no-op, so a firing is "a row exists"; one atomic step;                 *)
(*  - GET /me/ reads the Game unlocked, then ensure_timers schedules         *)
(*    DIRECTLY from that snapshot when the key's row is missing: two steps.  *)
(* Clock abstracted: "minimum length passed?" and "deadline passed when a    *)
(* deferred close fires?" are free choices; grace running out is Tick.       *)
EXTENDS Naturals, Sequences, FiniteSets

P == {"d", "r", "v"}
Keys == {"look", "w1", "w2", "talk", "vote", "grace"}
Stages == {"look", "w1", "w2", "talk", "vote"}
Allowed == {<<"look","w1">>, <<"w1","w2">>, <<"w2","talk">>, <<"talk","vote">>, <<"vote","results">>}
RoleOf == [r |-> "Robber", v |-> "Villager"]
VoteFor == [d |-> "r", r |-> "v", v |-> "d"]

VARIABLES
  phase,      \* look | w1 | w2 | talk | vote | results
  ready,      \* PlayerRole.phase_ready
  chose,      \* night_action_data["chose_<w>"]
  dCopied,    \* none | Robber | Villager (her look resolves inside her request)
  dStep,      \* where her stored window-1 follow-up came from: none | look | followup
  sentF,      \* her phone sent its follow-up
  retried,    \* her phone resent its look once (the first response was lost)
  fRefused,   \* her follow-up was refused while window 1 was open
  resLook, resFollow, resR,  \* times each prompted action got its choice or default applied
  followSrc,  \* where the APPLIED follow-up came from: none | look | followup | default
  votes, locked, lockedAt,
  conn, dropped,   \* v: on | grace | gone
  rows, rowDef,    \* ScheduledTimer row exists (live token); its "deferred" param
  effects,         \* after-commit timer ops not applied yet: a set of op sequences
  snap, ensured    \* a GET /me/ snapshot of the stage awaiting ensure_timers; used once

vars == <<phase, ready, chose, dCopied, dStep, sentF, retried, fRefused, resLook, resFollow, resR,
          followSrc, votes, locked, lockedAt, conn, dropped, rows, rowDef, effects, snap, ensured>>
phoneIn == <<chose, dCopied, dStep, sentF, retried, fRefused>>
outVars == <<resLook, resFollow, resR, followSrc>>
voteVars == <<votes, locked, lockedAt>>

Sch(k, def) == [op |-> "sch", key |-> k, def |-> def]
Can(k)      == [op |-> "can", key |-> k, def |-> FALSE]
CanAll      == [op |-> "all", key |-> "look", def |-> FALSE]
Emit(ops) == IF ops = <<>> THEN UNCHANGED effects ELSE effects' = effects \cup {ops}

AllFalse == [p \in P |-> FALSE]
Present == {p \in P : conn[p] # "gone"}
ReadyW2(ch) == (\A p \in P : conn[p] # "grace") /\ Present # {} /\ \A p \in Present : ch[p][2] >= 1
StageReady(rd) == Present # {} /\ \A p \in Present : rd[p]
VotesReady(lk) == (\A p \in P : lk[p]) \/ (Present # {} /\ \A p \in Present : lk[p])

(* ---- server transitions, inside a locked transaction ---- *)
OpenW1(pre) ==       \* start_night_phase -> _open_window(1); window 1 has a fixed length
  /\ phase' = "w1" /\ ready' = AllFalse
  /\ Emit(pre \o <<Can("look"), Sch("w1", FALSE)>>)
  /\ UNCHANGED <<outVars, voteVars>>
CloseW1(pre) ==      \* advance_wave(1): her follow-up (or its default), then open window 2
  /\ phase' = "w2" /\ ready' = AllFalse
  /\ resLook' = IF chose["d"][1] = 0 THEN resLook + 1 ELSE resLook
  /\ IF dCopied = "Robber"
       THEN resFollow' = resFollow + 1 /\ followSrc' = IF dStep # "none" THEN dStep ELSE "default"
       ELSE UNCHANGED <<resFollow, followSrc>>
  /\ Emit(pre \o <<Can("w1"), Sch("w2", FALSE)>>)
  /\ UNCHANGED <<resR, voteVars>>
CloseW2(pre) ==      \* advance_wave(2) -> transition_to_discussion
  /\ phase' = "talk" /\ ready' = AllFalse /\ resR' = resR + 1
  /\ Emit(pre \o <<Can("w2"), Sch("talk", FALSE)>>)
  /\ UNCHANGED <<resLook, resFollow, followSrc, voteVars>>
ToVote(pre) ==       \* end_discussion / transition_to_voting
  /\ phase' = "vote" /\ UNCHANGED ready
  /\ votes' = [p \in P |-> "none"] /\ locked' = AllFalse /\ lockedAt' = [p \in P |-> "none"]
  /\ Emit(pre \o <<Can("talk"), Sch("vote", FALSE)>>
              \o (IF conn["v"] = "grace" THEN <<Sch("grace", FALSE)>> ELSE <<>>))
  /\ UNCHANGED outVars
Reveal(pre) ==       \* reveal_votes
  /\ phase' = "results" /\ UNCHANGED ready
  /\ Emit(pre \o <<Can("vote"), CanAll>>)
  /\ UNCHANGED <<outVars, voteVars>>
Stay(pre) == UNCHANGED <<phase, ready, outVars, voteVars>> /\ Emit(pre)
CloseOrDefer(pre) == \* _close_or_defer in window 2: now, or a deferred close under the SAME key
  CloseW2(pre) \/ Stay(pre \o <<Sch("w2", TRUE)>>)
Evaluate(pre, c) ==  \* _evaluate_presence with connection state c
  LET pr == {p \in P : c[p] # "gone"}
      nograce == \A p \in P : c[p] # "grace"
  IN CASE phase = "w2" ->
            IF nograce /\ pr # {} /\ \A p \in pr : chose[p][2] >= 1 THEN CloseOrDefer(pre) ELSE Stay(pre)
       [] phase = "look" -> IF nograce /\ pr # {} /\ \A p \in pr : ready[p] THEN OpenW1(pre) ELSE Stay(pre)
       [] phase = "vote" ->
            IF (\A p \in P : locked[p]) \/ (pr # {} /\ \A p \in pr : locked[p]) THEN Reveal(pre) ELSE Stay(pre)
       [] OTHER -> Stay(pre)

Keep == UNCHANGED <<conn, dropped, rows, rowDef, snap, ensured>>

(* ---- requests naming the current stage ---- *)
\* night2.submit_choose: Game lock, stage check, count, read the picks, store, close check
Choose(p, intent, arg) ==
  LET w == IF phase = "w1" THEN 1 ELSE 2
      n == chose[p][w]
  IN /\ phase \in {"w1", "w2"}
     /\ IF n >= (IF w = 1 THEN 2 ELSE 1)
        THEN \* 409 already_chosen
             /\ fRefused' = (fRefused \/ intent = "followup")
             /\ Stay(<<>>) /\ UNCHANGED <<chose, dCopied, dStep>>
        ELSE LET ch == [chose EXCEPT ![p][w] = n + 1] IN
             /\ chose' = ch /\ UNCHANGED fRefused
             /\ IF p = "d" /\ w = 1 /\ n = 0
                  THEN dCopied' = RoleOf[arg] /\ UNCHANGED dStep        \* her look ("first other player")
                  ELSE IF p = "d" /\ w = 1 /\ n = 1 /\ dCopied = "Robber"
                  THEN dStep' = intent /\ UNCHANGED dCopied            \* read as the Robber: "first other player"
                  ELSE UNCHANGED <<dCopied, dStep>>
             /\ IF p = "d" /\ w = 1 /\ n = 0
                  THEN resLook' = resLook + 1 /\ UNCHANGED <<phase, ready, resFollow, resR, followSrc, voteVars>>
                       /\ UNCHANGED effects
                  ELSE IF w = 2 /\ ReadyW2(ch) THEN CloseOrDefer(<<>>)
                  ELSE Stay(<<>>)

PhoneChoose ==
  /\ \/ /\ phase = "w1" /\ chose["d"][1] = 0                    \* her look
           /\ \E t \in {"r", "v"} : Choose("d", "look", t) /\ UNCHANGED <<sentF, retried>>
     \/ /\ phase = "w1" /\ chose["d"][1] >= 1 /\ ~retried         \* the same look again: response lost
           /\ retried' = TRUE /\ Choose("d", "look", "r") /\ UNCHANGED sentF
           \* (the resent body names whoever she looked at; "r" is the case that matters)
     \/ /\ phase = "w1" /\ dCopied = "Robber" /\ ~sentF          \* her follow-up: rob v
           /\ sentF' = TRUE /\ Choose("d", "followup", "v") /\ UNCHANGED retried
     \/ \E p \in P : /\ phase \in {"w1", "w2"}
                     /\ (p # "d" \/ phase = "w2")
                     /\ chose[p][IF phase = "w1" THEN 1 ELSE 2] = 0
                     /\ Choose(p, "plain", "none") /\ UNCHANGED <<sentF, retried>>
  /\ Keep

\* services.set_ready (look: true only; talk)
Ready(p) ==
  /\ phase \in {"look", "talk"} /\ ~ready[p]
  /\ LET rd == [ready EXCEPT ![p] = TRUE] IN
     IF StageReady(rd) THEN IF phase = "look" THEN OpenW1(<<>>) ELSE ToVote(<<>>)
     ELSE ready' = rd /\ UNCHANGED <<phase, outVars, voteVars, effects>>
  /\ UNCHANGED phoneIn /\ Keep

\* services.submit_vote with lock=true (a pick changes nothing a rule here reads)
Lock(p) ==
  /\ phase = "vote" /\ ~locked[p]
  /\ LET lk == [locked EXCEPT ![p] = TRUE] IN
     /\ votes' = [votes EXCEPT ![p] = VoteFor[p]] /\ locked' = lk
     /\ lockedAt' = [lockedAt EXCEPT ![p] = VoteFor[p]]
     /\ IF VotesReady(lk)
          THEN phase' = "results" /\ Emit(<<Can("vote"), CanAll>>)
          ELSE UNCHANGED phase /\ UNCHANGED effects
     /\ UNCHANGED <<ready, outVars>>
  /\ UNCHANGED phoneIn /\ Keep

\* a late lock / pick after locking: 409 vote_locked, nothing stored
LateVote(p) == phase = "vote" /\ locked[p] /\ UNCHANGED vars

\* WaveAdvanceView / EndDiscussionView / ForceRevealView (host), naming the current stage
Host ==
  /\ \/ phase = "look" /\ OpenW1(<<>>)
     \/ phase = "w1" /\ CloseW1(<<>>)
     \/ phase = "w2" /\ CloseW2(<<>>)
     \/ phase = "talk" /\ ToVote(<<>>)
     \/ phase = "vote" /\ Reveal(<<>>)
  /\ UNCHANGED phoneIn /\ Keep

(* ---- after-commit effects ---- *)
ApplyOp(r, d, o) ==
  IF o.op = "sch" THEN <<[r EXCEPT ![o.key] = TRUE], [d EXCEPT ![o.key] = o.def]>>
  ELSE IF o.op = "can" THEN <<[r EXCEPT ![o.key] = FALSE], d>>
  ELSE <<[k \in Keys |-> FALSE], d>>                 \* cancel_all_for_game ("<id>:" keys, grace too)
RECURSIVE ApplyOps(_, _, _)
ApplyOps(r, d, ops) ==
  IF ops = <<>> THEN <<r, d>> ELSE LET x == ApplyOp(r, d, Head(ops)) IN ApplyOps(x[1], x[2], Tail(ops))
ApplyEffects ==
  \E b \in effects :
    LET x == ApplyOps(rows, rowDef, b) IN
    /\ rows' = x[1] /\ rowDef' = x[2] /\ effects' = effects \ {b}
    /\ UNCHANGED <<phase, ready, phoneIn, outVars, voteVars, conn, dropped, snap, ensured>>

(* ---- timers.fire ---- *)
Fire ==
  \E k \in Keys :
    /\ rows[k] /\ rows' = [rows EXCEPT ![k] = FALSE] /\ UNCHANGED rowDef
    /\ CASE k = "look" -> IF phase = "look" THEN OpenW1(<<>>) ELSE Stay(<<>>)
         [] k = "w1"   -> IF phase = "w1" THEN CloseW1(<<>>) ELSE Stay(<<>>)
         [] k = "w2"   -> IF phase # "w2" THEN Stay(<<>>)
                          ELSE IF ~rowDef[k] \/ ReadyW2(chose) THEN CloseW2(<<>>)
                          ELSE \/ CloseW2(<<>>)                     \* the deadline has passed too
                               \/ Stay(<<Sch("w2", FALSE)>>)        \* not ready: restore the deadline
         [] k = "talk" -> IF phase = "talk" THEN ToVote(<<>>) ELSE Stay(<<>>)
         [] k = "vote" -> IF phase = "vote" THEN Reveal(<<>>) ELSE Stay(<<>>)
         [] k = "grace" ->
              IF phase \notin {"look", "w1", "w2", "vote"} THEN Stay(<<>>)
              ELSE CASE conn["v"] = "grace" -> Stay(<<Sch("grace", FALSE)>>)   \* early: re-arm
                     [] conn["v"] = "gone"  -> Evaluate(<<>>, conn)
                     [] OTHER               -> Stay(<<>>)
    /\ UNCHANGED <<phoneIn, conn, dropped, snap, ensured>>

(* ---- v's phone ---- *)
Drop ==
  /\ conn["v"] = "on" /\ ~dropped /\ phase # "results"
  /\ conn' = [conn EXCEPT !["v"] = "grace"] /\ dropped' = TRUE
  /\ Stay(IF phase \in {"look", "w1", "w2", "vote"} THEN <<Sch("grace", FALSE)>> ELSE <<>>)
  /\ UNCHANGED <<phoneIn, rows, rowDef, snap, ensured>>
Tick ==
  /\ conn["v"] = "grace" /\ conn' = [conn EXCEPT !["v"] = "gone"]
  /\ UNCHANGED <<phase, ready, phoneIn, outVars, voteVars, dropped, rows, rowDef, effects, snap, ensured>>
Return ==   \* register_connection
  /\ conn["v"] # "on" /\ phase # "results"
  /\ LET c == [conn EXCEPT !["v"] = "on"] IN
     /\ conn' = c
     /\ IF phase \in {"look", "w1", "w2", "vote"} THEN Evaluate(<<Can("grace")>>, c) ELSE Stay(<<Can("grace")>>)
  /\ UNCHANGED <<phoneIn, dropped, rows, rowDef, snap, ensured>>

(* ---- GET /me/: unlocked snapshot, then ensure_timers from it ---- *)
MeRead ==
  /\ snap = "none" /\ ~ensured /\ phase # "results"
  /\ snap' = phase
  /\ UNCHANGED <<phase, ready, phoneIn, outVars, voteVars, conn, dropped, rows, rowDef, effects, ensured>>
MeEnsure ==
  /\ snap \in Stages /\ ~rows[snap]
  /\ rows' = [rows EXCEPT ![snap] = TRUE]
  /\ rowDef' = [rowDef EXCEPT ![snap] = (snap = "w2" /\ ReadyW2(chose))]
  /\ snap' = "none" /\ ensured' = TRUE
  /\ UNCHANGED <<phase, ready, phoneIn, outVars, voteVars, conn, dropped, effects>>
MeDone == snap \in Stages /\ rows[snap] /\ snap' = "none" /\ ensured' = TRUE
          /\ UNCHANGED <<phase, ready, phoneIn, outVars, voteVars, conn, dropped, rows, rowDef, effects>>

Done == phase = "results" /\ effects = {} /\ UNCHANGED vars

Init ==
  /\ phase = "look" /\ ready = AllFalse
  /\ chose = [p \in P |-> [w \in {1, 2} |-> 0]]
  /\ dCopied = "none" /\ dStep = "none" /\ sentF = FALSE /\ retried = FALSE /\ fRefused = FALSE
  /\ resLook = 0 /\ resFollow = 0 /\ resR = 0 /\ followSrc = "none"
  /\ votes = [p \in P |-> "none"] /\ locked = AllFalse /\ lockedAt = [p \in P |-> "none"]
  /\ conn = [p \in P |-> "on"] /\ dropped = FALSE
  /\ rows = [k \in Keys |-> k = "look"]  \* the deal scheduled the look backstop
  /\ rowDef = [k \in Keys |-> FALSE]
  /\ effects = {} /\ snap = "none" /\ ensured = FALSE

\* Bound: at most MaxPending committed transactions whose after-commit timer ops
\* have not run yet (in the code they run right after the commit, in the same thread).
MaxPending == 2
Room == Cardinality(effects) < MaxPending

ChooseStep == Room /\ PhoneChoose
ReadyStep == Room /\ \E p \in P : Ready(p)
LockStep == Room /\ \E p \in P : Lock(p) \/ LateVote(p)
HostStep == Room /\ Host
FireStep == Room /\ Fire
DropStep == Room /\ Drop
ReturnStep == Room /\ Return

Next ==
  \/ ChooseStep \/ ReadyStep \/ LockStep
  \/ HostStep \/ FireStep \/ DropStep \/ ReturnStep
  \/ ApplyEffects \/ Tick
  \/ MeRead \/ MeEnsure \/ MeDone
  \/ Done

Spec == Init /\ [][Next]_vars /\ WF_vars(ApplyEffects) /\ WF_vars(FireStep) /\ WF_vars(Tick)
                              /\ WF_vars(MeEnsure \/ MeDone)

(* ---- state equivalence (TLC VIEW) ----
   A timer row, or a pending op, for a stage the game has passed can only ever fire
   as a no-op (every job re-checks the phase under the Game lock, and phases never go
   back), so states that differ only in such rows / ops behave the same. rowDef only
   matters for a live w2 row. *)
Rank == [look |-> 0, w1 |-> 1, w2 |-> 2, talk |-> 3, vote |-> 4, results |-> 5, grace |-> 0]
Live(k) == k = "grace" \/ Rank[k] >= Rank[phase]
LiveOp(o) == o.op = "all" \/ Live(o.key)
NormEffects == {SelectSeq(b, LiveOp) : b \in effects} \ {<<>>}
NormView == <<phase, ready, phoneIn, outVars, voteVars, conn, dropped,
              [k \in Keys |-> rows[k] /\ Live(k)], rows["w2"] /\ Live("w2") /\ rowDef["w2"],
              NormEffects, snap, ensured>>

(* ---- rules ---- *)
ChooseLimit == \A p \in P : chose[p][1] <= 2 /\ chose[p][2] <= 1
AppliedAtMostOnce == resLook <= 1 /\ resFollow <= 1 /\ resR <= 1
AppliedExactlyOnce ==
  phase \in {"talk", "vote", "results"} =>
    resLook = 1 /\ resR = 1 /\ resFollow = (IF dCopied = "Robber" THEN 1 ELSE 0)
FollowUpFromFollowUpRequest == followSrc # "look"
FollowUpNotRefused == ~fRefused
LockedVoteKept == \A p \in P : locked[p] => votes[p] = lockedAt[p]
PhaseForward == [][phase' # phase => <<phase, phase'>> \in Allowed]_phase
ReachesResults == <>(phase = "results")
=============================================================================
