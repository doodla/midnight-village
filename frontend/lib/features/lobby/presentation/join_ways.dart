part of 'join_screen.dart';

// 01's two ways in and its foot (part of join_screen.dart). Dressed in paper,
// 01 has exactly one amber plaque at any moment: "Join" once the code field
// holds a whole code (typed, scanned, or the link's), else "Start a table".
// The other way in is a bone scrap, or, beside a code not yet whole, the
// kit's locked form saying what it needs. The two keep their places when
// the plaque moves: only the paper changes.

/// Which of 01's ways in is the amber plaque.
enum JoinPlaque { start, join }

extension _JoinWays on _JoinViewState {
  /// "Join" beside the code, or alone under the name from a link. The plaque
  /// when the code is whole; else the kit's locked form saying what it needs
  /// in 01's own word for it, "Code" (a tap takes the cursor to what is
  /// missing: the name first, then the code).
  Widget _join({
    required JoinPlaque plaque,
    required String? code,
    required ButtonSize size,
    required JoinWay? busy,
  }) {
    if (plaque == JoinPlaque.start || code == null) {
      return PrimaryButton.locked(
        label: JoinCopy.codeHint,
        onLockedTap: _named ? _codeFocus.requestFocus : _needName,
        size: size,
      );
    }
    // Another request is on its way (Start a table): Join holds its words.
    if (busy == JoinWay.start) {
      return PrimaryButton.waiting(
        label: JoinCopy.join,
        reason: SpokenCopy.working,
        size: size,
      );
    }
    // Busy, Join keeps its amber and its reading (a tap does nothing: the
    // button ignores it and the flow sends one request at a time). With no
    // name it is still the plaque, and a tap leads to the name.
    return PrimaryButton(
      label: JoinCopy.join,
      onPressed: _named && !widget.seated
          ? () => widget.onJoin(_typedName, code)
          : _needName,
      busy: busy == JoinWay.join,
      size: size,
    );
  }

  /// "Start a table", in its own place under the code: the amber plaque
  /// while the code is not whole (with no name a tap leads to the name),
  /// else a small bone scrap in the same place.
  Widget _start({required JoinPlaque plaque, required JoinWay? busy}) {
    const size = ButtonSize.large;
    void act() => widget.onStart(_typedName);
    if (plaque == JoinPlaque.join) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: size.primaryHeight),
        child: Center(
          child: _scrap(
            label: JoinCopy.startTable,
            busy: busy,
            own: JoinWay.start,
            act: act,
          ),
        ),
      );
    }
    if (busy == JoinWay.join) {
      return PrimaryButton.waiting(
        label: JoinCopy.startTable,
        reason: SpokenCopy.working,
        size: size,
      );
    }
    return PrimaryButton(
      label: JoinCopy.startTable,
      onPressed: _named ? act : _needName,
      busy: busy == JoinWay.start,
      size: size,
    );
  }

  /// A way in on bone paper ("Join a table", or "Start a table" while Join
  /// is the plaque): with no name a tap leads to the name field; while
  /// another request is on its way it holds its words; [own] is the request
  /// this one made.
  Widget _scrap({
    required String label,
    required JoinWay? busy,
    required JoinWay? own,
    required VoidCallback act,
  }) {
    const size = ButtonSize.large;
    if (!_named) {
      return SecondaryButton.locked(
        label: label,
        onLockedTap: _needName,
        size: size,
      );
    }
    if (own != null && busy == own) {
      return SecondaryButton(
        label: label,
        busy: true,
        onPressed: act,
        size: size,
      );
    }
    if (busy != null) {
      return SecondaryButton.waiting(
        label: label,
        reason: SpokenCopy.working,
        size: size,
      );
    }
    return SecondaryButton(label: label, onPressed: act, size: size);
  }
}

/// 01's quiet foot: "{n} at tables", how the last game went, and in an
/// Android browser "Get the app" (on the numbers' row, at its end; alone at
/// the end with no numbers). None of it from a table's link.
class _JoinFoot extends StatelessWidget {
  const _JoinFoot({
    required this.online,
    required this.lastWon,
    required this.link,
    required this.onGetApp,
  });

  final int? online;
  final bool? lastWon;
  final String? link;
  final VoidCallback? onGetApp;

  /// Whether there is anything to show.
  static bool shows({
    required int? online,
    required bool? lastWon,
    required String? link,
    required VoidCallback? onGetApp,
  }) =>
      (link == null && (online != null || lastWon != null)) || onGetApp != null;

  @override
  Widget build(BuildContext context) {
    final style = context.skin.typography.lede.copyWith(
      color: context.ground.text,
    );
    final online = this.online;
    final won = lastWon;
    final showStats = link == null && (online != null || won != null);
    // The target's side padding overhangs the column, so the words end on
    // its edge; the 48 px target stays whole.
    final getApp = onGetApp == null
        ? null
        : Transform.translate(
            offset: const Offset(Space.sm, 0),
            child: TextAction(
              label: JoinCopy.getApp,
              onPressed: onGetApp,
              roomy: true,
              quiet: true,
            ),
          );
    final onlineLine = showStats && online != null
        ? FitWords(JoinCopy.online.fill({'n': online}), style: style)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.xs,
      children: [
        if (showStats) const Rule.divider(height: Space.mdPlus),
        if (onlineLine != null && getApp != null)
          Row(
            spacing: Space.sm,
            children: [
              Expanded(child: onlineLine),
              getApp,
            ],
          )
        else if (onlineLine != null)
          onlineLine
        else if (getApp != null)
          Align(alignment: AlignmentDirectional.centerEnd, child: getApp),
        if (showStats && won != null)
          FitWords(won ? JoinCopy.lastWon : JoinCopy.lastLost, style: style),
      ],
    );
  }
}
