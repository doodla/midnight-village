import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/game/presentation/shell/game_entry.dart';
import '../../features/lobby/presentation/home_gate.dart';

part 'routes.g.dart';

/// Home: the table's shell when signed in (01 at no table, 02 at a waiting
/// table, the game in a game), else 01 Join.
@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeGate();
}

/// A table's link (its QR code, Share): 01 with the name and "Join", or the
/// table itself for a player who already sits at it.
@TypedGoRoute<JoinRoute>(path: '/join/:code')
class JoinRoute extends GoRouteData with $JoinRoute {
  const JoinRoute({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      HomeGate(code: code.toUpperCase());
}

/// A table by its code: the old game screen goes here after play again.
/// The table a player sits at is `/me/table/`'s, so this is home.
@TypedGoRoute<LobbyRoute>(path: '/lobby/:code')
class LobbyRoute extends GoRouteData with $LobbyRoute {
  const LobbyRoute({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeGate();
}

/// Game route — active game screen identified by [gameId]. The table it
/// belongs to comes with the game's state (`lobby_code` in every phase).
/// [GameEntry] decides by the game's night protocol: the rebuilt shell for
/// protocol 2, the old game screen for protocol 1.
@TypedGoRoute<GameRoute>(path: '/game/:gameId')
class GameRoute extends GoRouteData with $GameRoute {
  const GameRoute({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      GameEntry(gameId: gameId);
}
