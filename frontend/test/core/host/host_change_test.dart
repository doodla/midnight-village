import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/host/host_change.dart';

import '../../helpers/contract/contract_samples.dart';
import '../../helpers/contract/from_sample.dart';
import '../../helpers/game_events.dart';

void main() {
  final handover = FromSample.hostChange(
    GameEvents.hostChanged(hostId: 2, hostName: 'Ben', originalHostId: 1),
  );
  final returned = FromSample.hostChange(
    GameEvents.hostChanged(
      hostId: 1,
      hostName: 'Ana',
      originalHostId: 1,
      reason: 'returned',
    ),
  );
  final transferred = FromSample.hostChange(
    GameEvents.hostChanged(
      hostId: 2,
      hostName: 'Ben',
      originalHostId: 2,
      reason: 'transferred',
    ),
  );

  group('HostChange.fromEvent', () {
    test('reads each recorded host_changed event', () {
      for (final name in [
        'ws/game/host_changed_handover',
        'ws/game/host_changed_returned',
        'ws/lobby/host_changed_transferred',
      ]) {
        final event = ContractSamples.map(name);
        final change = HostChange.fromEvent(event);
        expect(change.hostId, event['host_id']);
        expect(change.hostName, event['host_name']);
        expect(change.originalHostId, event['original_host_id']);
        expect(change.reason.name, event['reason']);
      }
    });
  });

  group('hostChangeLine', () {
    test('transferred reads "Ben is the host now" to everyone else', () {
      expect(
        hostChangeLine(change: transferred, viewerId: 3),
        'Ben is the host now',
      );
      expect(
        hostChangeLine(change: transferred, viewerId: 1),
        'Ben is the host now',
      );
    });

    test('transferred reads "You are the host now" to the new host', () {
      expect(
        hostChangeLine(change: transferred, viewerId: 2),
        'You are the host now',
      );
    });

    test(
      'handover reads "Ben is hosting while Ana is away" to a bystander',
      () {
        expect(
          hostChangeLine(
            change: handover,
            viewerId: 3,
            originalHostName: 'Ana',
          ),
          'Ben is hosting while Ana is away',
        );
      },
    );

    test(
      'handover reads "You are hosting while Ana is away" to the new host',
      () {
        expect(
          hostChangeLine(
            change: handover,
            viewerId: 2,
            originalHostName: 'Ana',
          ),
          'You are hosting while Ana is away',
        );
      },
    );

    test(
      'handover reads "Ben is hosting while you are away" to the old host',
      () {
        expect(
          hostChangeLine(
            change: handover,
            viewerId: 1,
            originalHostName: 'Ana',
          ),
          'Ben is hosting while you are away',
        );
      },
    );

    test('handover falls back to "the host" without the original name', () {
      expect(
        hostChangeLine(change: handover, viewerId: 3),
        'Ben is hosting while the host is away',
      );
    });

    test('returned reads "Ana is hosting again" to everyone else', () {
      expect(
        hostChangeLine(change: returned, viewerId: 3),
        'Ana is hosting again',
      );
      expect(
        hostChangeLine(change: returned, viewerId: 2),
        'Ana is hosting again',
      );
    });

    test('returned reads "You are hosting again" to the returning host', () {
      expect(
        hostChangeLine(change: returned, viewerId: 1),
        'You are hosting again',
      );
    });
  });
}
