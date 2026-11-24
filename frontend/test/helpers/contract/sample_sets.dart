import 'package:midnight_village/features/game/domain/screen_table.dart';

import 'contract_samples.dart';

/// The screen each recorded `/me/` is (the first-time play spec, section 3,
/// as amended by sections 7 and 8), at its own game's table with no local
/// step taken, read from the sample's own words: the results phase is the
/// end board; else its stage names the screen, the look is your card (04),
/// a night window the night board (05), the talk 08, the vote 09. A sample
/// whose stage is none of these fails here, and so does `screen_table_test`.
Map<String, AppScreen> get meScreens => {
  for (final name in meSamples())
    name: _screenOf(ContractSamples.map('http/game/$name')),
};

AppScreen _screenOf(Map<String, dynamic> me) {
  if (me['phase'] == 'results') return AppScreen.end;
  final stage = (me['stage'] as String).split('.').first;
  return switch (stage) {
    'look' => AppScreen.yourCard,
    'w1' || 'w2' => AppScreen.nightBoard,
    'talk' => AppScreen.talk,
    'vote' => AppScreen.vote,
    _ => throw StateError('a /me/ at stage "$stage": say which screen it is'),
  };
}

/// Every recorded `/me/` sample, by its name under `http/game/`.
List<String> meSamples() => [
  for (final s in ContractSamples.index)
    if (s.isHttp && s.status == 200 && s.matchesPath('/onuw/games/g/me/'))
      s.name.substring('http/game/'.length),
];

/// Every recorded lobby body (a lobby answer, or `lobby_update`'s data),
/// with its sample's name.
List<(String, Map<String, dynamic>)> lobbyBodies() => [
  for (final s in ContractSamples.index)
    if (s.isHttp &&
        s.name.startsWith('http/lobby/') &&
        (s.status == 200 || s.status == 201) &&
        ContractSamples.map(s.name).containsKey('code'))
      (s.name, ContractSamples.map(s.name)),
  (
    'ws/lobby/lobby_update',
    (ContractSamples.map('ws/lobby/lobby_update')['data'] as Map)
        .cast<String, dynamic>(),
  ),
];
