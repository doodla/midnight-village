import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/night/night_story_view.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/vote_slip.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import 'end_of_game.dart';
import 'failure_report.dart';
import 'live_table.dart';
import 'time_budget.dart';
import 'ui_harness.dart';

/// Runs [script] on a fresh app at a phone's size, recording a failure with
/// its filmstrip folder, and tears the app down whatever happens.
Future<void> runPhone(
  WidgetTester tester,
  String name,
  Future<void> Function(Phone r) script,
) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final ui = UiHarness(tester);
  final phone = Phone(tester, ui, name);
  try {
    await ui.pumpApp();
    await script(phone);
  } catch (e) {
    FailureReport.record(
      scenario: name,
      checkpoint: 'ui-game',
      message: e.toString(),
      pngPath: 'integration_test/screenshots/$name/',
    );
    rethrow;
  } finally {
    await phone.close();
    await ui.tearDownHarness();
  }
}

/// One player's phone ([holder], Alice unless the table says otherwise) at
/// a forced table, and the API hand for the others.
class Phone {
  Phone(this.tester, this.ui, this.name);

  final WidgetTester tester;
  final UiHarness ui;
  final String name;
  late LiveTable table;
  var _frame = 0;

  /// Whose phone this is.
  String holder = 'Alice';

  /// Opens the table (made as the `/debug` toolbar makes a v2 table), forced
  /// to [roles] (in seat order, the first the host) and [center], and
  /// [phone]'s phone on its game.
  Future<LiveTable> open({
    required Map<String, int> roleCounts,
    required Map<String, String> roles,
    String phone = 'Alice',
    required List<String> center,
  }) async {
    table = (await tester.runAsync(
      () => LiveTable.open(
        playerNames: roles.keys.toList(),
        roleCounts: roleCounts,
        playerRolesByName: roles,
        centerCards: center,
        // Long backstops: every stage here ends because everyone acted, or
        // by the fire-timer hook, never by a clock.
        timerSettings: {
          'card_look_seconds': 120,
          'night_wave_seconds': 600,
          'night_min_window_seconds': 0,
          'night_doppelganger_window_seconds': 600,
          'discussion_seconds': 600,
          'voting_seconds': 600,
        },
      ),
    ))!;
    holder = phone;
    final alice = table.player(holder);
    await ui.switchTo(
      userId: alice.userId,
      displayName: alice.displayName,
      accessToken: alice.accessToken,
      refreshToken: alice.refreshToken,
      gameId: table.gameId,
    );
    await ui.openShell(table.gameId);
    return table;
  }

  Future<void> close() async {
    try {
      await tester.runAsync(table.closeAll);
    } catch (_) {
      // Not opened.
    }
  }

  /// Real network, in the real zone.
  Future<T> api<T>(Future<T> Function() call) async =>
      (await tester.runAsync(() => call().timeout(eventTimeout))) as T;

  /// Every player but Alice, one after the other.
  Future<void> everyoneElse(Future<void> Function(DebugPlayer p) act) async {
    for (final p in table.table.players.where((p) => p.displayName != holder)) {
      await act(p);
    }
  }

  /// A stage-scoped request as [p], naming the stage `/me/` has now (a
  /// choose answers the prompt as `/me/` shows it).
  Future<void> staged(
    DebugPlayer p,
    String tail,
    Map<String, dynamic> data,
  ) async {
    final me = await table.me(p);
    final prompt = me['action_prompt'] as Map<String, dynamic>?;
    await table.client.post(
      '/onuw/games/${table.gameId}/$tail/',
      token: p.accessToken,
      data: {
        ...data,
        'stage': me['stage'] as String,
        if (data['action_type'] == 'choose')
          'chosen': prompt == null ? 0 : prompt['chosen'] as int,
      },
    );
  }

  /// [p]'s choose, as its phone sends it: only while its prompt still has
  /// a turn (`chooses_left`). A phone with nothing to choose sends nothing.
  Future<void> choose(DebugPlayer p, List<Map<String, Object>> picks) async {
    final prompt = (await table.me(p))['action_prompt'] as Map?;
    if (prompt == null || (prompt['chooses_left'] as int) < 1) return;
    await staged(p, 'action', {'action_type': 'choose', 'picks': picks});
  }

  /// What is true on the server (the debug-state oracle). Called inside
  /// [api] (the real zone) only.
  Future<Map<String, dynamic>> oracle() => table.oracleJson();

  Future<bool> _aliceReady() async {
    final players = ((await oracle())['players'] as List)
        .cast<Map<String, dynamic>>();
    return players.firstWhere(
          (p) => p['user_id'] == table.player(holder).userId,
        )['ready']
        as bool;
  }

