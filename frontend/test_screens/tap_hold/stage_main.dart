// A stage for the browser tap/hold check (tool/tap_hold/drive.cjs): one part
// that answers a tap and a hold, mounted as its screen mounts it, saying on the
// console what each touch did. Not part of the app: nothing imports it.
// A first step: only 03's role grid so far.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

void say(String what) => debugPrint('tap-hold: $what');

final _target = GlobalKey();

void main() {
  if (Uri.base.queryParameters['sem'] == '1') {
    WidgetsFlutterBinding.ensureInitialized();
    SemanticsBinding.instance.ensureSemantics();
  }
  runApp(const _Stage());
}

class _Stage extends StatefulWidget {
  const _Stage();
  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  final _deck = <Object, int>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ready());
  }

  void _ready() {
    final box = _target.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ready());
      WidgetsBinding.instance.scheduleFrame();
      return;
    }
    final c = box.localToGlobal(box.size.center(Offset.zero));
    say('ready ${c.dx} ${c.dy}');
  }

  void _lift() {
    WidgetsBinding.instance.addPostFrameCallback((_) => say('settled'));
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: skinTheme(SkinId.fallback.skin),
    builder: (context, app) =>
        GroundScope(ground: GroundKind.night, child: app!),
    home: Listener(
      onPointerUp: (_) => _lift(),
      onPointerCancel: (_) => _lift(),
      child: ScreenFrame(
        ground: GroundKind.night,
        body: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.mdPlus,
          crossAxisSpacing: Space.md,
          childAspectRatio: RoleCard.gridCellAspect,
          children: [
            for (final (i, role) in deckOrder.indexed)
              RoleCard(
                key: i == 4 ? _target : null,
                role: role,
                count: _deck[role] ?? 1,
                lit: true,
                onTap: () {
                  say('tap');
                  setState(() => _deck[role] = (_deck[role] ?? 1) + 1);
                },
                onLongPress: () => say('hold'),
                onRemove: () {},
              ),
          ],
        ),
      ),
    ),
  );
}
