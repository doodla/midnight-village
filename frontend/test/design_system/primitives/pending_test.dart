import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/pending.dart';

/// One control's request ([Pending]): busy at once, never twice, done or a
/// failure with its own "Try again", and nothing left over when its screen
/// is gone.
void main() {
  test('is busy the moment it is run, before anything is sent', () async {
    final pending = Pending();
    final seen = <PendingPhase>[];
    pending.addListener(() => seen.add(pending.phase));
    final reply = Completer<void>();
    var sent = false;
    final done = pending.run(() {
      sent = true;
      return reply.future;
    });
    expect(pending.busy, isTrue);
    expect(seen, [
      PendingPhase.busy,
    ], reason: 'listeners (the control) hear it synchronously, in the tap');
    expect(sent, isTrue);
    reply.complete();
    expect(await done, isTrue);
    expect(pending.phase, PendingPhase.idle);
  });

  test('cannot be sent twice while it is on its way', () async {
    final pending = Pending();
    final reply = Completer<void>();
    var sends = 0;
    final first = pending.run(() {
      sends++;
      return reply.future;
    });
    expect(await pending.run(() async => sends++), isFalse);
    expect(sends, 1);
    reply.complete();
    await first;
    expect(await pending.run(() async => sends++), isTrue);
    expect(sends, 2);
  });

  test('a request that did not get through is "Not sent." with "Try again", '
      'which sends exactly the same request', () async {
    final pending = Pending();
    var sends = 0;
    Future<void> send() async {
      sends++;
      if (sends == 1) throw StateError('no answer');
    }

    expect(await pending.run(send), isFalse);
    expect(pending.failed, isTrue);
    expect(pending.failure?.words, BannerCopy.notSent);
    expect(pending.failure?.canRetry, isTrue);

    expect(await pending.retry(), isTrue);
    expect(sends, 2);
    expect(pending.phase, PendingPhase.idle);
    expect(pending.failure, isNull, reason: 'the failure goes with the retry');
  });

  test('a refusal says why, never "Not sent."', () async {
    final pending = Pending();
    await pending.run(
      () async => throw const RequestRefused(BannerCopy.lobbyClosed),
    );
    expect(pending.failure?.words, BannerCopy.lobbyClosed);
    expect(pending.failure?.canRetry, isFalse);
  });

  test(
    'busy lasts until the screen it leads to is up, not the answer',
    () async {
      final pending = Pending();
      final screen = Completer<void>();
      final done = pending.run(
        () async {},
        settle: (_) async {
          await screen.future;
          return true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        pending.busy,
        isTrue,
        reason: 'the request is answered; the next screen is not up',
      );
      screen.complete();
      expect(await done, isTrue);
      expect(pending.phase, PendingPhase.idle);
    },
  );

  test('a read of the next screen that is failing frees the control and says '
      '"One moment" with "Try again", which reads again and never sends the '
      'request twice', () async {
    final pending = Pending();
    var sends = 0;
    var reads = 0;
    Future<bool> read(bool again) async => ++reads >= 2;
    expect(
      await pending.run(() async => sends++, settle: read),
      isTrue,
      reason: 'the request worked',
    );
    expect(pending.failed, isTrue);
    expect(pending.failure?.words, BannerCopy.offline);
    expect(pending.failure?.canRetry, isTrue);

    expect(await pending.retry(), isTrue);
    expect(sends, 1, reason: 'the answered request is not sent again');
    expect(reads, 2);
    expect(pending.phase, PendingPhase.idle);
  });

  test('a read that throws is a failing read too', () async {
    final pending = Pending();
    await pending.run(
      () async {},
      settle: (_) async => throw StateError('not read yet'),
    );
    expect(pending.failure?.words, BannerCopy.offline);
  });

  test('a screen that goes while its request is out is left alone: no '
      'listener is told, nothing is thrown', () async {
    final pending = Pending();
    final reply = Completer<void>();
    final done = pending.run(() => reply.future);
    var told = 0;
    pending.addListener(() => told++);
    pending.dispose();
    reply.completeError(StateError('late'));
    await done;
    expect(told, 0);
  });
}
