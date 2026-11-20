import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/host/host_change.dart';

import '../../helpers/contract/contract_samples.dart';

void main() {
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
}
