import 'skin.dart';
import 'skins/night_print.dart' as night_print;
import 'skins/shadow_paper.dart' as shadow_paper;

/// The skins a player can choose. This is the only place, with the skin
/// switch, that names one: layout code reads the active [Skin] and never asks
/// which it is (test/design_system/skin/skin_identity_test.dart checks).
enum SkinId {
  shadowPaper('Shadow paper'),
  nightPrint('Night print');

  const SkinId(this.label);

  final String label;

  Skin get skin => switch (this) {
    SkinId.shadowPaper => shadow_paper.shadowPaper,
    SkinId.nightPrint => night_print.nightPrint,
  };
}
