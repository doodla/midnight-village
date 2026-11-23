import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/features/game/domain/game_outcome.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_view.dart';
import 'text_scale.dart';

/// The end board on the results [results], for the player in seat [viewer]
/// (0 is the first), as a host or a guest, at text size [scale]. A guest's
/// host is the first seat.
Future<void> pumpEndBoardOn(
  WidgetTester tester,
  Map<String, dynamic> results, {
  int viewer = 0,
  bool host = true,
  double scale = 1,
  ScrollController? controller,
}) async {
  final outcome = GameOutcome.fromJson(results);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: skinTheme(SkinId.fallback.skin),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: ambientTextScaler(context, scale)),
        child: app!,
      ),
      home: EndBoardView(
        outcome: outcome,
        viewerId: outcome.seats[viewer].id,
        isHost: host,
        hostName: host ? null : outcome.seats.first.name,
        onWhatHappened: () {},
        onEditDeck: () {},
        onPlayAgain: () {},
        onLeave: () {},
        scrollController: controller,
      ),
    ),
  );
  await tester.pump();
}
