import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/domain/where_am_i.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/live_game_setup.dart' show testHealTiming;

// The seat an answer names (`SeatSeed`, `seatFromServer`): used by the one
// read asked for with it, for its own account, never kept for a later read.

class _Service extends Mock implements LobbyService {}

const _ana = 1;
const _code = 'K7QX4M';

/// The table Ana started, as the server answers it (Ana and Bo seated).
final _lobby = FromSample.lobby(
  serverLobby(
    code: _code,
    seats: [(id: _ana, name: 'Ana'), (id: 2, name: 'Bo')],
    hostId: _ana,
  ),
);

/// What `/me/table/` says when it is asked: another table (so a read that
/// went to the server is told apart from the seed).
final _server = FromSample.myTable(serverMyTable(code: 'V9YC2J'));

/// A provider that hands the test a `Ref`, as the app's notifiers have.
final _refProvider = Provider<Ref>((ref) => ref);

({ProviderContainer container, _Service service, Ref ref}) _phone() {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final service = _Service();
  when(service.fetchMyTable).thenAnswer((_) async => _server);
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWithValue(
        AuthState.authenticated(User(id: _ana, displayName: 'Ana')),
      ),
      lobbyServiceProvider.overrideWithValue(service),
      devicePreferencesProvider.overrideWithValue(DevicePreferences()),
      healTimingProvider.overrideWithValue(testHealTiming),
    ],
  );
  addTearDown(container.dispose);
  container.listen(_refProvider, (_, _) {});
  return (
    container: container,
    service: service,
    ref: container.read(_refProvider),
  );
}

void main() {
  test('the seat the answer names is the next read, with no request; the '
      'read after it asks the server', () async {
    final p = _phone();
    final seat = MyTable.seatedAt(_lobby, viewerId: _ana)!;

    final held = holdSeatFromAnswer(p.ref, _ana, seat);
    addTearDown(held.close);
    final first = await p.container.read(myTableProvider.future);

    expect(first, same(seat));
    expect(first!.isHost, isTrue);
    verifyNever(p.service.fetchMyTable);

    // Used once: the next read is the server's.
    p.container.invalidate(myTableProvider);
    final second = await p.container.read(myTableProvider.future);
    expect(second!.lobbyCode, 'V9YC2J');
    verify(p.service.fetchMyTable).called(1);
  });

  test(
    'a seed for another account is dropped: the read asks the server',
    () async {
      final p = _phone();
      // Bo's seat (another account than the one signed in).
      final bos = MyTable.seatedAt(_lobby, viewerId: 2)!;

      final held = holdSeatFromAnswer(p.ref, 2, bos);
      addTearDown(held.close);
      final read = await p.container.read(myTableProvider.future);

      expect(read!.lobbyCode, 'V9YC2J');
      verify(p.service.fetchMyTable).called(1);
    },
  );

  test('an answer that does not seat the viewer names no seat: where they '
      'sit is asked', () async {
    final p = _phone();
    final seat = MyTable.seatedAt(_lobby, viewerId: 42);
    expect(seat, isNull);

    final held = holdSeatFromAnswer(p.ref, _ana, seat);
    addTearDown(held.close);
    final read = await p.container.read(myTableProvider.future);

    expect(read!.lobbyCode, 'V9YC2J');
    verify(p.service.fetchMyTable).called(1);
  });

  test('with nothing holding /me/table/, no seat is put: a later read never '
      'finds a stale one', () async {
    final p = _phone();
    expect(p.container.exists(myTableProvider), isFalse);

    seatFromServer(p.ref, _ana, MyTable.seatedAt(_lobby, viewerId: _ana)!);
    // Much later, a screen reads it.
    final sub = p.container.listen(myTableProvider, (_, _) {});
    addTearDown(sub.close);
    final read = await p.container.read(myTableProvider.future);

    expect(read!.lobbyCode, 'V9YC2J');
    verify(p.service.fetchMyTable).called(1);
  });

  test('held, the seat replaces the value at once', () async {
    final p = _phone();
    final sub = p.container.listen(myTableProvider, (_, _) {});
    addTearDown(sub.close);
    await p.container.read(myTableProvider.future);
    clearInteractions(p.service);
    final seat = MyTable.seatedAt(_lobby, viewerId: _ana)!;

    seatFromServer(p.ref, _ana, seat);

    expect(await p.container.read(myTableProvider.future), same(seat));
    verifyNever(p.service.fetchMyTable);
  });
}
