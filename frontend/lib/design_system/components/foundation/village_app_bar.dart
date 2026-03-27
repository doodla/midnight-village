import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tokens/app_tokens.dart';
import '../../tokens/app_tokens_provider.dart';

enum _VillageAppBarVariant { brand, back, phase, minimal }

/// A themed app bar with 4 variants for the Midnight Village design system.
///
/// - [VillageAppBar.brand] — castle icon + "Midnight Village" title; for home screens.
/// - [VillageAppBar.back] — back arrow + custom title; for detail screens.
/// - [VillageAppBar.phase] — phase label in gold; for active game phases.
/// - [VillageAppBar.minimal] — role name with optional icon; for role screens.
///
/// Transparent background integrates with [AtmosphericBackground].
class VillageAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final _VillageAppBarVariant _variant;
  final String? _title;
  final String? _label;
  final String? _roleName;
  final IconData? _icon;

  /// Optional widget rendered in the trailing (actions) slot.
  final Widget? trailing;

  const VillageAppBar.brand({super.key, this.trailing})
      : _variant = _VillageAppBarVariant.brand,
        _title = null,
        _label = null,
        _roleName = null,
        _icon = null;

  const VillageAppBar.back({super.key, required String title, this.trailing})
      : _variant = _VillageAppBarVariant.back,
        _title = title,
        _label = null,
        _roleName = null,
        _icon = null;

  const VillageAppBar.phase({super.key, required String label, this.trailing})
      : _variant = _VillageAppBarVariant.phase,
        _title = null,
        _label = label,
        _roleName = null,
        _icon = null;

  const VillageAppBar.minimal({
    super.key,
    required String roleName,
    IconData? icon,
    this.trailing,
  })  : _variant = _VillageAppBarVariant.minimal,
        _title = null,
        _label = null,
        _roleName = roleName,
        _icon = icon;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: _buildLeading(context),
      title: _buildTitle(tokens),
      actions: trailing != null ? [trailing!] : null,
    );
  }

  Widget? _buildLeading(BuildContext context) => switch (_variant) {
        _VillageAppBarVariant.brand => const Icon(Icons.castle),
        _VillageAppBarVariant.back => IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        _ => null,
      };

  Widget? _buildTitle(AppTokens tokens) => switch (_variant) {
        _VillageAppBarVariant.brand => const Text('Midnight Village'),
        _VillageAppBarVariant.back => Text(_title ?? ''),
        _VillageAppBarVariant.phase => Text(
            _label ?? '',
            style: tokens.typography.phaseLabel.copyWith(
              color: tokens.colors.secondary,
            ),
          ),
        _VillageAppBarVariant.minimal => _icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon),
                  SizedBox(width: tokens.spacing.xs),
                  Text(_roleName ?? ''),
                ],
              )
            : Text(_roleName ?? ''),
      };
}
