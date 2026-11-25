---------------------------- MODULE PhoneNight ----------------------------
(* ONE phone through the night of a protocol-2 game, against an abstract    *)
(* server that keeps the rules of api-contract-v2 "Third amendment".        *)
(* Modelled from (worktree agent-a20b3fb01011a67b0, commit a1eb6dd):        *)
(*  lib/features/game/presentation/protocol_two_game.dart (refresh loop,    *)
(*    _accept, _armHealing, _send, retry, choose), outbox.dart (afterFetch, *)
(*    on), design_system/night/choose_prompt.dart (turn, used,              *)
(*    afterChoose), night_board.dart (_sent, _failed, _sends,               *)
(*    didUpdateWidget), stage_requests.dart (ChooseRequest).                *)
(* Every await in that code is a point where any other step may happen:    *)
(*  a request is a message; its answer (or a timeout = notSent) is another  *)
(*  step; a /me/ fetch is send / server read / apply-or-fail.               *)
(* Stages: 0 look, 1 window 1, 2 window 2, 3 talk.                          *)
EXTENDS Naturals, FiniteSets

CONSTANTS ROLE,          \* "dopp" | "actor" | "sleeper"
          COPY,          \* what the Doppelganger copies: "Robber" | "Minion" | "Villager"
          SENDS_CHOSEN,  \* the app puts `chosen` in the choose body (the pending line)
          FIXED_SERVER,  \* the server after fb229fb (chosen required)
          FIX_RETRY,     \* proposed: a failed /me/ is retried with backoff also after the first load
          FIX_TURN,      \* proposed: turn and used read from chooses_left (server 0f1f309)
          ANSWER_CARRIES, \* night-result-now: a taken choose answers the caller's results and
                         \* chooses_left; the phone re-reads /me/ only when that is above 0
          MaxFaults, MaxRestarts, MaxTaps

Keys == {<<1, 0>>, <<1, 1>>, <<2, 0>>}
NoItem == [id |-> 0, key |-> <<>>, st |-> 0, echo |-> 0, turn |-> 0, tap |-> 0, leg |-> "none"]
MaxCh(w) == IF w = 1 THEN 2 ELSE 1

VARIABLES
  sv, cnt, copied, stored, badStore,  \* server: stage, chooses per window, her copy, what was stored
  reqs, reps,                         \* requests on their way to the server; answers on their way back
  inst, loaded, snap, cur, conts,     \* phone memory (lost on restart): /me/, the choose lane, awaits
  fq, fv, fc, again, retryArmed,      \* the /me/ fetch loop
  bKey, bSent, bFailed,               \* the night board widget
  ev, intent, taps, ids, faults, restarts

server == <<sv, cnt, copied, stored, badStore>>
fetch == <<fq, fv, fc, again, retryArmed>>
board == <<bKey, bSent, bFailed>>
vars == <<sv, cnt, copied, stored, badStore, reqs, reps, inst, loaded, snap, cur, conts,
          fq, fv, fc, again, retryArmed, bKey, bSent, bFailed, ev, intent, taps, ids, faults, restarts>>

