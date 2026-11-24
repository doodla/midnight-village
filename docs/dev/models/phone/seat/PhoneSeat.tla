----------------------------- MODULE PhoneSeat -----------------------------
(* ONE guest phone and where it sits, from 02 through a game, play again and  *)
(* the next deal: the events that move it (game_started on the lobby socket,  *)
(* game_results and play_again on the game socket), /me/table/ reads (all of  *)
(* them asked through askWhere), the lobby's reads and the phone's own player *)
(* list, the game's /me/ (refused to a phone not in the game), the phone      *)
(* leaving, a socket that opens, drops and comes back, the phone asleep, the  *)
(* app coming back. Modelled from branch start-lands-fast (on e48d802):       *)
(* where_am_i_provider.dart (myTable, SeatSeed, seatFromServer, askWhere),    *)
(* lobby_seat.dart and lobby_notifier.dart (build, refreshLobby, the          *)
(* connection listener, _askWhereIfMoved, _applyStartedGame, _seatIn),        *)
(* live_game.dart (apply, _seatBackAtTable, _onConnection, _compareTable,     *)
(* the 403).                                                                  *)
(*                                                                            *)
(* The server's table is a version: 0 waiting, 1 game 1, 2 game 1 finished,   *)
(* 3 waiting again (play again), 4 game 2; NoTable once this phone has left.  *)
EXTENDS Naturals, Sequences

CONSTANTS
  FIX_SEED,    \* an event that says where the phone sits is its seat (no read)
  FIX_LATE,    \* ... unless the table the phone holds already names that game
  FIX_HEAL,    \* a lobby read again saying "in a game", and the socket or the
               \* app coming back at 02, ask /me/table/ at once
  FIX_UP,      \* a socket's first opening reads what its screen depends on,
               \* as a socket coming back does: /me/table/ (and 02 its lobby).
               \* It is also what confirms a seat taken from an event: the
               \* seat always opens a new socket.
  FIX_403,     \* a /me/ refused (not a player) asks /me/table/
  DROP_STALE,  \* a /me/table/ read out when a newer one is asked for is
               \* dropped (Riverpod keeps only the newest build's answer)
  MaxDrops, MaxResumes, MaxFails

NoTable == 50
Kind(v) == CASE v \in {0, 3} -> "waiting" [] v \in {1, 4} -> "game"
             [] v = 2 -> "finished" [] OTHER -> "none"
\* the socket the phone listens to at what it shows (one game's socket per game)
Src(v) == CASE Kind(v) = "waiting" -> "lobby" [] v \in {1, 2} -> "game1"
               [] v = 4 -> "game2" [] OTHER -> "none"
\* the game a table names (its newest game this player plays in): the game id
GameOf(v) == CASE v \in {1, 2, 3} -> 1 [] v = 4 -> 2 [] OTHER -> 0
None == 99       \* (not a version)
Sent == 98
Forbidden == 97  \* /me/ refused: not a player of this game
LNone == [v |-> None, m |-> FALSE]   \* the lobby read: none out
LSent == [v |-> Sent, m |-> FALSE]   \* ... out

VARIABLES
  srv,      \* the server's table
  member,   \* the server has this phone at the table
  left,     \* it has left (once)
  up,       \* the phone's socket is connected (listened to by the server)
  opening,  \* ... and it is a new socket, not up yet for the first time
  chan,     \* events on their way to the phone, in order
  tab,      \* the table the phone shows (/me/table/'s held value)
  reads,    \* /me/table/ reads out: [cur, v] (cur: the newest; v = Sent until served)
  judge,    \* askWhere(settledBy:): the newest read out is judged when it lands
  lq,       \* the lobby read: None, Sent, or what it was served: [v, m]
  lwhy,     \* why it was read: "mount" (02 opens) or "again"
  lmem,     \* the phone's own player list has it at the table
  mq,       \* the game's /me/ read: None, Sent, Forbidden, or the served version
  drops, resumes, fails

vars == <<srv, member, left, up, opening, chan, tab, reads, judge, lq, lwhy, lmem,
          mq, drops, resumes, fails>>
Truth == IF member THEN srv ELSE NoTable

(* ---------------- the phone's moves ---------------- *)
\* (Reads are not numbered: only "newest or not" decides what the app does with
\* an answer. With DROP_STALE an older read can change nothing and is let go.)
Older == IF DROP_STALE THEN {} ELSE {[cur |-> FALSE, v |-> r.v] : r \in reads}
NewRead == Older \cup {[cur |-> TRUE, v |-> Sent]}
\* askWhere(ref): a new read replaces the one out
Ask == reads' = NewRead /\ judge' = FALSE
\* askWhere(settledBy: moved on): a read out now is judged when it lands
AskJudged == IF \E r \in reads : r.cur THEN judge' = TRUE /\ UNCHANGED reads ELSE Ask
\* the app coming back (myTable's own resume): a read out answers it
AskJoin == IF \E r \in reads : r.cur THEN UNCHANGED <<reads, judge>> ELSE Ask
\* What the phone shows becomes v. A screen on another socket opens it (not
\* listened to until up) and reads at once: 02 its lobby, a game its /me/.
Show(v) == /\ tab' = v
           /\ IF Src(v) # Src(tab) /\ Src(v) # "none" THEN up' = FALSE /\ opening' = TRUE
              ELSE UNCHANGED <<up, opening>>
           /\ IF Kind(v) = "waiting" /\ Kind(tab) # "waiting"
              THEN lq' = LSent /\ lwhy' = "mount"
              ELSE UNCHANGED <<lq, lwhy>>
           /\ IF Kind(v) \in {"game", "finished"} /\ Src(v) # Src(tab) THEN mq' = Sent
              ELSE UNCHANGED mq
\* seatFromServer: the seat is put; a read out is dropped
Seed(v) == /\ reads' = Older /\ judge' = FALSE /\ Show(v)

(* ---------------- server ---------------- *)
\* an event reaches the phone only on a socket that is up and listened to
Emit(src, v) == IF up /\ Src(tab) = src THEN chan' = Append(chan, [src |-> src, v |-> v])
                ELSE UNCHANGED chan
Ph == <<member, left, up, opening, tab, reads, judge, lq, lwhy, lmem, mq, drops, resumes, fails>>
Deal == /\ Kind(srv) = "waiting" /\ srv' = srv + 1 /\ Emit("lobby", srv + 1) /\ UNCHANGED Ph
End == /\ srv = 1 /\ srv' = 2 /\ Emit("game1", 2) /\ UNCHANGED Ph
PlayAgain == /\ srv = 2 /\ srv' = 3 /\ Emit("game1", 3) /\ UNCHANGED Ph
\* the player taps Leave at 02: answered, so the server has it off the table; the
\* answer reads /me/table/ (settle), and player_left reads the lobby again
Leave == /\ member /\ ~left /\ Kind(tab) = "waiting" /\ Kind(srv) = "waiting"
         /\ member' = FALSE /\ left' = TRUE
         /\ Ask /\ lq' = LSent /\ lwhy' = "again"
         /\ UNCHANGED <<srv, up, opening, chan, tab, lmem, mq, drops, resumes, fails>>

(* ---------------- events in ---------------- *)
Deliver ==
  /\ chan # <<>>
  /\ LET e == Head(chan) IN
     /\ chan' = Tail(chan)
     /\ IF e.src # Src(tab)
        THEN UNCHANGED <<up, opening, tab, reads, judge, lq, lwhy, mq>>   \* that socket is closed
        ELSE IF e.src = "lobby"                                        \* game_started
             THEN IF ~FIX_SEED THEN Ask /\ UNCHANGED <<up, opening, tab, lq, lwhy, mq>>
                  ELSE IF FIX_LATE /\ GameOf(tab) = GameOf(e.v)        \* _alreadyIn(id)
                       THEN UNCHANGED <<up, opening, tab, reads, judge, lq, lwhy, mq>>
                  ELSE IF lmem THEN Seed(e.v)                          \* seatedAt(own list)
                  ELSE Ask /\ UNCHANGED <<up, opening, tab, lq, lwhy, mq>>
        ELSE IF e.v = 3 /\ FIX_SEED /\ Kind(tab) = "finished"         \* play_again at the end
             THEN Seed(e.v)
        ELSE Ask /\ UNCHANGED <<up, opening, tab, lq, lwhy, mq>>       \* game_results; play_again elsewhere
  /\ UNCHANGED <<srv, member, left, lmem, drops, resumes, fails>>

(* ---------------- reads ---------------- *)
ServeTable == \E r \in reads :
  /\ r.v = Sent /\ reads' = (reads \ {r}) \cup {[r EXCEPT !.v = Truth]}
  /\ UNCHANGED <<srv, member, left, up, opening, chan, tab, judge, lq, lwhy, lmem, mq,
                 drops, resumes, fails>>
\* the newest read's answer is shown; judged (askWhere settledBy) and still
\* "waiting": asked again
ApplyTable == \E r \in reads :
  /\ r.v # Sent
  /\ IF r.cur \/ ~DROP_STALE
     THEN /\ Show(r.v)
          /\ IF r.cur /\ judge /\ Kind(r.v) = "waiting"
             THEN /\ reads' = (IF DROP_STALE THEN {}
                               ELSE {[cur |-> FALSE, v |-> x.v] : x \in reads \ {r}})
                              \cup {[cur |-> TRUE, v |-> Sent]}
                  /\ judge' = FALSE
             ELSE reads' = reads \ {r} /\ judge' = (judge /\ ~r.cur)
     ELSE reads' = reads \ {r} /\ UNCHANGED <<up, opening, tab, judge, lq, lwhy, mq>>
  /\ UNCHANGED <<srv, member, left, chan, lmem, drops, resumes, fails>>
ServeLobby == /\ lq = LSent /\ lq' = [v |-> srv, m |-> member]
              /\ UNCHANGED <<srv, member, left, up, opening, chan, tab, reads, judge, lwhy,
                             lmem, mq, drops, resumes, fails>>
\* a lobby read that fails: the phone keeps its own (older) player list
\* meanwhile, and reads again after a backoff (`_healRead`, main's #187): the
\* read stays asked for, and is served later
LobbyFails == /\ lq = LSent /\ fails < MaxFails /\ fails' = fails + 1
              /\ UNCHANGED <<srv, member, left, up, opening, chan, tab, reads, judge, lq,
                             lwhy, lmem, mq, drops, resumes>>
\* the lobby says the table is past waiting and the phone knows no game of it:
\* the first read (build) did so before too (current-game); a read again only
\* with FIX_HEAL (_askWhereIfMoved)
ApplyLobby ==
  /\ lq \notin {LNone, LSent} /\ lq' = LNone /\ lmem' = lq.m /\ UNCHANGED lwhy
  /\ IF Kind(tab) = "waiting" /\ Kind(lq.v) # "waiting" /\ (lwhy = "mount" \/ FIX_HEAL)
     THEN AskJudged ELSE UNCHANGED <<reads, judge>>
  /\ UNCHANGED <<srv, member, left, up, opening, chan, tab, mq, drops, resumes, fails>>
\* the game's /me/: refused to a phone not in the game; further on than the
\* table the phone holds: the table is read (_compareTable)
ServeMe == /\ mq = Sent
           /\ mq' = IF ~member THEN Forbidden ELSE IF GameOf(tab) = 1 /\ srv > 2 THEN 2 ELSE srv
           /\ UNCHANGED <<srv, member, left, up, opening, chan, tab, reads, judge, lq, lwhy,
                          lmem, drops, resumes, fails>>
ApplyMe == /\ mq \notin {None, Sent} /\ mq' = None
           /\ IF mq = Forbidden THEN (IF FIX_403 THEN Ask ELSE UNCHANGED <<reads, judge>>)
              ELSE IF Kind(tab) = "game" /\ mq > tab THEN Ask ELSE UNCHANGED <<reads, judge>>
           /\ UNCHANGED <<srv, member, left, up, opening, chan, tab, lq, lwhy, lmem, drops,
                          resumes, fails>>
\* in a game every stage has a deadline, and past it the phone reads /me/ until
\* the stage changes (the day model's FIX_HEAL): a player whose game is behind
\* reads the table; a phone not in the game is refused every time
GameHeals == /\ Kind(tab) = "game" /\ reads = {} /\ mq = None
             /\ IF member THEN srv # tab ELSE FIX_403
             /\ Ask
             /\ UNCHANGED <<srv, member, left, up, opening, chan, tab, lq, lwhy, lmem, mq,
                            drops, resumes, fails>>

(* ---------------- the socket and the app ---------------- *)
Drop == /\ up /\ drops < MaxDrops /\ drops' = drops + 1
        /\ up' = FALSE /\ chan' = <<>>
        /\ UNCHANGED <<srv, member, left, opening, tab, reads, judge, lq, lwhy, lmem, mq,
                       resumes, fails>>
\* the socket is up (a game's only for a player of it). Back after a drop: 02
\* reads its lobby (whose judged rule asks the table); a game or the end asks
\* the table. Up for the first time: the same with FIX_UP; before it, nothing.
Back == /\ ~up /\ Src(tab) # "none" /\ (Src(tab) = "lobby" \/ member)
        /\ up' = TRUE /\ opening' = FALSE
        /\ IF opening
           THEN IF ~FIX_UP THEN UNCHANGED <<reads, judge, lq, lwhy>>
                ELSE IF Kind(tab) = "waiting"
                THEN lq' = LSent /\ lwhy' = "again" /\ UNCHANGED <<reads, judge>>
                ELSE Ask /\ UNCHANGED <<lq, lwhy>>
           ELSE IF Kind(tab) = "waiting"
                \* 02: the lobby read asks (judged) if the table moved on; before
                \* FIX_HEAL that read was not judged at all (ApplyLobby)
                THEN lq' = LSent /\ lwhy' = "again" /\ UNCHANGED <<reads, judge>>
                ELSE Ask /\ UNCHANGED <<lq, lwhy>>
        /\ UNCHANGED <<srv, member, left, chan, tab, lmem, mq, drops, resumes, fails>>
\* the app comes back: FIX_HEAL asks the table wherever it is and reads the
\* lobby at 02; before, only a game did
Woken == /\ resumes' = resumes + 1
         /\ IF Kind(tab) = "waiting"
            THEN IF FIX_HEAL THEN AskJoin /\ lq' = LSent /\ lwhy' = "again"
                 ELSE UNCHANGED <<reads, judge, lq, lwhy>>
            ELSE Ask /\ UNCHANGED <<lq, lwhy>>
Resume == /\ resumes < MaxResumes /\ Woken
          /\ UNCHANGED <<srv, member, left, up, opening, chan, tab, lmem, mq, drops, fails>>
\* the phone slept and is woken: the events its socket should have brought
\* are lost (the socket looked open), then it comes back as Resume
Sleep == /\ chan # <<>> /\ resumes < MaxResumes /\ chan' = <<>> /\ Woken
         /\ UNCHANGED <<srv, member, left, up, opening, tab, lmem, mq, drops, fails>>

Init == /\ srv = 0 /\ member = TRUE /\ left = FALSE /\ up = TRUE /\ opening = FALSE
        /\ chan = <<>> /\ tab = 0 /\ reads = {} /\ judge = FALSE /\ lq = LNone
        /\ lwhy = "mount" /\ lmem = TRUE /\ mq = None /\ drops = 0 /\ resumes = 0
        /\ fails = 0

Next == \/ Deal \/ End \/ PlayAgain \/ Leave
        \/ Deliver \/ ServeTable \/ ApplyTable \/ ServeLobby \/ LobbyFails \/ ApplyLobby
        \/ ServeMe \/ ApplyMe \/ GameHeals
        \/ Drop \/ Back \/ Resume \/ Sleep

\* the host moves on; the phone's own steps and a socket coming up are fair;
\* a resume, a leave and a failure are never promised
Spec == Init /\ [][Next]_vars
        /\ WF_vars(Deal) /\ WF_vars(End) /\ WF_vars(PlayAgain)
        /\ WF_vars(Deliver) /\ WF_vars(ServeTable) /\ WF_vars(ApplyTable)
        /\ WF_vars(ServeLobby) /\ WF_vars(ApplyLobby) /\ WF_vars(Back)
        /\ WF_vars(ServeMe) /\ WF_vars(ApplyMe) /\ WF_vars(GameHeals)

(* ---------------- rules ---------------- *)
\* the screen never goes back to a table older than one it showed
NeverBack == [][tab' >= tab]_vars
\* the phone ends where the server is, with no slow poll (it is left out)
Converges == <>[](tab = Truth)
=============================================================================
