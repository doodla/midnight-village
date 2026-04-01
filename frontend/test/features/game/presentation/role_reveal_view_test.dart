import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/game/presentation/role_reveal_view.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';

void main() {
  group('RoleRevealView', () {
    testWidgets('displays the role name', (tester) async {
      await tester.pumpWithTokens(
        RoleRevealView(roleId: RoleId.seer, onComplete: () {}),
      );

      // Role name appears in both the heading and the RoleCard.
      expect(find.text('Seer'), findsAtLeastNWidgets(1));
      // Ensure the "You are the" text is present.
      expect(find.text('You are the'), findsOneWidget);

      // Clean up: advance past the 4-second timer so no pending timers remain.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('displays a RoleCard', (tester) async {
      await tester.pumpWithTokens(
        RoleRevealView(roleId: RoleId.werewolf, onComplete: () {}),
      );

      expect(find.byType(RoleCard), findsAtLeastNWidgets(1));

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('displays "You are the" heading text', (tester) async {
      await tester.pumpWithTokens(
        RoleRevealView(roleId: RoleId.villager, onComplete: () {}),
      );

      expect(find.text('You are the'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('onComplete not called before 4 seconds', (tester) async {
      bool completed = false;
      await tester.pumpWithTokens(
        RoleRevealView(
          roleId: RoleId.mason,
          onComplete: () => completed = true,
        ),
      );

      await tester.pump(const Duration(seconds: 3));
      expect(completed, isFalse);

      // Advance past the 4-second threshold.
      await tester.pump(const Duration(seconds: 2));
      expect(completed, isTrue);
    });

    testWidgets('auto-advance timer fires after 4 seconds', (tester) async {
      bool completed = false;
      await tester.pumpWithTokens(
        RoleRevealView(
          roleId: RoleId.robber,
          onComplete: () => completed = true,
        ),
      );

      // Not fired yet before 4 seconds.
      await tester.pump(const Duration(seconds: 3));
      expect(completed, isFalse);

      // Fires at or after 4 seconds.
      await tester.pump(const Duration(seconds: 2));
      expect(completed, isTrue);
    });

    testWidgets('renders correctly for all role types', (tester) async {
      for (final role in RoleId.values) {
        await tester.pumpWithTokens(
          RoleRevealView(roleId: role, onComplete: () {}),
        );
        // Role name appears at least once (in heading text or RoleCard).
        expect(
          find.text(role.displayName),
          findsAtLeastNWidgets(1),
          reason: 'Expected role name for ${role.name}',
        );
        // Advance past timer so no pending timers on next iteration.
        await tester.pump(const Duration(seconds: 5));
      }
    });
  });
}
