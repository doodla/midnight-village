// OLD LOOK: delete when 01 Join, 02 Table and the game screens (04 to 11) are rebuilt
@Deprecated(
  'OLD LOOK: delete when 01 Join, 02 Table and the game screens (04 to 11) are rebuilt. Build screens from lib/design_system/primitives/ instead.',
)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// A centered loading indicator with an optional message.
///
/// The spinner color uses the primary token. The optional [message]
/// is rendered below the spinner using body typography.
class MvLoading extends ConsumerWidget {
  final String? message;

  const MvLoading({super.key, this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(tokens.colors.primary),
          ),
          if (message != null) ...[
            SizedBox(height: tokens.spacing.md),
            Text(
              message!,
              style: tokens.typography.body.copyWith(
                color: tokens.colors.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
