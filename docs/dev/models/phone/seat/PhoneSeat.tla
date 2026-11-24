----------------------------- MODULE PhoneSeat -----------------------------
(* ONE guest phone and where it sits, from 02 through a game, play again and  *)
(* the next deal: the events that move it (game_started on the lobby socket,  *)
(* game_results and play_again on the game socket), /me/table/ reads, the     *)
(* lobby's reads, the game's /me/, a socket that opens, drops and comes back, *)
(* the app coming back. Modelled from branch start-lands-fast (on e48d802):   *)
(* where_am_i_provider.dart (myTable, SeatSeed, seatFromServer),              *)
(* lobby_notifier.dart (build, refreshLobby, _askWhereIfMoved,                *)
(* _applyStartedGame, the connection listener), live_game.dart (apply,        *)
(* _seatBackAtTable, _healEverything, _onConnection, _compareTable),          *)
(* at_table_screen.dart (_follow).                                            *)
(*                                                                            *)
(* The server's table is a version: 0 waiting, 1 game 1, 2 game 1 finished,   *)
(* 3 waiting again (play again), 4 game 2. The phone holds one (tab).         *)
EXTENDS Naturals, Sequences

CONSTANTS
  FIX_SEED,    \* an event that says where the phone sits is its seat (no read)
  FIX_LATE,    \* ... unless the table the phone holds already names that game
               \* (a late game_started: the phone is there or past it)
  FIX_HEAL,    \* a lobby read again saying "in a game", and the socket or the
               \* app coming back at 02, read /me/table/ at once
  FIX_UP,      \* a socket's first opening reads what was said before it
               \* listened: at 02 the lobby (then FIX_HEAL's rule), at the end
               \* /me/table/
  DROP_STALE,  \* a /me/table/ read still out when a newer one is asked for is
               \* dropped (Riverpod keeps only the newest build's answer)
  POLL,        \* the slow poll at 02 and at the end (15 s): the backstop
  OPEN_INSTANT, \* a new screen's socket listens at once (no opening window):
               \* isolates the misses this slice is about (a drop, a sleep)
  MaxDrops, MaxResumes

Kind(v) == CASE v \in {0, 3} -> "waiting" [] v \in {1, 4} -> "game" [] OTHER -> "finished"
\* the socket the phone listens to at what it shows (one game's socket per game)
Src(v) == IF Kind(v) = "waiting" THEN "lobby" ELSE IF v <= 2 THEN "game1" ELSE "game2"
None == 99  \* (not a version)
Sent == 98  \* (not a version)

VARIABLES
  srv,      \* the server's table
  up,       \* the phone's socket is connected (listened to by the server)
  opening,  \* ... and it is a new socket, not up yet for the first time
  chan,     \* events on their way to the phone, in order
  tab,      \* the table the phone shows (/me/table/'s held value)
  gen,      \* the newest /me/table/ read asked for
  reads,    \* /me/table/ reads out: [g, v] (v = Sent until served)
  lq,       \* the lobby read: None, Sent, or the served version
  lwhy,     \* why it was read: "mount" (02 opens) or "again" (reconnect, resume)
  mq,       \* the game's /me/ read: None, Sent, or the served version
  drops, resumes

vars == <<srv, up, opening, chan, tab, gen, reads, lq, lwhy, mq, drops, resumes>>

(* ---------------- the phone's moves ---------------- *)
\* ref.invalidate(myTableProvider): a new read; with DROP_STALE the older is ignored
ReadTable == /\ gen' = gen + 1
             /\ reads' = reads \cup {[g |-> gen + 1, v |-> Sent]}
\* What the phone shows becomes v. A screen on another socket opens it (not
\* listened to until it is up) and reads at once: 02 its lobby, a game its /me/.
Show(v) == /\ tab' = v
           /\ IF Src(v) # Src(tab) /\ ~OPEN_INSTANT THEN up' = FALSE /\ opening' = TRUE
              ELSE UNCHANGED <<up, opening>>
           /\ IF Kind(v) = "waiting" /\ Kind(tab) # "waiting"
              THEN lq' = Sent /\ lwhy' = "mount"
              ELSE UNCHANGED <<lq, lwhy>>
           /\ IF Kind(v) # "waiting" /\ Src(v) # Src(tab) THEN mq' = Sent ELSE UNCHANGED mq
\* seatFromServer: the seat is put and a read asked for that takes it (no request)
Seed(v) == /\ gen' = gen + 1 /\ Show(v) /\ UNCHANGED reads

(* ---------------- server ---------------- *)
\* an event reaches the phone only on a socket that is up and listened to
Emit(src, v) == IF up /\ Src(tab) = src THEN chan' = Append(chan, [src |-> src, v |-> v])
                ELSE UNCHANGED chan
Ph == <<up, opening, tab, gen, reads, lq, lwhy, mq, drops, resumes>>
Deal == /\ Kind(srv) = "waiting" /\ srv' = srv + 1 /\ Emit("lobby", srv + 1) /\ UNCHANGED Ph
End == /\ srv = 1 /\ srv' = 2 /\ Emit("game1", 2) /\ UNCHANGED Ph
PlayAgain == /\ srv = 2 /\ srv' = 3 /\ Emit("game1", 3) /\ UNCHANGED Ph

(* ---------------- events in ---------------- *)
Deliver ==
  /\ chan # <<>>
  /\ LET e == Head(chan) IN
     /\ chan' = Tail(chan)
     /\ IF e.src # Src(tab) THEN UNCHANGED <<up, opening, tab, gen, reads, lq, lwhy, mq>> \* closed
        ELSE IF e.src = "lobby"                                       \* game_started
             THEN IF ~FIX_SEED THEN ReadTable /\ UNCHANGED <<up, opening, tab, lq, lwhy, mq>>
                  ELSE IF FIX_LATE /\ tab >= e.v
                       THEN UNCHANGED <<up, opening, tab, gen, reads, lq, lwhy, mq>>
                  ELSE Seed(e.v)
        ELSE IF e.v = 3 /\ FIX_SEED /\ Kind(tab) = "finished"        \* play_again at the end
             THEN Seed(e.v)
        ELSE ReadTable /\ UNCHANGED <<up, opening, tab, lq, lwhy, mq>> \* game_results; play_again elsewhere
  /\ UNCHANGED <<srv, drops, resumes>>

(* ---------------- reads ---------------- *)
ServeTable == \E r \in reads :
  /\ r.v = Sent /\ reads' = (reads \ {r}) \cup {[r EXCEPT !.v = srv]}
  /\ UNCHANGED <<srv, up, opening, chan, tab, gen, lq, lwhy, mq, drops, resumes>>
ApplyTable == \E r \in reads :
  /\ r.v # Sent /\ reads' = reads \ {r}
  /\ IF r.g = gen \/ ~DROP_STALE THEN Show(r.v) ELSE UNCHANGED <<up, opening, tab, lq, lwhy, mq>>
  /\ UNCHANGED <<srv, chan, gen, drops, resumes>>
ServeLobby == /\ lq = Sent /\ lq' = srv
              /\ UNCHANGED <<srv, up, opening, chan, tab, gen, reads, lwhy, mq, drops, resumes>>
\* the lobby says the table is past waiting and the phone knows no game of it:
\* the first read (build) looked the game up even before (current-game, then
\* the table); a read again does only with FIX_HEAL (_askWhereIfMoved)
ApplyLobby ==
  /\ lq \notin {None, Sent} /\ lq' = None /\ UNCHANGED lwhy
  /\ IF Kind(tab) = "waiting" /\ Kind(lq) # "waiting" /\ (lwhy = "mount" \/ FIX_HEAL)
     THEN ReadTable ELSE UNCHANGED <<gen, reads>>
  /\ UNCHANGED <<srv, up, opening, chan, tab, mq, drops, resumes>>
\* the slow poll at a waiting table or a finished game (only while it is behind:
\* a poll that would read the same answer changes nothing)
Poll == /\ POLL /\ Kind(tab) # "game" /\ tab # srv /\ reads = {}
        /\ ReadTable
        /\ UNCHANGED <<srv, up, opening, chan, tab, lq, lwhy, mq, drops, resumes>>
\* /me/ says the game is further on than the table the phone holds (its
\* results, or the next deal: this game is over): the table is read
\* (_compareTable). The phone's own game's later phases (deadlines, the
\* stage's events) are the day model's (../day/), not this one's.
ServeMe == /\ mq = Sent /\ mq' = srv
           /\ UNCHANGED <<srv, up, opening, chan, tab, gen, reads, lq, lwhy, drops, resumes>>
ApplyMe == /\ mq \notin {None, Sent} /\ mq' = None
           /\ IF Kind(tab) = "game" /\ mq > tab THEN ReadTable ELSE UNCHANGED <<gen, reads>>
           /\ UNCHANGED <<srv, up, opening, chan, tab, lq, lwhy, drops, resumes>>
\* in a game every stage has a deadline, and past it the phone reads until
\* the stage changes (_armHealing, the day model's FIX_HEAL): abstracted here
\* as a read of the table while the game the phone shows is behind
GameHeals == /\ Kind(tab) = "game" /\ srv # tab /\ reads = {} /\ mq = None
             /\ ReadTable
             /\ UNCHANGED <<srv, up, opening, chan, tab, lq, lwhy, mq, drops, resumes>>

(* ---------------- the socket and the app ---------------- *)
Drop == /\ up /\ drops < MaxDrops /\ drops' = drops + 1
        /\ up' = FALSE /\ chan' = <<>>
        /\ UNCHANGED <<srv, opening, tab, gen, reads, lq, lwhy, mq, resumes>>
\* the socket is up. Back after a drop: at 02 the lobby is read again (and,
\* FIX_HEAL, the table); in a game or at the end the game reads the table
\* (_healEverything). Up for the first time: nothing before FIX_UP; with it,
\* 02 reads its lobby again (_readWhenUp: its rule reads the table if the
\* lobby has moved on) and a game reads its table (_onConnection).
Back == /\ ~up /\ up' = TRUE /\ opening' = FALSE
        /\ IF opening
           THEN IF FIX_UP /\ Kind(tab) = "waiting"
                THEN lq' = Sent /\ lwhy' = "again" /\ UNCHANGED <<gen, reads>>
                ELSE IF FIX_UP
                THEN ReadTable /\ UNCHANGED <<lq, lwhy>>
                ELSE UNCHANGED <<gen, reads, lq, lwhy>>
           ELSE IF Kind(tab) = "waiting"
                THEN /\ lq' = Sent /\ lwhy' = "again"
                     /\ IF FIX_HEAL THEN ReadTable ELSE UNCHANGED <<gen, reads>>
                ELSE ReadTable /\ UNCHANGED <<lq, lwhy>>
        /\ UNCHANGED <<srv, chan, tab, mq, drops, resumes>>
\* the app comes back: FIX_HEAL reads the table wherever it is (myTable
\* listens to the resume) and the lobby at 02; before, only a game did
Woken == /\ resumes' = resumes + 1
         /\ IF Kind(tab) = "waiting"
            THEN IF FIX_HEAL THEN ReadTable /\ lq' = Sent /\ lwhy' = "again"
                 ELSE UNCHANGED <<gen, reads, lq, lwhy>>
            ELSE ReadTable /\ UNCHANGED <<lq, lwhy>>
\* the player leaves the app and comes back (nothing was missed)
Resume == /\ resumes < MaxResumes /\ Woken
          /\ UNCHANGED <<srv, up, opening, chan, tab, mq, drops>>
\* the phone slept and is woken: the events its socket should have brought
\* are lost (the socket looked open), then it comes back as Resume
Sleep == /\ chan # <<>> /\ resumes < MaxResumes /\ chan' = <<>> /\ Woken
         /\ UNCHANGED <<srv, up, opening, tab, mq, drops>>

Done == srv = 4 /\ tab = 4 /\ chan = <<>> /\ reads = {} /\ lq = None /\ mq = None /\ up
        /\ UNCHANGED vars

Init == /\ srv = 0 /\ up = TRUE /\ opening = FALSE /\ chan = <<>> /\ tab = 0 /\ gen = 0
        /\ reads = {} /\ lq = None /\ lwhy = "mount" /\ mq = None /\ drops = 0 /\ resumes = 0

Next == \/ Deal \/ End \/ PlayAgain
        \/ Deliver \/ ServeTable \/ ApplyTable \/ ServeLobby \/ ApplyLobby \/ Poll
        \/ ServeMe \/ ApplyMe \/ GameHeals
        \/ Drop \/ Back \/ Resume \/ Sleep \/ Done

\* the host moves on; the phone's own steps and a socket coming up are fair;
\* a resume is the player's, never promised
Spec == Init /\ [][Next]_vars
        /\ WF_vars(Deal) /\ WF_vars(End) /\ WF_vars(PlayAgain)
        /\ WF_vars(Deliver) /\ WF_vars(ServeTable) /\ WF_vars(ApplyTable)
        /\ WF_vars(ServeLobby) /\ WF_vars(ApplyLobby) /\ WF_vars(Back) /\ WF_vars(Poll)
        /\ WF_vars(ServeMe) /\ WF_vars(ApplyMe) /\ WF_vars(GameHeals)

(* ---------------- rules ---------------- *)
\* the screen never goes back to a table older than one it showed
NeverBack == [][tab' >= tab]_vars
\* the phone ends where the server is (without the slow poll when POLL = FALSE)
Converges == <>[](tab = srv)
=============================================================================
