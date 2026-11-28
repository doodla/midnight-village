import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which of the app's sockets are up now, by name ([game], [lobby]).
///
/// A poll heals a missing socket, never a healthy one: an event the server
/// sends reaches a socket that is up, and a socket that comes back (or opens)
/// reads what its screen depends on itself (`docs/dev/models/phone/seat/`). So
/// the slow table poll asks only while the socket that would hear its news is
/// not up (`myTableProvider`). Each socket reports itself: the game's in
/// `LiveGameNotifier`, the table's in `LobbyNotifier`.
class SocketHealth {
  final Set<String> _up = {};

  /// The name of game [gameId]'s socket.
  static String game(String gameId) => 'game:$gameId';

  /// The name of table [code]'s lobby socket.
  static String lobby(String code) => 'lobby:$code';

  /// Socket [name] is [up], or not (down, trying again, closed).
  void report(String name, {required bool up}) =>
      up ? _up.add(name) : _up.remove(name);

  /// Whether socket [name] is up now.
  bool isUp(String name) => _up.contains(name);
}

/// The one [SocketHealth] of the app.
final socketHealthProvider = Provider<SocketHealth>(
  (ref) => SocketHealth(),
  name: 'socketHealthProvider',
);
