import 'package:flutter/foundation.dart';

import '../../../design_system/faces/face_content.dart' show serverRole;
import '../../../design_system/faces/night_report.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/night/choose_prompt.dart';
import '../../../design_system/night/night_pick.dart';
import 'stage_progress.dart';

/// A game's phase, as `/me/` names it.
enum GamePhase {
  night('night'),
  discussion('discussion'),
  voting('voting'),
  results('results');

  const GamePhase(this.server);

  final String server;

  static GamePhase fromServer(Object? name) =>
      values.where((p) => p.server == name).firstOrNull ??
      (throw FormatException('Unknown phase', name));
}

/// This phone's own vote in the vote (`/me/`'s `my_vote`): picked, or
/// locked in. Nobody else's is ever sent.
@immutable
class MyVote {
  const MyVote._(this.targetId, {required this.locked});

  factory MyVote.fromJson(Map<String, dynamic> json) =>
      MyVote._(json['target_player_id'] as int, locked: json['locked'] as bool);

  /// The vote as this phone holds it from the tap on (see `ProtocolTwoGame`).
  const MyVote.local(this.targetId, {required this.locked});

  final int targetId;

  /// Locked in: final, the server takes no other pick.
  final bool locked;

  @override
  bool operator ==(Object other) =>
      other is MyVote && other.targetId == targetId && other.locked == locked;

  @override
  int get hashCode => Object.hash(targetId, locked);

  @override
  String toString() => 'MyVote($targetId${locked ? ', locked' : ''})';
}

/// `GET /onuw/games/<id>/me/` of a night protocol 2 game, everything this
/// phone may know, parsed strictly (a key the server always sends is
/// required; a missing one throws, so a fixture cannot lean on a default).
///
/// The night is not parsed here a second time: [prompt], [seats] and
/// [report] are the design system's own parsers (`ChoosePrompt.fromMe`,
/// `NightSeat.seatsOf`, `NightReport.fromMe`), run once on the same body, so
/// the board, the faces and this model can never read the night differently.
/// The rest (phase, stage, deadline, counts, the vote, ready) is read here.
@immutable
class GameMe {
  const GameMe._({
    required this.playerId,
    required this.gameId,
    required this.lobbyCode,
    required this.phase,
    required this.window,
    required this.deadline,
    required this.stageStartedAt,
    required this.stage,
    required this.dealt,
    required this.finalRole,
    required this.isHost,
    required this.hostId,
    required this.seats,
    required this.prompt,
    required this.deck,
    required this.report,
    required this.nightResultCount,
    required this.nightResultsSeen,
    required this.myVote,
    required this.ready,
    required this.progress,
    required this.voteTargets,
  });

  /// A protocol-2 `/me/` body. One without a `stage` key is protocol 1
  /// (`gameStateFromServer` reads those) and is refused here.
  factory GameMe.fromJson(Map<String, dynamic> me) {
    if (!me.containsKey('stage')) {
      throw FormatException('Not a night protocol 2 /me/ (no stage)', me);
    }
    // Sent in every protocol-2 /me/, null or not: a missing one is a broken
    // payload, never "nothing".
    for (final key in _alwaysSent) {
      if (!me.containsKey(key)) throw FormatException('No $key in /me/', me);
    }
    final role = me['your_role'] as Map<String, dynamic>;
    // Always sent, read for strictness only: `has_acted` and `has_voted` are
    // the protocol-1 flags; protocol 2 says the same with `chosen`, `ready`
    // and `my_vote`.
    role['has_acted'] as bool;
    me['has_voted'] as bool;
    final rawVote = me['my_vote'] as Map<String, dynamic>?;
    final rawProgress = me['progress'] as Map<String, dynamic>?;
    final results = me['night_results'] as List;
    final deadline = me['deadline'] as String?;
    final stageStartedAt = me['stage_started_at'] as String?;
    final voteTargets = me['vote_targets'] as List?;
    final finalRole = role['current_role'] as String?;
    return GameMe._(
      playerId: me['player_id'] as int,
      gameId: me['game_id'] as String,
      lobbyCode: me['lobby_code'] as String,
      phase: GamePhase.fromServer(me['phase']),
      window: me['current_wave'] as int,
      deadline: deadline == null ? null : DateTime.parse(deadline),
      stageStartedAt: stageStartedAt == null
          ? null
          : DateTime.parse(stageStartedAt),
      stage: me['stage'] as String?,
      dealt: serverRole(role['original_role']),
      finalRole: finalRole == null ? null : serverRole(finalRole),
      isHost: me['is_host'] as bool,
      hostId: me['host_id'] as int,
      seats: NightSeat.seatsOf(me),
      prompt: me['action_prompt'] == null ? null : ChoosePrompt.fromMe(me),
      deck: {
        for (final entry in (me['roles_in_game'] as List).cast<Map>())
          serverRole(entry['role']): entry['count'] as int,
      },
      report: NightReport.fromMe(me),
      nightResultCount: results.length,
      nightResultsSeen: me['night_results_seen'] as int,
      myVote: rawVote == null ? null : MyVote.fromJson(rawVote),
      ready: me['ready'] as bool?,
      progress: rawProgress == null
          ? null
          : StageProgress.fromJson(rawProgress),
      voteTargets: voteTargets == null
          ? null
          : List.unmodifiable(voteTargets.cast<int>()),
    );
  }