(* ---- what the server's /me/ says (engine/choose.py build_choose_prompt) ---- *)
Acting(w, cop) ==
  CASE ROLE = "dopp" -> IF w = 1 /\ ~cop THEN "Doppelganger"
                        ELSE IF w = 1 /\ COPY \in {"Robber", "Minion"} THEN COPY ELSE "None"
    [] ROLE = "actor" -> IF w = 2 THEN "Seer" ELSE "None"
    [] OTHER -> "None"
KindOf(a) == CASE a = "Doppelganger" -> "look" [] a \in {"Robber", "Seer"} -> "act" [] OTHER -> "none"
View(s, c, cop) ==
  IF s \in {1, 2}
  THEN LET a == Acting(s, cop)
           ch == c[s]
           e == IF s = 1 /\ ch >= 1 /\ a # "None" THEN 2 ELSE 1
       IN [st |-> s, ch |-> ch, kind |-> KindOf(a), cl |-> IF e > ch THEN e - ch ELSE 0]
  ELSE [st |-> s, ch |-> 0, kind |-> "-", cl |-> 0]

(* ---- what the app reads from it (choose_prompt.dart, outbox.dart) ---- *)
HasPrompt(v) == v.st \in {1, 2}
Turn(v) == IF FIX_TURN THEN (IF v.cl > 0 THEN v.ch ELSE (IF v.ch > 0 THEN v.ch - 1 ELSE 0))
           ELSE IF v.st = 1 /\ v.kind \notin {"look", "none"} THEN 1 ELSE 0
Used(v) == v.ch > Turn(v)
Key(v) == IF HasPrompt(v) THEN <<v.st, Turn(v)>> ELSE <<v.st, 9>>
\* Outbox.on: the tap shown for its own stage and turn (afterChoose)
Me(v, c) == IF HasPrompt(v) /\ c.id # 0 /\ c.key = Key(v) /\ ~Used(v)
            THEN [v EXCEPT !.ch = Turn(v) + 1, !.cl = 0] ELSE v
\* Outbox.afterFetch
AfterFetch(c, v, f) ==
  IF c.id = 0 THEN c ELSE IF c.key # Key(v) \/ (c.leg = "conf" /\ f = c.id) THEN NoItem ELSE c
ConfId(c) == IF c.id # 0 /\ c.leg = "conf" THEN c.id ELSE 0

(* ---- the board widget follows the state (initState / didUpdateWidget) ---- *)
BoardNext(ld, v, c) ==
  LET m == Me(v, c) IN
  IF ~ld \/ ~HasPrompt(m) THEN [k |-> <<>>, s |-> "none", f |-> FALSE, reset |-> bKey # <<>>]
  ELSE IF Key(m) # bKey
       THEN [k |-> Key(m), s |-> IF Used(m) THEN "used" ELSE "none", f |-> FALSE, reset |-> TRUE]
       ELSE [k |-> bKey, s |-> IF bSent = "none" /\ Used(m) THEN "used" ELSE bSent, f |-> bFailed,
             reset |-> FALSE]
NotCurrent(cs) == {[x EXCEPT !.b = FALSE] : x \in cs}
\* set the phone's state; the board rebuilds from it
Show(ld, v, c, cs) ==
  LET b == BoardNext(ld, v, c) IN
  /\ loaded' = ld /\ snap' = v /\ cur' = c
  /\ bKey' = b.k /\ bSent' = b.s /\ bFailed' = b.f
  /\ conts' = IF b.reset THEN NotCurrent(cs) ELSE cs

(* refresh(): one fetch at a time; a request meanwhile runs once after it *)
Refresh(c) ==
  IF fq # "none" THEN /\ again' = TRUE /\ UNCHANGED <<fq, fc>>
  ELSE /\ fq' = "sent" /\ again' = FALSE /\ fc' = ConfId(c)
LoopEnds(cs) == {IF x.k = "rwait" THEN [x EXCEPT !.done = TRUE] ELSE x : x \in cs}

(* ---------------- server ---------------- *)
SAdvance ==
  /\ sv < 3 /\ sv' = sv + 1 /\ ev' = TRUE
  /\ UNCHANGED <<cnt, copied, stored, badStore, reqs, reps, inst, loaded, snap, cur, conts, fetch,
                 board, intent, taps, ids, faults, restarts>>

SProcess(r) ==
  LET w == sv
      c == IF w \in {1, 2} THEN cnt[w] ELSE 0
      ans == IF r.st # sv THEN "stale"                                  \* 409 wrong_stage
             ELSE IF ~SENDS_CHOSEN
                  THEN IF FIXED_SERVER THEN "refused"                  \* 400: chosen is required
                       ELSE IF c >= MaxCh(w) THEN "stale" ELSE "store"
             ELSE IF r.echo < c THEN "taken"                           \* a resend: 200, nothing stored
             ELSE IF r.echo > c THEN "refused"                         \* 400
             ELSE IF c >= MaxCh(w) THEN "stale"                        \* 409 already_chosen
             ELSE "store"
  IN /\ reqs' = reqs \ {r}
     /\ IF ans = "store"
        THEN /\ cnt' = [cnt EXCEPT ![w] = c + 1]
             /\ stored' = stored \cup {[w |-> w, idx |-> c, turn |-> r.turn, tap |-> r.tap]}
             /\ copied' = (copied \/ (ROLE = "dopp" /\ w = 1 /\ c = 0))
             /\ badStore' = (badStore \/ r.turn # c)
        ELSE UNCHANGED <<cnt, stored, copied, badStore>>
     \* the answer's chooses_left: the prompt as the server holds it after this request
     /\ reps' = IF r.live /\ r.inst = inst
                THEN reps \cup {[id |-> r.id, ans |-> IF ans = "store" THEN "taken" ELSE ans,
                                 cl |-> View(sv, cnt', copied').cl]}
                ELSE reps
     /\ UNCHANGED <<sv, inst, loaded, snap, cur, conts, fetch, board, ev, intent, taps, ids, faults, restarts>>

FetchServe ==
  /\ fq = "sent" /\ fq' = "served" /\ fv' = View(sv, cnt, copied)
  /\ UNCHANGED <<server, reqs, reps, inst, loaded, snap, cur, conts, fc, again, retryArmed, board,
                 ev, intent, taps, ids, faults, restarts>>

\* _accept: drop a reply of an earlier stage; afterFetch; the board rebuilds
FetchApply ==
  /\ fq = "served"
  /\ LET behind == loaded /\ fv.st < snap.st
         c2 == IF behind THEN cur ELSE AfterFetch(cur, fv, fc)
         cs == IF again THEN conts ELSE LoopEnds(conts)
     IN /\ IF behind THEN /\ conts' = cs /\ UNCHANGED <<loaded, snap, cur, board>>
           ELSE Show(TRUE, fv, c2, cs)
        /\ IF again THEN /\ fq' = "sent" /\ again' = FALSE /\ fc' = ConfId(c2)
           ELSE /\ fq' = "none" /\ UNCHANGED <<again, fc>>
        /\ retryArmed' = (retryArmed /\ behind)
  /\ UNCHANGED <<server, reqs, reps, inst, fv, ev, intent, taps, ids, faults, restarts>>

\* the fetch fails (no answer, 5xx): before the first load a retry with backoff
\* is armed; after it only the deadline heal (_armHealing(current.server))
FetchFail ==
  /\ fq \in {"sent", "served"} /\ faults < MaxFaults /\ faults' = faults + 1
  /\ retryArmed' = (retryArmed \/ ~loaded \/ FIX_RETRY)
  /\ IF again THEN /\ fq' = "sent" /\ again' = FALSE /\ fc' = ConfId(cur) /\ UNCHANGED conts
     ELSE /\ fq' = "none" /\ UNCHANGED <<again, fc>> /\ conts' = LoopEnds(conts)
  /\ UNCHANGED <<server, reqs, reps, inst, loaded, snap, cur, fv, board, ev, intent, taps, ids, restarts>>

RetryFire ==
  /\ retryArmed /\ retryArmed' = FALSE /\ Refresh(cur)
  /\ UNCHANGED <<server, reqs, reps, inst, loaded, snap, cur, conts, fv, board, ev, intent, taps, ids,
                 faults, restarts>>

\* the stage's deadline has passed (the server moved on): one fetch, then polls
Heal ==
  /\ loaded /\ snap.st < sv /\ fq = "none" /\ Refresh(cur)
  /\ UNCHANGED <<server, reqs, reps, inst, loaded, snap, cur, conts, fv, retryArmed, board, ev, intent,
                 taps, ids, faults, restarts>>

\* a socket event (night_window / phase_change) asks for /me/; or it is dropped
EvDeliver ==
  /\ ev /\ ev' = FALSE /\ Refresh(cur)
  /\ UNCHANGED <<server, reqs, reps, inst, loaded, snap, cur, conts, fv, retryArmed, board, intent,
                 taps, ids, faults, restarts>>
EvDrop == ev /\ ev' = FALSE /\ UNCHANGED <<server, reqs, reps, inst, loaded, snap, cur, conts, fetch, board,
                                           intent, taps, ids, faults, restarts>>
\* app resume / socket reconnect: fetch
\* (counted with the faults, so that it cannot happen forever)
Resume ==
  /\ loaded /\ faults < MaxFaults /\ faults' = faults + 1 /\ Refresh(cur)
  /\ UNCHANGED <<server, reqs, reps, inst, loaded, snap, cur, conts, fv, retryArmed, board, ev, intent,
                 taps, ids, restarts>>

(* ---------------- taps ---------------- *)
\* notifier.choose(stage, picks), synchronously up to its first await; cs = the
\* awaits with the board's earlier sends made not current
Choose(cs, tap) ==
  LET k == Key(snap) IN
  IF cur.id # 0 /\ cur.key = k
  THEN IF cur.leg = "unsent"
       THEN \* retry(lane): fetch first, then look
            /\ conts' = cs \cup {[k |-> "rwait", id |-> cur.id, b |-> TRUE, done |-> FALSE]}
            /\ Refresh(cur) /\ UNCHANGED <<cur, reqs, ids>>
       ELSE /\ conts' = cs /\ UNCHANGED <<cur, reqs, ids, fq, fc, again>>  \* Declined: alreadyChosen
  ELSE IF Used(snap)
       THEN /\ conts' = cs /\ UNCHANGED <<cur, reqs, ids, fq, fc, again>>   \* Declined
       ELSE /\ ids' = ids + 1
            /\ cur' = [id |-> ids + 1, key |-> k, st |-> snap.st, echo |-> snap.ch, turn |-> Turn(snap),
                       tap |-> tap, leg |-> "flight"]
            /\ reqs' = reqs \cup {[id |-> ids + 1, inst |-> inst, st |-> snap.st, echo |-> snap.ch,
                                   turn |-> Turn(snap), tap |-> tap, live |-> TRUE]}
            /\ conts' = cs \cup {[k |-> "send", id |-> ids + 1, b |-> TRUE, done |-> FALSE]}
            /\ UNCHANGED <<fq, fc, again>>

