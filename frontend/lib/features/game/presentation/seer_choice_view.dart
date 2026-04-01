import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/components/core/primary_button.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Pre-action choice screen for the Seer (and Doppelganger-as-Seer).
///
/// Presents two options:
///   - "Look at a player's card" → selects `peek_player` action type.
///   - "Look at two center cards" → selects `peek_center` action type.
///
/// After the player taps a choice, [onActionTypeSelected] is called with the
/// selected action type string and the [GameContainerScreen] transitions to
/// [NightSubView.actionPrompt] via [GameNotifier.selectSeerChoice].
class SeerChoiceView extends ConsumerWidget {
  /// The role label for the identity strip (e.g. "Seer" or "Doppelganger").
  final String roleActingAs;

  /// Called with the selected action type string (`peek_player` or `peek_center`).
  final ValueChanged<String> onActionTypeSelected;

  const SeerChoiceView({
    super.key,
    required this.roleActingAs,
    required this.onActionTypeSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Role identity strip.
          Text(
            roleActingAs,
            style: tokens.typography.subheading.copyWith(
              color: tokens.colors.villageTeam,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            'Choose your action',
            style: tokens.typography.body.copyWith(
              color: tokens.colors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.spacing.xxl),
          PrimaryButton(
            label: 'Look at a player\'s card',
            onPressed: () => onActionTypeSelected('peek_player'),
          ),
          SizedBox(height: tokens.spacing.md),
          PrimaryButton(
            label: 'Look at two center cards',
            onPressed: () => onActionTypeSelected('peek_center'),
          ),
        ],
      ),
    );
  }
}
