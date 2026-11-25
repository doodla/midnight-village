import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/auth_interceptor.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/finger.dart';
import '../../helpers/shell_setup.dart';

/// This device's secure storage: it answers the read at start, then never
/// answers anything again (on the web its answers come in later tasks,
/// behind the app's frames: here, never). A request that waits for it
/// never leaves.
class _StorageThatGoesQuiet extends Mock implements FlutterSecureStorage {
  _StorageThatGoesQuiet(Map<String, String> values) {
    when(() => read(key: any(named: 'key'))).thenAnswer((i) {
      if (quiet) return Completer<String?>().future;
      return Future.value(values[i.namedArguments[#key]]);
    });
    when(
      () => write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) => Completer<void>().future);
    when(
      () => delete(key: any(named: 'key')),
    ).thenAnswer((_) => Completer<void>().future);
  }

  var quiet = false;
}

/// Lets every microtask run (Dio passes a request on through a chain of
/// them), and nothing else: no timer, no frame, no time.
Future<void> _microtasksOnly() async {
  for (var i = 0; i < 200; i++) {
    await Future<void>.value();
  }
}

void main() {
  testWidgets('a tap\'s request is handed to the HTTP client in the tap\'s '
      'own task, signed with the token held in memory: nothing waits '
      'between the finger and the request', (tester) async {
    const access = 'the-access-token';
    final device = _StorageThatGoesQuiet({
      'access_token': access,
      'refresh_token': 'the-refresh-token',
    });
    final tokens = TokenStorage(storage: device);
    // Start: the saved session is read back.
    expect(await tokens.hasTokens, isTrue);
    device.quiet = true;

    final s = await ShellSetup.pump(
      tester,
      recordedMe('me_discussion_choose_seer'),
      learned: {...Cue.values},
      before: (s) {
        s.answerPost('/night-results/seen/', 'game/night_results_seen');
        // The app's own signer before the mock server, on its client.
        s.http.dio.interceptors.insert(
          0,
          AuthInterceptor(
            tokenStorage: tokens,
            unauthenticatedClient: ApiClient(dio: s.http.dio),
            onAuthFailure: () => fail('signed out'),
          ),
        );
      },
    );
    await s.settle(tester);
    // My night is up by itself as the talk opens: the first touch puts it
    // away.
    await pressAtLikeAFinger(tester, const Offset(4, 400));
    await tester.pumpAndSettle();
    s.answerPost('/ready/', 'game/ready_talk');
    final before = s.posts('/ready/');

    // 08's "Ready to vote", pressed as a finger does; checked as it lifts,
    // before any time passes or any frame is drawn.
    final ready = tester.getCenter(find.byType(PrimaryButton).last);
    final finger = await tester.startGesture(ready);
    for (var i = 0; i < fingerFrames; i++) {
      tester.binding.scheduleFrame();
      await tester.pump(fingerFrame);
    }
    await finger.up();
    await _microtasksOnly();

    expect(
      s.posts('/ready/'),
      before + 1,
      reason:
          'the request left in the tap\'s own task (a storage read, a '
          'timer or a frame on the way would hold it)',
    );
    final sent = s.http.requests.lastWhere((r) => r.path.endsWith('/ready/'));
    expect(sent.headers['Authorization'], 'Bearer $access');

    await s.settle(tester);
    await s.close(tester);
  });
}
