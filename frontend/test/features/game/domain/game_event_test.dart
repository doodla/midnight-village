import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_event.dart';
import 'package:midnight_village/features/game/domain/stage_progress.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';

void main() {
  GameEvent event(String name) =>
      FromSample.event(ContractSamples.map('ws/game/$name'));

  test('every game socket event a phone hears is read', () {
    // The types each seat heard in the recorded stretches.
    final heard = {
      for (final s in ContractSamples.index)
        if (s.isSequence) ...ContractSamples.sequenceEventTypes(s.name),
    };
    expect(heard, containsAll(['progress', 'night_window', 'phase_change']));
    for (final sample in ContractSamples.index) {
      if (!sample.isEvent || sample.socket != 'game') continue;
      if (!heard.contains(sample.type)) continue;
      expect(
        event(sample.name.substring('ws/game/'.length)),
        isNot(isA<IgnoredEvent>()),
        reason: '${sample.name} is heard at a table',
      );
    }
  });

  test('a window opening, a phase, the votes, the end: fetch', () {
    for (final name in [
      'night_window_1',
      'night_window_2',
      'night_window_2_doppelganger',
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

  test('a type the phone does not know, or no event at all, means nothing', () {
    // A recorded event under a type the server may add later (the consumers
    // drop unknown types; so does the app).
    for (final type in ['wave_complete', 'action_prompt', 'later_event']) {
      expect(
        GameEvent.parse({
          ...ContractSamples.map('ws/game/night_window_2'),
          'type': type,
        }),
        isA<IgnoredEvent>(),
        reason: type,
      );
    }
    expect(GameEvent.parse('not json'), isA<IgnoredEvent>());
    expect(GameEvent.parse(42), isA<IgnoredEvent>());
  });
}
