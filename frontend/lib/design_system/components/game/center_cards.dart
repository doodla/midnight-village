// OLD LOOK: delete when 06 Night action is rebuilt
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Fixed card dimensions in dp — layout constants, not visual tokens.
const double _kCardWidth = 72.0;
const double _kCardHeight = 100.0;
const double _kCardBorderRadius = 8.0;
const double _kSelectedBorderWidth = 2.5;
const double _kDefaultBorderWidth = 1.5;

/// Shows a row of face-down center cards with optional tap-to-select behavior.
///
/// Selected cards are indicated with a [AppColorTokens.primary] border.
/// Cards are labeled "Card 1", "Card 2", etc.
///
/// [maxSelections] controls how many cards can be selected simultaneously.
/// When the limit is reached, unselected cards are dimmed and non-tappable.
class CenterCards extends ConsumerStatefulWidget {
  /// Number of center cards to display (typically 3 in ONUW).
  final int cardCount;

  /// Maximum number of cards that can be selected at once (1 or 2).
  final int maxSelections;

  /// Called whenever the selection changes with the list of selected indices.
  final ValueChanged<List<int>>? onSelectionChanged;

  const CenterCards({
    super.key,
    required this.cardCount,
    required this.maxSelections,
    this.onSelectionChanged,
  });

  @override
  ConsumerState<CenterCards> createState() => _CenterCardsState();
}

class _CenterCardsState extends ConsumerState<CenterCards> {
  final List<int> _selectedIndices = [];

  void _handleTap(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else if (_selectedIndices.length < widget.maxSelections) {
        _selectedIndices.add(index);
      }
    });
    widget.onSelectionChanged?.call(List.unmodifiable(_selectedIndices));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(activeThemeProvider);
    final bool maxReached = _selectedIndices.length >= widget.maxSelections;

    return Semantics(
      label: 'Center cards',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.cardCount, (index) {
          final bool isSelected = _selectedIndices.contains(index);
          final bool canTap =
              widget.onSelectionChanged != null && (isSelected || !maxReached);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
            child: _CenterCardTile(
              index: index,
              isSelected: isSelected,
              canTap: canTap,
              tokens: tokens,
              onTap: canTap ? () => _handleTap(index) : null,
            ),
          );
        }),
      ),
    );
  }
}

/// A single face-down card tile with selection state.
class _CenterCardTile extends StatelessWidget {
  final int index;
  final bool isSelected;
  final bool canTap;
  final AppTokens tokens;
  final VoidCallback? onTap;

  const _CenterCardTile({
    required this.index,
    required this.isSelected,
    required this.canTap,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isSelected
        ? tokens.colors.primary
        : tokens.colors.outline;
    final double borderWidth = isSelected
        ? _kSelectedBorderWidth
        : _kDefaultBorderWidth;
    final double opacity = (!canTap && !isSelected) ? 0.45 : 1.0;

    final String label = 'Card ${index + 1}${isSelected ? ', selected' : ''}';

    return Semantics(
      label: label,
      button: canTap,
      onTapHint: canTap ? 'select card' : null,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: _kCardWidth,
            height: _kCardHeight,
            decoration: BoxDecoration(
              color: tokens.colors.cardBack,
              borderRadius: BorderRadius.circular(_kCardBorderRadius),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Center(
              child: Text(
                'Card\n${index + 1}',
                style: tokens.typography.caption.copyWith(
                  color: tokens.colors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
