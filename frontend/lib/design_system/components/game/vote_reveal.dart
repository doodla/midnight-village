import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/models/game_result.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';

/// Displays the vote tally and elimination outcome after voting concludes.
///
/// Shows:
/// - A list of individual votes ("{VoterName} voted for {TargetName}")
/// - A tally of vote counts per player, sorted by vote count descending
/// - The elimination outcome — eliminated players in error color, or
///   "No one was eliminated!" when [eliminatedPlayerIds] is empty
class VoteReveal extends ConsumerWidget {
  /// The full list of individual votes cast this round.
  final List<VoteResult> votes;

  /// Map from player ID to the number of votes they received.
  final Map<String, int> tally;

  /// IDs of players who were eliminated this round. Empty means no one died.
  final List<String> eliminatedPlayerIds;

  const VoteReveal({
    super.key,
    required this.votes,
    required this.tally,
    required this.eliminatedPlayerIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    // Sort tally entries by vote count descending.
    final sortedTally = tally.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final int maxVotes = sortedTally.isNotEmpty ? sortedTally.first.value : 0;

    // Build a name lookup from the votes list for the tally section.
    final Map<String, String> nameById = {};
    for (final v in votes) {
      nameById[v.voterId] = v.voterName;
      nameById[v.targetId] = v.targetName;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------------------
          // Vote list
          // ----------------------------------------------------------------
          Text(
            'Votes',
            style: tokens.typography.heading.copyWith(
              color: tokens.colors.onBackground,
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          ...votes.map(
            (vote) => Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.xs),
              child: Text(
                '${vote.voterName} voted for ${vote.targetName}',
                style: tokens.typography.body.copyWith(
                  color: tokens.colors.onBackground,
                ),
              ),
            ),
          ),

          SizedBox(height: tokens.spacing.lg),

          // ----------------------------------------------------------------
          // Tally section
          // ----------------------------------------------------------------
          Text(
            'Tally',
            style: tokens.typography.heading.copyWith(
              color: tokens.colors.onBackground,
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          ...sortedTally.map((entry) {
            final playerName = nameById[entry.key] ?? entry.key;
            final isTopVoted = entry.value == maxVotes && maxVotes > 0;
            return Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      playerName,
                      style: tokens.typography.body.copyWith(
                        color: isTopVoted
                            ? tokens.colors.primary
                            : tokens.colors.onBackground,
                        fontWeight: isTopVoted
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: tokens.typography.body.copyWith(
                      color: isTopVoted
                          ? tokens.colors.primary
                          : tokens.colors.onBackground,
                      fontWeight: isTopVoted
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),

          SizedBox(height: tokens.spacing.lg),

          // ----------------------------------------------------------------
          // Elimination outcome
          // ----------------------------------------------------------------
          if (eliminatedPlayerIds.isEmpty)
            Text(
              'No one was eliminated!',
              style: tokens.typography.heading.copyWith(
                color: tokens.colors.onSurface,
              ),
            )
          else ...[
            Text(
              'Eliminated: ${_eliminatedNames(nameById)}',
              style: tokens.typography.heading.copyWith(
                color: tokens.colors.error,
              ),
            ),
          ],

          SizedBox(height: tokens.spacing.md),
        ],
      ),
    );
  }

  /// Returns a comma-separated string of eliminated player names.
  /// Falls back to the raw ID if the name is not found in [nameById].
  String _eliminatedNames(Map<String, String> nameById) {
    return eliminatedPlayerIds.map((id) => nameById[id] ?? id).join(', ');
  }
}
