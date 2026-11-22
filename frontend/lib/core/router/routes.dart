import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

/// A game's link (the debug toolbar opens one; an old address may still name
/// one): home, the same gate, so nothing is read before the saved account
/// is; signed in, the table's shell, which shows what `/me/table/` and the
/// table's game's `/me/` say ([gameId] is the link's, not an input).
@TypedGoRoute<GameRoute>(path: '/game/:gameId')
class GameRoute extends GoRouteData with $GameRoute {
  const GameRoute({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeGate();
}
