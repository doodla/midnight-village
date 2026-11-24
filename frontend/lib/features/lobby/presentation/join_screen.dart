import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/host/app_download.dart';
import '../../../core/router/back_policy.dart';
import '../../../design_system/copy/copy.dart';
import '../../../design_system/layout/space.dart';
import '../../../design_system/primitives/fit_line.dart';
import '../../../design_system/primitives/notice.dart';
import '../../../design_system/primitives/mood.dart';
import '../../../design_system/primitives/nudge.dart';
import '../../../design_system/primitives/primary_button.dart';
import '../../../design_system/primitives/screen_frame.dart';
import '../../../design_system/primitives/secondary_button.dart';
import '../../../design_system/primitives/waiting_sign.dart';
import '../../../design_system/primitives/skin_field.dart';
import '../../../design_system/primitives/text_action.dart';
import '../../../design_system/primitives/viewfinder.dart';
import '../../../design_system/skin/dress.dart';
import '../../../design_system/skin/ground.dart';
import '../../../design_system/skin/skin.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import 'home_numbers.dart';
import 'join_flow.dart';
import 'scan/code_scanner.dart';
import 'scan/scan_session.dart';
import 'scan/scan_view.dart';
import '../../../design_system/primitives/rule.dart';

part 'join_view.dart';
part 'join_ways.dart';

/// 01 Join (first-time play spec, section 3): a name first, then the way in.
///
/// - The name is this device's own guest account's, or empty and focused:
///   never someone else's.
/// - "Join a table" comes first (a table has one host and many guests), and
///   "Start a table" under it, both outlined and of equal weight, locked
///   until a name is typed. "Join a table" gives way to the code and an
///   amber "Join"; Back closes the code again.
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
    final scanner = ref.watch(codeScannerFactoryProvider);
    final scan = ref.watch(scanSessionProvider);
    final session = ref.read(scanSessionProvider.notifier);
    final download = ref.watch(appDownloadProvider);

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
    // Seated at another table: Back does what "Go there" does (never out of
    // the app with a seat).
    return BackHandler(
      open: onAction == goThere,
      onBack: goThere,
      child: JoinView(
        name: auth is AuthAuthenticated ? auth.user.displayName : '',
        code: link,
        seated: elsewhere,
        online: online?.players,
        lastWon: last?.youWon,
        busy: flow.busy,
        draft: ref.read(joinDraftProvider),
        onDraft: ref.read(joinDraftProvider.notifier).keep,
        scanner: scanner,
        scanning: scan.open,
        scanned: scan.code,
        onScanOpen: session.open,
        onScanClose: session.close,
        onScanLeft: session.left,
        onScanned: session.found,
        banner: banner,
        bannerAction: action,
        onBannerAction: onAction,
        onGetApp: download?.open,
        onEdited: notifier.clearBanner,
        onStart: (name) => unawaited(sat(notifier.start(name))),
        onJoin: (name, code) => unawaited(sat(notifier.join(name, code))),
      ),
    );
  }
}

/// The app opening: this device's saved account read back, then where this
/// player sits. 01's village and title, so it reads as the game opening,
/// and under them the one waiting body ([Waiting]): the lanterns, "Still
/// on its way." when it is slow, "One moment" once a try got no
/// answer (it is made again by itself; [onRetry] makes it now). No field
/// and no button: nothing here can make a second account.
class OpeningWait extends StatelessWidget {
  const OpeningWait({super.key, this.unanswered = false, this.onRetry});

  final bool unanswered;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => DressScope(
    dress: JoinView.defaultDress,
    child: Builder(builder: _build),
  );

  // Dressed as 01 is, so the opening does not change look under the form.
  Widget _build(BuildContext context) {
    final skin = context.skin;
    return ScreenFrame(
      ground: GroundKind.night,
      // Its one light is the lantern by the door in the picture.
      mood: MoodKind.lantern,
      topArt: skin.art.streetDoor,
      topArtLayout: TopArtLayout.fill,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: FitLine(JoinCopy.title, style: skin.typography.heroTitle),
          ),
          // The lanterns hang from the title, as from a sign.
          Waiting(failing: unanswered, onRetry: onRetry),
        ],
      ),
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