  static const _alwaysSent = [
    'deadline',
    'stage_started_at',
    'action_prompt',
    'my_vote',
    'ready',
    'progress',
    'vote_targets',
  ];

  /// This phone's own player id (`player_id`).
  final int playerId;

  final String gameId;

  /// The table (lobby) this game is played at.
  final String lobbyCode;
  final GamePhase phase;

  /// `current_wave`: 0 is the look stage (or a night about to open), 1 the
  /// Doppelganger's window, 2 everyone's; 0 outside the night.
  final int window;

  /// When the server ends the stage on its own; null when untimed. Every
  /// countdown is read from this, never assumed.
  final DateTime? deadline;

  /// When the timed stage open now began (`stage_started_at`), the same on
  /// every phone; null whenever [deadline] is.
  final DateTime? stageStartedAt;

  /// The opaque name of the stage the game is in, which every stage-scoped
  /// request echoes; null when no stage takes requests (the results).
  final String? stage;

  /// The card this phone was dealt.
  final RoleId dealt;

  /// The card it holds at the end: sent in the results only.
  final RoleId? finalRole;

  /// Whether this phone holds the host role now (the acting host included).
  final bool isHost;
  final int hostId;

  /// Everyone at the table, in seat order.
  final List<NightSeat> seats;

  /// This phone's night turn, while a window is open.
  final ChoosePrompt? prompt;

  /// The deck tonight (`roles_in_game`), in the server's order.
  final Map<RoleId, int> deck;

  /// What the server told this phone about its card and its night, as faces.
  final NightReport report;

  /// How many `night_results` entries `/me/` lists (closed windows only, and
  /// the Doppelganger's look at once).
  final int nightResultCount;

  /// How many of them this phone has acknowledged (`night-results/seen`).
  final int nightResultsSeen;

  /// This phone's own pick or locked vote, in the vote.
  final MyVote? myVote;

  /// This phone's own flag at the look and the talk; null elsewhere.
  final bool? ready;

  /// Counts at the look, talk and vote; null elsewhere.
  final StageProgress? progress;

  /// In the vote: the player ids this phone may vote for, in seat order
  /// (`vote_targets`, every other player); null elsewhere.
  final List<int>? voteTargets;

  /// Results this phone has not acknowledged yet.
  bool get hasUnseenResults => nightResultCount > nightResultsSeen;

  /// The look stage (night, window 0).
  bool get inLook => phase == GamePhase.night && window == 0;

  /// A night window is open (1 or 2).
  bool get inWindow => phase == GamePhase.night && window > 0;

  GameMe _with({
    ChoosePrompt? prompt,
    MyVote? myVote,
    bool clearVote = false,
    bool? ready,
    bool clearReady = false,
    StageProgress? progress,
    int? nightResultsSeen,
    int? hostId,
    bool? isHost,
  }) => GameMe._(
    playerId: playerId,
    gameId: gameId,
    lobbyCode: lobbyCode,
    phase: phase,
    window: window,
    deadline: deadline,
    stageStartedAt: stageStartedAt,
    stage: stage,
    dealt: dealt,
    finalRole: finalRole,
    isHost: isHost ?? this.isHost,
    hostId: hostId ?? this.hostId,
    seats: seats,
    prompt: prompt ?? this.prompt,
    deck: deck,
    report: report,
    nightResultCount: nightResultCount,
    nightResultsSeen: nightResultsSeen ?? this.nightResultsSeen,
    myVote: clearVote ? null : myVote ?? this.myVote,
    ready: clearReady ? null : ready ?? this.ready,
    progress: progress ?? this.progress,
    voteTargets: voteTargets,
  );

  /// With this turn's choose sent ([ChoosePrompt.afterChoose]).
  GameMe withChosen() {
    final open = prompt;
    return open == null ? this : _with(prompt: open.afterChoose);
  }

  /// With this phone's [ready] flag as tapped.
  GameMe withReady(bool ready) => _with(ready: ready);

  /// With this phone's vote as tapped.
  GameMe withVote(MyVote vote) => _with(myVote: vote);

  /// With the server's newer counts, when they are for this stage's counts;
  /// otherwise unchanged (a count for another stage is a reason to fetch).
  GameMe withProgress(StageProgress next) =>
      progress?.stage == next.stage ? _with(progress: next) : this;

  /// With results acknowledged up to [seen] (the count only goes up).
  GameMe withSeen(int seen) =>
      seen > nightResultsSeen ? _with(nightResultsSeen: seen) : this;

  /// With the host role where a `host_changed` event says it is now.
  GameMe withHost(int hostId) =>
      _with(hostId: hostId, isHost: hostId == playerId);
}