  /// From the talk to the count, [holder] on the phone: "Ready to vote" on,
  /// off and on again (each reaching the server, read from the oracle);
  /// the rest ready through the API; the vote opens; the phone picks
  /// [accuse], then locks in; the rest lock in their vote of [votes] (name
  /// to name), else a vote for the phone's holder; the count follows.
  Future<void> talkAndVote(
    LiveTable t, {
    required String accuse,
    Map<String, String> votes = const {},
  }) async {
    final alice = t.player(holder);
    // My night is up by itself as the talk opens where the night told this
    // phone something: a touch puts it away (nothing up, nothing to do).
    await putAwayMyNight();
    expect(button.label, TalkCopy.readyToVote);
    expect(button.phase, ButtonPhase.ready);
    for (final ready in [true, false, true]) {
      await tapButton(
        until: () =>
            button.label ==
            (ready ? CommonCopy.readyDone : TalkCopy.readyToVote),
      );
      await api(
        () => pollUntil(
          () async => await _aliceReady() == ready,
          reason: 'Ready to vote $ready on the server',
          timeout: eventTimeout,
        ),
      );
    }
    await shoot('talk-ready');

    await api(() => everyoneElse((p) => staged(p, 'ready', {'ready': true})));
    // 09 is built only from the vote's own `/me/`: its rows are there the
    // moment it shows.
    await ui.pumpUntil(shows<VoteScreen>, reason: 'the vote', rounds: 200);
    expect(text(accuse), isTrue, reason: 'the rows, at once');
    await ui.settle();
    expect(button.label, VoteCopy.pickName);
    // Her own slip is on the board, in her seat, and never a choice.
    final own = find.widgetWithText(VoteSlip, alice.displayName);
    expect(own, findsOneWidget, reason: 'herself, shown');
    expect(tester.widget<VoteSlip>(own).you, isTrue, reason: 'not a pick');
    await shoot('vote');

    final target = t.player(accuse);
    await ui.tapAndSubmit(
      find.text(accuse),
      until: () => button.label == 'Lock in $accuse',
    );
    await api(
      () => pollUntil(
        () async =>
            (await oracle())['votes']['${alice.userId}'] == target.userId,
        reason: "Alice's pick on the server",
        timeout: eventTimeout,
      ),
    );
    expect((await api(oracle))['vote_locked']['${alice.userId}'], isFalse);
    await shoot('vote-picked');

    await tapButton(until: () => button.label == VoteCopy.locked);
    await api(
      () => pollUntil(
        () async => (await oracle())['vote_locked']['${alice.userId}'] == true,
        reason: "Alice's lock on the server",
        timeout: eventTimeout,
      ),
    );
    expect((await api(() => t.me(alice)))['my_vote'], {
      'target_player_id': target.userId,
      'locked': true,
    });
    await shoot('vote-locked');

    await api(
      () => everyoneElse(
        (p) => staged(p, 'vote', {
          'target_player_id': switch (votes[p.displayName]) {
            final named? => t.player(named).userId,
            null => alice.userId,
          },
          'lock': true,
        }),
      ),
    );
    // The count and the results, as the server says they went.
    await endAsTheOracleSays(
      tester: tester,
      ui: ui,
      table: t,
      name: holder,
      shoot: shoot,
    );
  }

  // ---------------------------------------------------------------------------
  // The screen
  // ---------------------------------------------------------------------------

  bool shows<T extends Widget>() => find.byType(T).evaluate().isNotEmpty;
  bool text(String t) => find.text(t).evaluate().isNotEmpty;

  NightBoard get board => tester.widget<NightBoard>(find.byType(NightBoard));
  PrimaryButton get button =>
      tester.widget<PrimaryButton>(find.byType(PrimaryButton).last);

  /// "You" on the board.
  Finder get you => find.ancestor(
    of: find.text(NightCopy.you),
    matching: find.byType(FaceDownCard),
  );

  /// A card on the board by its caption (a pick: no network).
  Future<void> tapCard(String caption) async {
    await tester.tap(find.text(caption).last);
    await tester.pump();
    await ui.settle();
  }

  /// Holds [target] for a reveal that counts, runs [whileHeld], lets go.
  Future<void> holdThen(
    Finder target,
    Future<void> Function() whileHeld,
  ) async {
    final gesture = await tester.startGesture(tester.getCenter(target.first));
    await tester.pump(HoldToReveal.holdDelay);
    await tester.pump(HoldToReveal.revealedAfter);
    await whileHeld();
    await gesture.up();
    await tester.pump();
  }

  /// My night's story is on the board (held, or up by itself as the talk
  /// opens).
  bool get myNightUp => find.byType(NightStoryView).evaluate().isNotEmpty;

  /// What My night says now: the sentence under the picture as it is drawn,
  /// then the story's own reading (every card, by who held it).
  List<String> readMyNight() => [
    for (final t in tester.widgetList<RichText>(find.byType(RichText)))
      t.text.toPlainText(),
    tester.widget<NightStoryView>(find.byType(NightStoryView)).story.spoken,
  ];

  /// The talk opens with My night up by itself where the night told this
  /// phone something: [whileOpen] reads it, then the first touch anywhere
  /// puts it away (and is only that). Nothing up: nothing to do.
  Future<void> putAwayMyNight([Future<void> Function()? whileOpen]) async {
    if (!myNightUp) return;
    await ui.settle();
    await whileOpen?.call();
    await tester.tapAt(tester.getCenter(find.byType(TalkView)));
    await tester.pump();
    await ui.settle();
    expect(myNightUp, isFalse, reason: 'My night is away');
  }

  /// A hold on My night's note shows the night on the board while it is
  /// held: [whileOpen] reads it; letting go puts it away.
  Future<void> openMyNight(Future<void> Function() whileOpen) async {
    await holdThen(find.byType(HoldToReveal), () async {
      await tester.pump();
      expect(myNightUp, isTrue, reason: 'My night is up while held');
      await whileOpen();
    });
    await ui.settle();
    expect(myNightUp, isFalse, reason: 'My night is away once let go');
  }

  /// The screen's primary button (it sends a request: a real-zone tap).
  Future<void> tapButton({required bool Function() until}) =>
      ui.tapAndSubmit(find.byType(PrimaryButton).last, until: until);

  /// The next filmstrip frame.
  Future<void> shoot(String state) =>
      ui.captureFrame(name, '${(++_frame).toString().padLeft(2, '0')}-$state');
}
