import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// A themed card with optional header and footer sections.
///
/// Header and footer are separated from the body by a divider.
class MvCard extends ConsumerWidget {
  final Widget child;
  final Widget? header;
  final Widget? footer;
  final double? elevation;
  final EdgeInsets? padding;

  const MvCard({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.elevation,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    return Card(
      color: tokens.colors.surface,
      elevation: elevation ?? tokens.elevation.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(tokens.spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) ...[
              header!,
              Divider(color: tokens.colors.outline, height: 1),
            ],
            child,
            if (footer != null) ...[
              Divider(color: tokens.colors.outline, height: 1),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
