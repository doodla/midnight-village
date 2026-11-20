// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $homeRoute,
  $joinRoute,
  $lobbyRoute,
  $gameRoute,
];

RouteBase get $homeRoute =>
    GoRouteData.$route(path: '/', factory: $HomeRoute._fromState);

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $joinRoute =>
    GoRouteData.$route(path: '/join/:code', factory: $JoinRoute._fromState);

mixin $JoinRoute on GoRouteData {
  static JoinRoute _fromState(GoRouterState state) =>
      JoinRoute(code: state.pathParameters['code']!);

  JoinRoute get _self => this as JoinRoute;

  @override
  String get location =>
      GoRouteData.$location('/join/${Uri.encodeComponent(_self.code)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $lobbyRoute =>
    GoRouteData.$route(path: '/lobby/:code', factory: $LobbyRoute._fromState);

mixin $LobbyRoute on GoRouteData {
  static LobbyRoute _fromState(GoRouterState state) =>
      LobbyRoute(code: state.pathParameters['code']!);

  LobbyRoute get _self => this as LobbyRoute;

  @override
  String get location =>
      GoRouteData.$location('/lobby/${Uri.encodeComponent(_self.code)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $gameRoute =>
    GoRouteData.$route(path: '/game/:gameId', factory: $GameRoute._fromState);

mixin $GameRoute on GoRouteData {
  static GameRoute _fromState(GoRouterState state) =>
      GameRoute(gameId: state.pathParameters['gameId']!);

  GameRoute get _self => this as GameRoute;

  @override
  String get location =>
      GoRouteData.$location('/game/${Uri.encodeComponent(_self.gameId)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