\* the player picks cards and taps Choose: "Chosen" at once
TapChoose ==
  /\ loaded /\ bKey \in Keys /\ bSent = "none" /\ taps < MaxTaps
  /\ taps' = taps + 1 /\ intent' = [intent EXCEPT ![bKey] = taps + 1]
  /\ bSent' = "tap" /\ UNCHANGED <<bKey, bFailed>>
  /\ Choose(NotCurrent(conts), taps + 1)
  /\ UNCHANGED <<server, reps, inst, loaded, snap, fv, retryArmed, ev, faults, restarts>>

\* "Not sent." -> "Try again" (the board calls onChoose again with its picks)
TapTryAgain ==
  /\ loaded /\ bKey \in Keys /\ bFailed /\ bSent # "none"
  /\ bFailed' = FALSE /\ UNCHANGED <<bKey, bSent, taps, intent>>
  /\ Choose(NotCurrent(conts), intent[bKey])
  /\ UNCHANGED <<server, reps, inst, loaded, snap, fv, retryArmed, ev, faults, restarts>>

(* ---------------- answers ---------------- *)
\* _send after `await _service.send`, then the board's .then
\* cl: the answer's chooses_left (ANSWER_CARRIES); a taken answer with 0 left needs no
\* /me/: the item stays confirming (its results shown) until a later fetch
Answer(c0, ans, cl, reps2, reqs2) ==
  LET match == cur.id = c0.id
      c2 == IF ~match THEN cur
            ELSE CASE ans \in {"taken", "stale"} -> [cur EXCEPT !.leg = "conf"]
                   [] ans = "refused" -> NoItem
                   [] OTHER -> [cur EXCEPT !.leg = "unsent"]
      b == BoardNext(loaded, snap, c2)
      bs == IF c0.b /\ ans = "refused" THEN (IF Used(Me(snap, c2)) THEN "used" ELSE "none") ELSE b.s
      cs == conts \ {c0}
  IN /\ reps' = reps2 /\ reqs' = reqs2
     /\ cur' = c2 /\ bKey' = b.k /\ bSent' = bs
     /\ bFailed' = (b.f \/ (c0.b /\ ~b.reset /\ ans = "notSent"))
     /\ conts' = IF b.reset THEN NotCurrent(cs) ELSE cs
     /\ IF match /\ ans \in {"taken", "stale"} /\ ~(ANSWER_CARRIES /\ ans = "taken" /\ cl = 0)
        THEN Refresh(c2) ELSE UNCHANGED <<fq, fc, again>>
     /\ UNCHANGED <<server, inst, loaded, snap, fv, retryArmed, ev, intent, taps, ids, restarts>>

