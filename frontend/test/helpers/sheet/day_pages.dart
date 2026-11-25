import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/primitives/countdown.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import '../painted_text.dart' show BehindScrim;
import 'sheet_data.dart';

// 08 Talk and 09 Vote, to the first-time play spec.

/// 08: the talk, as the app draws it ([TalkView]) on the viewer's phone of
/// game 7 or 8, its `/me/` in the talk. The sun is loudest, then My night; "Ready to vote" is outlined and
/// never locked.
class TalkPage extends StatefulWidget {
  const TalkPage({
    super.key,
    required this.viewer,
    this.me,
    this.secondsLeft = 252,
    this.open = false,
  });

  final Viewer viewer;

  /// As the talk opens: My night's sheet up where the night told this phone
  /// something it has not acknowledged (Close puts it away).
  final bool open;

  /// The phone's `/me/` in the talk: [viewer]'s recorded one when not given.
  final Map<String, dynamic>? me;

  /// The talk's clock.
  final int secondsLeft;

  @override
  State<TalkPage> createState() => _TalkPageState();
}

class _TalkPageState extends State<TalkPage> {
  late final _me = GameMe.fromJson(widget.me ?? widget.viewer.talkMe);
  var _ready = false;
  late final _open =
      widget.open && _me.hasUnseenResults && _me.report.tellsSomething;

  final _talk = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final view = KeyedSubtree(
      key: _talk,
      child: TalkView(
        me: _me.withReady(_ready),
        clock: Countdown.held(widget.secondsLeft),
        onReady: () => setState(() => _ready = !_ready),
        openNight: _open,
      ),
    );
    // My night's sheet over it: what is under its scrim is not meant to be
    // read ([BehindScrim]); the talk keeps its state (it opens the sheet
    // once) whichever way it is wrapped.
    return ModalRoute.of(context)?.isCurrent == false
        ? BehindScrim(child: view)
        : view;
  }
}

/// 09: pick a name, then lock it in, as the app draws it ([VoteView]) on
/// Ana's phone of game 7, its `/me/` as the vote opens. Your own name is never
/// listed; once locked the pick is red and sealed.
class VotePage extends ConsumerStatefulWidget {
  const VotePage({super.key, this.me, this.secondsLeft = 72});

  /// The viewer's `/me/` as the vote opens: Ana's of game 7 when not given.
  final Map<String, dynamic>? me;

  /// The vote's clock.
  final int secondsLeft;

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
      clock: Countdown.held(widget.secondsLeft),
      onPick: (id) => setState(() => _vote = MyVote.local(id, locked: false)),
      onLock: (id) {
        setState(() => _vote = MyVote.local(id, locked: true));
        ref.read(learnedCuesProvider.notifier).learn(Cue.voteLock);
      },
    );
  }
}
