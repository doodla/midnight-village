import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/core/primary_button.dart';
import '../../../design_system/tokens/app_tokens_provider.dart';

/// "Waiting for Mira to reconnect" -- one quiet line, the same on every phone.
///
/// Names only. Whether a phone is connected is public to the table, so this
/// says nothing about roles or about who has acted. Renders nothing when
/// [names] is empty.
class AwayNotice extends ConsumerWidget {
  const AwayNotice({super.key, required this.names});

  /// Display names of the players who are away, in table order.
  final List<String> names;

  /// The sentence for [names]: "Mira", "Mira and Tom", "Mira, Tom and Sam".
  static String sentence(List<String> names) {
    final who = names.length <= 1
        ? names.join()
        : '${names.sublist(0, names.length - 1).join(', ')} '
              'and ${names.last}';
    return 'Waiting for $who to reconnect';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (names.isEmpty) return const SizedBox.shrink();
    final tokens = ref.watch(activeThemeProvider);
    return Text(
      sentence(names),
      key: const ValueKey('away-notice'),
      style: tokens.typography.caption.copyWith(
        color: tokens.colors.onDisabled,
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// The host's way to carry on when someone has dropped: a clearly labelled
/// button that calls [onPressed] and says so in plain words when it fails.
///
/// Only the host is given one; the screens build it for the host alone.
class HostContinueControl extends ConsumerStatefulWidget {
  const HostContinueControl({
    super.key,
    required this.label,
    required this.onPressed,
  });

  /// "Continue without them" at night, "Reveal votes now" in the vote.
  final String label;

  /// The server call. The screen follows the game's own events afterwards.
  final Future<void> Function() onPressed;

  @override
  ConsumerState<HostContinueControl> createState() =>
      _HostContinueControlState();
}

class _HostContinueControlState extends ConsumerState<HostContinueControl> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _press() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onPressed();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(activeThemeProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton.outlined(
          label: widget.label,
          isLoading: _busy,
          onPressed: _press,
        ),
        if (_failed) ...[
          SizedBox(height: tokens.spacing.xs),
          Text(
            'That did not work. Try again.',
            key: const ValueKey('host-continue-error'),
            style: tokens.typography.caption.copyWith(
              color: tokens.colors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
