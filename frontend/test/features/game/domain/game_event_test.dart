import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_event.dart';
import 'package:midnight_village/features/game/domain/stage_progress.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';

void main() {
  GameEvent event(String name) =>
      FromSample.event(ContractSamples.map('ws/game/$name'));

  test('every game socket event a protocol-2 phone hears is read', () {
    // The types each seat heard in the recorded protocol-2 stretches.
    final heard = {
      for (final s in ContractSamples.index)
        if (s.isSequence) ...ContractSamples.sequenceEventTypes(s.name),
    };
    expect(
      heard,
      containsAll([
        'progress',
        'night_window',
        'wave_complete',
        'phase_change',
      ]),
    );
    for (final sample in ContractSamples.index) {
      if (!sample.isEvent || sample.socket != 'game') continue;
      if (!heard.contains(sample.type)) continue;
      expect(
        event(sample.name.substring('ws/game/'.length)),
        isNot(isA<IgnoredEvent>()),
        reason: '${sample.name} is heard under protocol 2',
      );
    }
  });

  test('a window opening or closing, a phase, the votes, the end: fetch', () {
    for (final name in [
      'night_window_1',
      'night_window_2',
      'night_window_2_doppelganger',
      'wave_complete_v2',
      'phase_change_discussion',
      'phase_change_voting_untimed',
      'vote_reveal',
      'vote_reveal_with_abstentions',
      'game_results',
      'game_results_tanner',
    ]) {
      expect(event(name), isA<RefetchEvent>(), reason: name);
    }
    expect(event('play_again'), isA<TableMovedEvent>());
  });

  test('progress carries the counts /me/ carries, in the same form', () {
    for (final name in [
      'progress_look',
      'progress_look_open',
      'progress_talk',
      'progress_talk_open',
      'progress_vote',
      'progress_vote_open',
    ]) {
      final json = ContractSamples.map('ws/game/$name');
      final parsed = event(name) as ProgressEvent;
      expect(parsed.progress.stage, ProgressStage.fromServer(json['stage']));
      expect(parsed.progress.done, json['done']);
      expect(parsed.progress.needed, json['needed']);
    }
  });

  test('presence and host changes are read', () {
    final presence = event('player_presence_disconnected') as PresenceEvent;
    expect(presence.connected, isFalse);
    final host = event('host_changed_handover') as HostEvent;
    expect(host.change.hostId, 8);
  });

  // PROTOCOL 1: the server still sends these to a protocol-1 game; the app's
  // samples leave them out, so they are read raw here. Delete this loop with
  // the server's protocol 1.
  test("protocol 1's per-role events mean nothing here", () {
    for (final name in ['action_prompt_seer', 'wave_waiting', 'wave_start']) {
      expect(
        GameEvent.parse(ContractSamples.map('ws/game/$name')),
        isA<IgnoredEvent>(),
        reason: name,
      );
    }
    expect(GameEvent.parse('not json'), isA<IgnoredEvent>());
    expect(GameEvent.parse(42), isA<IgnoredEvent>());
  });
}
