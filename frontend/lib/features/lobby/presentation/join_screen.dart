import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/copy/copy.dart';
import '../../../design_system/layout/space.dart';
import '../../../design_system/primitives/fit_line.dart';
import '../../../design_system/primitives/notice.dart';
import '../../../design_system/primitives/primary_button.dart';
import '../../../design_system/primitives/screen_frame.dart';
import '../../../design_system/primitives/secondary_button.dart';
import '../../../design_system/primitives/skin_field.dart';
import '../../../design_system/skin/ground.dart';
import '../../../design_system/skin/skin.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import 'home_numbers.dart';
import 'join_flow.dart';

/// 01 Join (first-time play spec, section 3): a name first, then the way in.
///
/// - The name is this device's own guest account's, or empty and focused:
///   never someone else's.
/// - "Join a table" comes first (a table has one host and many guests), and
///   "Start a table" under it, both outlined and of equal weight, locked
///   until a name is typed. "Join a table" gives way to the code and an
///   amber "Join".
/// - Opened from a table's link ([code]): the name and an amber "Join".
/// - Under them, "{n} at tables" and how this player's last game went.
///
/// What happens on a tap is [JoinFlow]'s; once the player sits at a table,
/// `/me/table/` says so and the app shows that table (opened from a link,
/// this screen goes home to it).
class JoinScreen extends ConsumerWidget {
  const JoinScreen({super.key, this.code, this.elsewhere = false});

  /// The table of the link this was opened from.
  final String? code;

  /// Opened from another table's link while this player sits at a table:
  /// "You're at another table." with "Go there", and no Join (the server
  /// does not seat anyone twice, and nobody is moved without asking).
  final bool elsewhere;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(joinFlowProvider);
    final auth = ref.watch(authProvider);
    final online = ref.watch(onlineStatsProvider).value;
    final last = ref.watch(lastGameProvider).value;
    final notifier = ref.read(joinFlowProvider.notifier);
    final link = code;

    Future<void> sat(Future<bool> attempt) async {
      if (await attempt && link != null && context.mounted) context.go('/');
    }

    // (A saved account being read back never shows 01: `HomeGate` waits.)
    void goThere() {
      notifier.goThere();
      context.go('/');
    }

    final (String? banner, String? action, VoidCallback? onAction) = switch ((
      elsewhere,
      flow,
    )) {
      (true, _) => (BannerCopy.alreadyInLobby, BannerCopy.goThere, goThere),
      (_, JoinFlowState(goThere: true)) => (
        flow.banner,
        BannerCopy.goThere,
        goThere,
      ),
      (_, JoinFlowState(retry: true)) => (
        flow.banner,
        BannerCopy.tryAgain,
        () => unawaited(sat(notifier.retry())),
      ),
      _ => (flow.banner, null, null),
    };
    return JoinView(
      name: auth is AuthAuthenticated ? auth.user.displayName : '',
      code: link,
      seated: elsewhere,
      online: online?.players,
      lastWon: last?.youWon,
      busy: flow.busy,
      banner: banner,
      bannerAction: action,
      onBannerAction: onAction,
      onEdited: notifier.clearBanner,
      onStart: (name) => unawaited(sat(notifier.start(name))),
      onJoin: (name, code) => unawaited(sat(notifier.join(name, code))),
    );
  }
}

/// The app opening while this device's saved account is read back: 01's
/// village and title, so it reads as the game opening, and "One moment"
/// under them once a try got no answer (it is made again by itself). No
/// field and no button: nothing here can make a second account.
class OpeningWait extends StatelessWidget {
  const OpeningWait({super.key, this.unanswered = false});

  final bool unanswered;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.streetDoor,
      topArtLayout: TopArtLayout.fill,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.lgPlus,
        children: [
          Semantics(
            header: true,
            child: FitLine(JoinCopy.title, style: skin.typography.heroTitle),
          ),
          if (unanswered) const Notice(message: BannerCopy.offline),
        ],
      ),
    );
  }
}

/// 01 drawn from plain values (the component sheet and the gallery draw it
/// too): [name] to start the field with, the link's [code], the numbers
/// under it, what is on its way ([busy]) and the last [banner].
class JoinView extends StatefulWidget {
  const JoinView({
    super.key,
    this.name = '',
    this.code,
    this.online,
    this.lastWon,
    this.busy,
    this.seated = false,
    this.banner,
    this.bannerAction,
    this.onBannerAction,
    this.openCode = false,
    required this.onStart,
    required this.onJoin,
    this.onEdited,
  });

  final String name;
  final String? code;

  /// Players at tables right now; null while unknown.
  final int? online;

  /// How this player's last game went; null with none.
  final bool? lastWon;

  final JoinWay? busy;
  final String? banner;

  /// The banner's button ("Try again", "Go there"), when it has one.
  final String? bannerAction;
  final VoidCallback? onBannerAction;

  /// The player sits at another table: the link's "Join" is not offered.
  final bool seated;

  /// Starts with "Join a table" opened (the gallery's state).
  final bool openCode;

