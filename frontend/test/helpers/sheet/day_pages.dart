import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import 'sheet_data.dart';

// 08 Talk and 09 Vote, to the first-time play spec (10 and 11:
// end_pages.dart).

/// 08: the talk, as the app draws it ([TalkView]) on the viewer's phone of
/// game 7 or 8, its `/me/` in the talk. The sun is loudest, then My night
/// (the hold cue on it in a first game); "Ready to vote" is outlined and
/// never locked.
class TalkPage extends StatefulWidget {
  const TalkPage({
    super.key,
    required this.viewer,
    this.me,
    this.secondsLeft = 252,
    this.elapsed,
  });

  final Viewer viewer;

  /// The phone's `/me/` in the talk: [viewer]'s recorded one when not given.
  final Map<String, dynamic>? me;

  /// The talk's clock: its number, and how far the sun is.
  final int secondsLeft;
  final double? elapsed;

  @override
  State<TalkPage> createState() => _TalkPageState();
}

class _TalkPageState extends State<TalkPage> {
  late final _me = GameMe.fromJson(widget.me ?? widget.viewer.talkMe);
  var _ready = false;

  @override
  Widget build(BuildContext context) => TalkView(
    me: _me.withReady(_ready),
    secondsLeft: widget.secondsLeft,
    elapsed: widget.elapsed,
    onReady: () => setState(() => _ready = !_ready),
  );
}

/// 09: pick a name, then lock it in, as the app draws it ([VoteView]) on
/// Ana's phone of game 7, its `/me/` as the vote opens. Your own row is never
/// listed; once locked every row looks the same.
class VotePage extends ConsumerStatefulWidget {
  const VotePage({super.key, this.me, this.secondsLeft = 72, this.remaining});

  /// The viewer's `/me/` as the vote opens: Ana's of game 7 when not given.
  final Map<String, dynamic>? me;

  /// The vote's clock: its number, and how much of the bar is left.
  final int secondsLeft;
  final double? remaining;

  @override
  ConsumerState<VotePage> createState() => _VotePageState();
}

class _VotePageState extends ConsumerState<VotePage> {
  late final _me = GameMe.fromJson(
    widget.me ?? recordedMe('me_voting_unpicked'),
  );
  MyVote? _vote;

  @override
  Widget build(BuildContext context) {
    final vote = _vote;
    return VoteView(
      me: vote == null ? _me : _me.withVote(vote),
      secondsLeft: widget.secondsLeft,
      remaining: widget.remaining,
      onPick: (id) => setState(() => _vote = MyVote.local(id, locked: false)),
      onLock: (id) {
        setState(() => _vote = MyVote.local(id, locked: true));
        ref.read(learnedCuesProvider.notifier).learn(Cue.voteLock);
      },
    );
  }
}
