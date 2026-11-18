import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/host/host_change.dart';

void main() {
  const handover = HostChange(
    hostId: 2,
    hostName: 'Ben',
    originalHostId: 1,
    reason: HostChangeReason.handover,
  );
  const returned = HostChange(
    hostId: 1,
    hostName: 'Ana',
    originalHostId: 1,
    reason: HostChangeReason.returned,
  );

  group('HostChange.fromEvent', () {
    test('reads the host_changed event', () {
      final change = HostChange.fromEvent({
        'type': 'host_changed',
        'host_id': 2,
        'host_name': 'Ben',
        'original_host_id': 1,
        'reason': 'handover',
      });

      expect(change, handover);
    });

    test('reads a returned event', () {
      final change = HostChange.fromEvent({
        'host_id': 1,
        'host_name': 'Ana',
        'original_host_id': 1,
        'reason': 'returned',
      });

      expect(change?.reason, HostChangeReason.returned);
    });

    test('is null for an unknown reason or a missing host', () {
      expect(HostChange.fromEvent({'host_id': 2, 'reason': 'mystery'}), isNull);
      expect(HostChange.fromEvent({'reason': 'handover'}), isNull);
    });
  });

  group('hostChangeLine', () {
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
