import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/finger.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/table_setup.dart';

// A join that is refused or not sent says so on 01, pressed as a finger
// presses (`pressLikeAFinger`: down, frames, up) on a network that takes frames to answer: the
// busy state is drawn, then the refusal lands. 01 is one screen through it
// (never torn down and built again because a request is busy), so what was
// typed, the focus and the banner all stay. `tester.tap` with an answer at
// once hid this: the request began and ended inside one frame.

/// A finger (the shared press, test/helpers/finger.dart), then a frame.
Future<void> _press(WidgetTester tester, Finder what) async {
  await tester.ensureVisible(what);
  await tester.pump();
  await pressLikeAFinger(tester, what);
  await tester.pump(fingerFrame);
}

/// Frames go by (the request is on its way, or its answer is landing).
Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

const _code = 'ZZZZZZ';
const _path = '/lobbies/$_code/join/';

Iterable<String> _typed(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .map((f) => f.controller!.text);

State _view(WidgetTester tester) => tester.state(find.byType(JoinView));

/// The refusals 01 words differently, each as the server sends it.
const _refusals = [
  ('join_not_found', 404, BannerCopy.lobbyNotFound),
  ('join_full', 400, BannerCopy.lobbyFull),
  ('join_closed', 400, BannerCopy.lobbyClosed),
  ('join_already_at_table', 409, BannerCopy.alreadyInLobby),
];

/// The answer to the join: a recorded refusal, or the server down.
void _answer(TableSetup setup, String? sample, int status) => setup.http.answer(
  'POST',
  _path,
  sample == null ? 'Server Error' : ContractSamples.map('http/lobby/$sample'),
  status: status,
);

/// Types the code on 01 and presses Join; the join is held until [land].
Future<HeldReplies> _typeAndJoin(WidgetTester tester, TableSetup setup) async {
  await _press(tester, find.text(JoinCopy.joinTable));
  await _frames(tester);
  await tester.enterText(find.byType(TextField).last, _code);
  await tester.pump();
  final held = setup.http.hold(method: 'POST', path: _path);
  await _press(tester, find.text(JoinCopy.join));
  return held;
}

/// The held join is answered, and the answer lands over frames.
Future<void> _land(WidgetTester tester, HeldReplies held) async {
  await _frames(tester);
  expect(held.length, 1, reason: 'one join on its way, drawn busy');
  held.release();
  await _frames(tester, 20);
}

void main() {
  group('a typed code, signed in', () {
    for (final (sample, status, banner) in [
      ..._refusals,
      (null, 503, BannerCopy.notSent),
    ]) {
      testWidgets('a join answered "${sample ?? status}" after a frame says '
          '"$banner"; the code, its focus and 01 itself stay', (tester) async {
        final setup = await TableSetup.pump(tester, signedInAs: 'Ben');
        _answer(setup, sample, status);
        final held = await _typeAndJoin(tester, setup);
        final view = _view(tester);
        await _land(tester, held);

        expect(find.text(banner), findsOneWidget);
        expect(
          find.text(BannerCopy.tryAgain),
          sample == null ? findsOneWidget : findsNothing,
        );
        expect(_typed(tester), contains(_code));
        expect(_view(tester), same(view), reason: 'one 01 throughout');
        final code = tester.widget<EditableText>(
          find.byType(EditableText).last,
        );
        expect(code.focusNode.hasFocus, isTrue, reason: 'the cursor stays');
        await setup.close(tester);
      });
    }

    testWidgets('the banner goes when the player edits the code, not when '
        'the cursor moves into a field', (tester) async {
      final setup = await TableSetup.pump(tester, signedInAs: 'Ben');
      _answer(setup, 'join_not_found', 404);
      await _land(tester, await _typeAndJoin(tester, setup));
      expect(find.text(BannerCopy.lobbyNotFound), findsOneWidget);

      // Into the name field and back: the refusal stays.
      await _press(tester, find.byType(TextField).first);
      await _frames(tester);
      await _press(tester, find.byType(TextField).last);
      await _frames(tester);
      expect(find.text(BannerCopy.lobbyNotFound), findsOneWidget);

      // An edit: it goes.
      await tester.enterText(find.byType(TextField).last, 'ZZZZZ');
      await tester.pump();
      expect(find.text(BannerCopy.lobbyNotFound), findsNothing);
      await setup.close(tester);
    });
  });

  group('a typed code, signed out (the account is made on the way)', () {
    for (final (sample, status, banner) in [
      ..._refusals.take(1),
      (null, 503, BannerCopy.notSent),
    ]) {
      testWidgets('"$banner" shows on the same 01', (tester) async {
        final setup = await TableSetup.pump(tester, realAuth: true);
        setup.http.answer(
          'POST',
          '/auth/guest/',
          ContractSamples.map('http/auth/guest_created'),
          status: 201,
        );
        _answer(setup, sample, status);
        await tester.enterText(find.byType(TextField).first, 'Ben');
        await tester.pump();
        final held = await _typeAndJoin(tester, setup);
        final view = _view(tester);
        await _land(tester, held);

        expect(find.text(banner), findsOneWidget);
        expect(_typed(tester), containsAll(['Ben', _code]));
        expect(_view(tester), same(view), reason: 'one 01 throughout');
        await setup.close(tester);
      });
    }
  });

  group('a scanned code, signed in', () {
    for (final (sample, status, banner) in [
      ..._refusals.take(1),
      (null, 503, BannerCopy.notSent),
    ]) {
      testWidgets('"$banner" shows on 01 with the code in its field', (
        tester,
      ) async {
        final setup = await TableSetup.pump(tester, signedInAs: 'Ben');
        _answer(setup, sample, status);
        await _press(tester, find.bySemanticsLabel(ScanCopy.scan));
        await _frames(tester);
        final held = setup.http.hold(method: 'POST', path: _path);
        setup.scanners.single.see(_code);
        await _land(tester, held);

        expect(find.text(banner), findsOneWidget);
        expect(_typed(tester), contains(_code));
        await setup.close(tester);
      });
    }
  });

  group('a table\'s link, signed in at no table', () {
    for (final (sample, status, banner) in [
      ..._refusals.take(3),
      (null, 503, BannerCopy.notSent),
    ]) {
      testWidgets('"$banner" shows on the same 01', (tester) async {
        final setup = await TableSetup.pump(
          tester,
          signedInAs: 'Ben',
          route: '/join/$_code',
        );
        _answer(setup, sample, status);
        final held = setup.http.hold(method: 'POST', path: _path);
        final view = _view(tester);
        await _press(tester, find.text(JoinCopy.join));
        await _land(tester, held);

        expect(find.text(banner), findsOneWidget);
        expect(_view(tester), same(view), reason: 'one 01 throughout');
        await setup.close(tester);
      });
    }
  });
}