Reply ==
  \E r \in reps, c0 \in conts :
    /\ c0.k = "send" /\ c0.id = r.id
    /\ Answer(c0, r.ans, r.cl, reps \ {r}, reqs) /\ UNCHANGED faults

\* no answer in time (receiveTimeout): notSent. The request may still arrive
\* later (delayed), or never (lost); an answer already on its way is lost.
Timeout ==
  \E c0 \in conts :
    /\ c0.k = "send" /\ faults < MaxFaults /\ faults' = faults + 1
    /\ \E lose \in BOOLEAN :
         Answer(c0, "notSent", 0, {x \in reps : x.id # c0.id},
                {IF x.id = c0.id /\ x.inst = inst THEN [x EXCEPT !.live = FALSE] ELSE x :
                   x \in {y \in reqs : ~(lose /\ y.id = c0.id /\ y.inst = inst)}})

\* retry(lane), after `await refresh()`
RwaitResume ==
  \E c0 \in conts :
    /\ c0.k = "rwait" /\ c0.done
    /\ LET cs == conts \ {c0} IN
       IF cur.id # c0.id \/ cur.leg # "unsent"
       THEN /\ conts' = cs /\ UNCHANGED <<cur, reqs, board>>          \* Declined: the board does nothing
       ELSE IF HasPrompt(snap) /\ snap.st = cur.st /\ snap.ch > cur.echo
       THEN /\ Show(loaded, snap, [cur EXCEPT !.leg = "conf"], cs)       \* Landed
            /\ UNCHANGED reqs
       ELSE /\ cur' = [cur EXCEPT !.leg = "flight"]                     \* the ORIGINAL again
            /\ reqs' = reqs \cup {[id |-> cur.id, inst |-> inst, st |-> cur.st, echo |-> cur.echo,
                                   turn |-> cur.turn, tap |-> cur.tap, live |-> TRUE]}
            /\ conts' = cs \cup {[c0 EXCEPT !.k = "send", !.done = FALSE]}
            /\ UNCHANGED board
    /\ UNCHANGED <<server, reps, inst, loaded, snap, fetch, ev, intent, taps, ids, faults, restarts>>

