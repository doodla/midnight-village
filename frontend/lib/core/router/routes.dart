import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/home_screen.dart';
import '../../features/game/presentation/game_container_screen.dart';
import '../../features/lobby/presentation/lobby_screen.dart';

part 'routes.g.dart';

/// Home route - the MVP single screen.
@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

/// Lobby route — join or wait in a game lobby identified by [code].
@TypedGoRoute<LobbyRoute>(path: '/lobby/:code')
class LobbyRoute extends GoRouteData with $LobbyRoute {
  const LobbyRoute({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      LobbyScreen(code: code);
}

/// Game route — active game screen identified by [gameId].
///
/// [lobby] is the code of the table the game belongs to (`?lobby=CODE`). The
/// game's own state may not say, and the results screen needs it to start
/// another game or leave the table.
@TypedGoRoute<GameRoute>(path: '/game/:gameId')
class GameRoute extends GoRouteData with $GameRoute {
  const GameRoute({required this.gameId, this.lobby});

  final String gameId;
  final String? lobby;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      GameContainerScreen(gameId: gameId, lobbyCode: lobby);
}
