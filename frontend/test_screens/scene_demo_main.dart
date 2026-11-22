// A standalone web entry that hosts the dusk and the dawn on screens built
// from the real primitives and art, for the browser frame-timing check
// (`tool/scene_web_check.sh`). Not part of the app: nothing imports it.
//
//   d  the deal: table to your card (dusk)
//   n  your card to the night board (a crossfade)
//   w  the night board to the talk (dawn)
//   r  back to the table (a crossfade)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/scene_switcher.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

void main() => runApp(const _Demo());

const _names = ['Ana', 'Ben', 'Cleo', 'Dev', 'Esme'];

class _Demo extends StatefulWidget {
  const _Demo();

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  var _stage = 0;

  SceneKind? _between(int from, int to) => switch ((from, to)) {
    (0, 1) => SceneKind.dusk,
    (2, 3) => SceneKind.dawn,
    _ => null,
  };

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.keyD => 1,
      LogicalKeyboardKey.keyN => 2,
      LogicalKeyboardKey.keyW => 3,
      LogicalKeyboardKey.keyR => 0,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    setState(() => _stage = next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: skinTheme(SkinId.fallback.skin),
    builder: (context, app) =>
        GroundScope(ground: GroundKind.night, child: app!),
    home: Focus(
      autofocus: true,
      onKeyEvent: _key,
      child: SceneSwitcher<int>(
        stage: _stage,
        sceneBetween: _between,
        child: switch (_stage) {
          0 => const _Table(),
          1 => const _Card(),
          2 => const _Board(),
          _ => const _Talk(),
        },
      ),
    ),
  );
}

class _Table extends StatelessWidget {
  const _Table();

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    topArt: context.skin.art.table,
    topArtLayout: TopArtLayout.banner,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.sm,
      children: [
        for (final name in _names)
          PaperCard(child: Text(name, style: context.skin.typography.body)),
      ],
    ),
    actions: [PrimaryButton(label: 'Deal to 5', onPressed: () {})],
  );
}

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    topArt: context.skin.art.nightVillage,
    topArtLayout: TopArtLayout.backdrop,
    fitsHeight: true,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your card', style: context.skin.typography.screenTitle),
        const SizedBox(height: Space.lg),
        const Expanded(
          child: Center(child: FaceDownCard(size: FaceDownSize.hero)),
        ),
      ],
    ),
    actions: [PrimaryButton.quiet(label: 'Ready', onPressed: () {})],
  );
}

class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    fitsHeight: true,
    body: Wrap(
      alignment: WrapAlignment.center,
      spacing: Space.md,
      runSpacing: Space.md,
      children: [
        for (final name in _names)
          FaceDownCard(size: FaceDownSize.board, ownerName: name),
      ],
    ),
    actions: [PrimaryButton.quiet(label: 'Choose a card', onPressed: () {})],
  );
}

class _Talk extends StatelessWidget {
  const _Talk();

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.day,
    topSlot: const TimerBand.sun(
      secondsLeft: 300,
      elapsed: 0.02,
      title: 'The village wakes',
    ),
    fitsHeight: true,
    minBodyHeight: 300,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.md,
      children: [
        for (final name in _names.take(3))
          PaperCard(child: Text(name, style: context.skin.typography.body)),
      ],
    ),
    actions: [PrimaryButton.quiet(label: 'Ready to vote', onPressed: () {})],
  );
}
