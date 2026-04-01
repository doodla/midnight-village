import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/home_screen.dart';

part 'routes.g.dart';

/// Home route - the MVP single screen.
@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

/// Lobby route — join or wait in a game lobby identified by [code].
///
/// Real lobby screen is wired in WP06.
@TypedGoRoute<LobbyRoute>(path: '/lobby/:code')
class LobbyRoute extends GoRouteData with $LobbyRoute {
  const LobbyRoute({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      Scaffold(body: Center(child: Text('Lobby: $code')));
}

/// Game route — active game screen identified by [gameId].
///
/// Real game container is wired in WP07.
@TypedGoRoute<GameRoute>(path: '/game/:gameId')
class GameRoute extends GoRouteData with $GameRoute {
  const GameRoute({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      Scaffold(body: Center(child: Text('Game: $gameId')));
}
