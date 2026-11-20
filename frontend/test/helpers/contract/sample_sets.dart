import 'contract_samples.dart';

/// Every recorded protocol-2 `/me/` sample, by its name under `http/game/`.
List<String> protocolTwoMeSamples() => [
  for (final s in ContractSamples.index)
    if (s.isHttp &&
        s.status == 200 &&
        s.matchesPath('/onuw/games/g/me/') &&
        ContractSamples.protocolOf(s) == NightProtocol.two)
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