(* ---------------- restart: memory gone, the app loads again ---------------- *)
Restart ==
  /\ restarts < MaxRestarts /\ restarts' = restarts + 1 /\ inst' = inst + 1
  /\ loaded' = FALSE /\ snap' = View(0, cnt, FALSE) /\ cur' = NoItem /\ conts' = {}
  /\ fq' = "sent" /\ again' = FALSE /\ fc' = 0 /\ retryArmed' = FALSE
  /\ bKey' = <<>> /\ bSent' = "none" /\ bFailed' = FALSE /\ ev' = FALSE /\ reps' = {}
  /\ UNCHANGED <<server, reqs, fv, intent, taps, ids, faults>>

Done ==
  /\ sv = 3 /\ loaded /\ snap.st = 3 /\ fq = "none" /\ conts = {} /\ reqs = {} /\ reps = {}
  /\ ~ev /\ ~retryArmed
  /\ UNCHANGED vars

Init ==
  /\ sv = 0 /\ cnt = [w \in {1, 2} |-> 0] /\ copied = FALSE /\ stored = {} /\ badStore = FALSE
  /\ reqs = {} /\ reps = {}
  /\ inst = 0 /\ loaded = FALSE /\ snap = View(0, cnt, FALSE) /\ cur = NoItem /\ conts = {}
  /\ fq = "sent" /\ fv = View(0, cnt, FALSE) /\ fc = 0 /\ again = FALSE /\ retryArmed = FALSE
  /\ bKey = <<>> /\ bSent = "none" /\ bFailed = FALSE
  /\ ev = FALSE /\ intent = [k \in Keys |-> 0] /\ taps = 0 /\ ids = 0 /\ faults = 0 /\ restarts = 0

