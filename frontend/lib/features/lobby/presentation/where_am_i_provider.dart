import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/where_am_i.dart';
import 'lobby_notifier.dart';

part 'where_am_i_provider.g.dart';

/// Where this player sits (`GET /me/table/`): the first fetch of a cold
/// start, and fetched again (invalidated) when the table moves on (play
/// again, leave). Null: at no table.
@riverpod
Future<MyTable?> myTable(Ref ref) =>
    ref.watch(lobbyServiceProvider).fetchMyTable();

/// The clock the app compares server deadlines with. Tests set it.
@riverpod
DateTime Function() clock(Ref ref) => DateTime.now;