  final ValueChanged<String> onStart;
  final void Function(String name, String code) onJoin;
  final VoidCallback? onEdited;

  /// The server's names: letters, digits and single spaces, 20 at most.
  static const nameLength = 20;

  /// The server's table codes: six letters and digits.
  static const codeLength = 6;

  @override
  State<JoinView> createState() => _JoinViewState();
}

class _JoinViewState extends State<JoinView> {
  late final _name = TextEditingController(text: widget.name);
  final _code = TextEditingController();
  late var _codeOpen = widget.openCode;

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _code.addListener(_changed);
  }

  void _changed() {
    widget.onEdited?.call();
    setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  final _codeFocus = FocusNode();

  /// Enter in the name field does what the screen offers first: from a link,
  /// Join; else the way to join (a guest's first step, never a table of
  /// their own by accident): the code field opens, or with a code typed,
  /// Join.
  void _nameEntered(String? link) {
    if (!_named || widget.busy != null || widget.seated) return;
    if (link != null) {
      widget.onJoin(_typedName, link);
    } else if (_codeOpen && _coded) {
      widget.onJoin(_typedName, _code.text);
    } else {
      setState(() => _codeOpen = true);
      _codeFocus.requestFocus();
    }
  }

  String get _typedName => _name.text.trim();
  bool get _named => _typedName.isNotEmpty;
  bool get _coded => _code.text.length == JoinView.codeLength;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    final busy = widget.busy;
    final idle = busy == null;
    final link = widget.code;

    VoidCallback? join(String? code) => idle && _named && code != null
        ? () => widget.onJoin(_typedName, code)
        : null;

    final banner = widget.banner;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.streetDoor,
      // The village takes the height the form leaves: the form sits low,
      // under the thumb, never above an empty lower half.
      topArtLayout: TopArtLayout.fill,
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.lgPlus,
          children: [
            Semantics(
              header: true,
              child: FitLine(
                JoinCopy.title,
                style: type.heroTitle.copyWith(fontSize: 42),
              ),
            ),
            SkinField.paper(
              controller: _name,
              hint: JoinCopy.nameHint,
              semanticLabel: JoinCopy.nameHint,
              autofocus: widget.name.isEmpty,
              maxLength: JoinView.nameLength,
              inputFormatters: [_NameFormatter()],
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _nameEntered(link),
            ),
            if (banner != null)
              Notice(
                message: banner,
                action: widget.onBannerAction == null
                    ? null
                    : widget.bannerAction,
                onAction: widget.onBannerAction,
              ),
            if (link != null && widget.seated)
              const SizedBox.shrink()
            else if (link != null)
              PrimaryButton(
                label: JoinCopy.join,
                onPressed: join(link),
                busy: busy == JoinWay.join,
                size: ButtonSize.large,
              )
            else ...[
              if (_codeOpen)
                Row(
                  spacing: Space.smPlus,
                  children: [
                    Expanded(
                      child: SkinField.code(
                        controller: _code,
                        focusNode: _codeFocus,
                        hint: JoinCopy.codeHint,
                        semanticLabel: JoinCopy.codeHint,
                        autofocus: _named,
                        maxLength: JoinView.codeLength,
                        inputFormatters: [_CodeFormatter()],
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) =>
                            join(_coded ? _code.text : null)?.call(),
                      ),
                    ),
                    PrimaryButton(
                      label: JoinCopy.join,
                      onPressed: join(_coded ? _code.text : null),
                      busy: busy == JoinWay.join,
                      size: ButtonSize.compact,
                    ),
                  ],
                )
              else
                SecondaryButton(
                  label: JoinCopy.joinTable,
                  onPressed: idle && _named
                      ? () => setState(() => _codeOpen = true)
                      : null,
                  size: ButtonSize.large,
                ),
              SecondaryButton(
                label: JoinCopy.startTable,
                onPressed: idle && _named
                    ? () => widget.onStart(_typedName)
                    : null,
                size: ButtonSize.large,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (link == null && (widget.online != null || widget.lastWon != null))
          Builder(
            builder: (context) {
              final style = type.lede.copyWith(color: context.ground.text);
              final online = widget.online;
              final won = widget.lastWon;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: Space.xs,
                children: [
                  const Divider(height: Space.mdPlus),
                  if (online != null)
                    FitWords(JoinCopy.online.fill({'n': online}), style: style),
                  if (won != null)
                    FitWords(
                      won ? JoinCopy.lastWon : JoinCopy.lastLost,
                      style: style,
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// A name as the server takes it: letters, digits and single spaces, no
/// space first.
class _NameFormatter extends TextInputFormatter {
  static final _unwanted = RegExp(r'[^\p{L}\p{N} ]', unicode: true);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text
        .replaceAll(_unwanted, '')
        .replaceAll(RegExp(' {2,}'), ' ')
        .replaceFirst(RegExp('^ '), '');
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// A table code: capitals and digits.
class _CodeFormatter extends TextInputFormatter {
  static final _unwanted = RegExp('[^A-Z0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase().replaceAll(_unwanted, '');
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
