import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// A themed scaffold with responsive layout constraints.
///
/// On viewports wider than 600px, the body is centered with a maximum
/// width of 600px and horizontal padding of [AppSpacingTokens.l].
/// On narrow viewports, horizontal padding is [AppSpacingTokens.m].
///
/// The [AppBar] is only rendered when [title], [showBackButton], or
/// [actions] are provided.
class MvScaffold extends ConsumerWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final bool showBackButton;

  const MvScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.bottomBar,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    final showAppBar =
        title != null ||
        showBackButton ||
        (actions != null && actions!.isNotEmpty);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: tokens.colors.surface,
              foregroundColor: tokens.colors.onSurface,
              title: title != null
                  ? Text(
                      title!,
                      style: tokens.typography.heading.copyWith(
                        color: tokens.colors.onSurface,
                      ),
                    )
                  : null,
              actions: actions,
              automaticallyImplyLeading: showBackButton,
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.lg,
                    ),
                    child: body,
                  ),
                ),
              );
            }
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
              child: body,
            );
          },
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
