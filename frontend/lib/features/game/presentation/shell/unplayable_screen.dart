import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../lobby/presentation/lobby_notifier.dart';
import '../../../lobby/presentation/where_am_i_provider.dart';

/// A game this app cannot play (its `/me/` has no `stage`: a night from
/// before every table was opened with `defaults: "v2"`): the night's ground,
/// one calm line and "Leave", which leaves the table, so the shell shows 01.
/// It is never fetched again in a loop; a "Leave" that fails can be tapped
/// again.
class UnplayableScreen extends ConsumerStatefulWidget {
  const UnplayableScreen({super.key});

  @override
  ConsumerState<UnplayableScreen> createState() => _UnplayableScreenState();
}

class _UnplayableScreenState extends ConsumerState<UnplayableScreen> {
  bool _busy = false;

  Future<void> _leave() async {
    final code = ref.read(myTableProvider).value?.lobbyCode;
    if (code == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(lobbyServiceProvider).leaveLobby(code);
      ref.invalidate(myTableProvider);
    } catch (e) {
      logger.w('UnplayableScreen: leave failed', error: e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    body: const SizedBox.shrink(),
    actions: [
      Notice(
        message: BannerCopy.cannotPlay,
        action: CommonCopy.leave,
        onAction: _busy ? () {} : _leave,
      ),
    ],
  );
}