SProcessStep == \E r \in reqs : SProcess(r)

Next ==
  \/ SAdvance \/ SProcessStep
  \/ FetchServe \/ FetchApply \/ FetchFail \/ RetryFire \/ Heal
  \/ EvDeliver \/ EvDrop \/ Resume
  \/ TapChoose \/ TapTryAgain
  \/ Reply \/ Timeout \/ RwaitResume
  \/ Restart \/ Done

\* Server and phone internals are fair; the player, the timers that close a
\* window, socket events, faults and restarts are not.
Spec == Init /\ [][Next]_vars
        /\ WF_vars(SProcessStep) /\ WF_vars(FetchServe) /\ WF_vars(FetchApply)
        /\ WF_vars(RetryFire) /\ WF_vars(Heal) /\ WF_vars(Reply) /\ WF_vars(RwaitResume)

(* ---------------- rules ---------------- *)
\* the server never stores a choose built for another turn than the one it is stored as
StoredAsIntended == ~badStore
\* never two for one turn from one phone
ServerTurns1 == IF ROLE = "dopp" /\ COPY \in {"Robber", "Minion"} THEN 2 ELSE 1
OnePerTurn == cnt[1] <= ServerTurns1 /\ cnt[2] <= 1
\* the board never says "Chosen" by itself (from /me/) while the server still
\* expects a choose from this phone (chooses_left > 0)
NoChosenForUnusedTurn == (loaded /\ bKey \in Keys /\ bSent = "used") => snap.cl = 0
\* what the server stored for a turn is the player's latest tap for it
StoredIsLatestTap == \A s \in stored : <<s.w, s.turn>> \in Keys => intent[<<s.w, s.turn>>] = s.tap

\* while window 1 is open after her look, her board does not stay at "Chosen":
\* it is armed (the follow-up; or the look again after a restart, whose resend
\* arms the follow-up), or she is told "Not sent"
FollowUpArmed ==
  (ROLE = "dopp" /\ COPY \in {"Robber", "Minion"}) =>
    ((sv = 1 /\ cnt[1] = 1) ~> (sv # 1 \/ cnt[1] = 2 \/ bFailed \/
                                 (loaded /\ bKey \in Keys /\ bSent = "none")))
\* "Chosen" from a tap is never shown for good while the server has nothing for it
ChosenNotForever ==
  \A k \in Keys :
    (loaded /\ bKey = k /\ bSent = "tap" /\ sv = k[1] /\ cnt[k[1]] <= k[2])
      ~> (cnt[k[1]] > k[2] \/ sv # k[1] \/ bKey # k \/ bSent = "none" \/ bFailed)
\* the screen ends at the server's stage
Converges == <>[](loaded /\ snap.st = sv)
=============================================================================
