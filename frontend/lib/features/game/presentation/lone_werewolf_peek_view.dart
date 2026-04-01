import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/core/primary_button.dart';
import 'package:midnight_village/design_system/components/game/center_cards.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Allows the lone Werewolf to optionally peek at one center card.
///
/// Shown after a `see_team` action result with no teammates. The player can
/// select one center card and tap "Peek" to submit a `see_team` action with
/// `center_index`, or tap "Skip" to submit with empty targets.
class LoneWerewolfPeekView extends ConsumerStatefulWidget {
  /// Number of center cards to display (typically 3 in ONUW).
  final int centerCardCount;

  /// Called with the action type string and targets map when the player
  /// submits. Action type is always `see_team`.
  final Future<void> Function(String actionType, Map<String, dynamic> targets)
  onSubmit;

  const LoneWerewolfPeekView({
    super.key,
    required this.centerCardCount,
    required this.onSubmit,
  });

  @override
  ConsumerState<LoneWerewolfPeekView> createState() =>
      _LoneWerewolfPeekViewState();
}

class _LoneWerewolfPeekViewState extends ConsumerState<LoneWerewolfPeekView> {
  int? _selectedIndex;

  void _onSelectionChanged(List<int> indices) {
    setState(() {
      _selectedIndex = indices.isNotEmpty ? indices.first : null;
    });
  }

  Future<void> _handlePeek() async {
    if (_selectedIndex == null) return;
    await widget.onSubmit('see_team', {'center_index': _selectedIndex!});
  }

  Future<void> _handleSkip() async {
    await widget.onSubmit('see_team', {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(activeThemeProvider);

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You are the lone Werewolf.',
            style: tokens.typography.subheading.copyWith(
              color: tokens.colors.werewolfTeam,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            'You may look at one center card.',
            style: tokens.typography.body.copyWith(
              color: tokens.colors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.spacing.xxl),
          CenterCards(
            cardCount: widget.centerCardCount,
            maxSelections: 1,
            onSelectionChanged: _onSelectionChanged,
          ),
          SizedBox(height: tokens.spacing.xxl),
          PrimaryButton(
            label: 'Peek',
            onPressed: _selectedIndex != null ? _handlePeek : null,
          ),
          SizedBox(height: tokens.spacing.md),
          PrimaryButton.outlined(label: 'Skip', onPressed: _handleSkip),
        ],
      ),
    );
  }
}
