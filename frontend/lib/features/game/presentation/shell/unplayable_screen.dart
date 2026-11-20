import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../lobby/presentation/join_flow.dart';
import '../../../lobby/presentation/lobby_notifier.dart';
import '../../../lobby/presentation/where_am_i_provider.dart';

/// A game this app cannot play: its first `/me/` has no `stage` (PROTOCOL 1:
/// a night from before every table was opened with `defaults: "v2"`; this
/// screen goes with the server's protocol 1). The night's ground, one calm
/// line and "Leave", which leaves the table, so the shell shows 01. It is
/// never fetched again in a loop. A Leave the server did not answer says
/// "Not sent." with "Try again"; a table already gone is 01 with "This table
/// has closed.".
class UnplayableScreen extends ConsumerStatefulWidget {
  const UnplayableScreen({super.key});

  @override
  ConsumerState<UnplayableScreen> createState() => _UnplayableScreenState();
}

class _UnplayableScreenState extends ConsumerState<UnplayableScreen> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _leave() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final code = (await ref.read(myTableProvider.future))?.lobbyCode;
      if (code != null) await ref.read(lobbyServiceProvider).leaveLobby(code);
      ref.invalidate(myTableProvider);
    } on NotFoundException {
      ref.read(joinFlowProvider.notifier).tableClosed();
      ref.invalidate(myTableProvider);
    } catch (e) {
      logger.w('UnplayableScreen: leave failed', error: e);
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    body: const SizedBox.shrink(),
    actionGap: Space.md,
    actions: [
      Notice(
        message: BannerCopy.cannotPlay,
        action: CommonCopy.leave,
        onAction: _busy ? () {} : _leave,
      ),
      if (_failed)
        Notice(
          message: BannerCopy.notSent,
          action: BannerCopy.tryAgain,
          onAction: _leave,
        ),
    ],
  );
}
