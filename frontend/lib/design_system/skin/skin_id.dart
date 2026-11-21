import 'skin.dart';
import 'skins/shadow_paper.dart' as shadow_paper;

/// The registry of skins, the default first. There is one look today. A
/// future look is a separate design with its own layouts, components and
/// original art, not a recolouring; it would be one file in `skins/` and one
/// entry here, and the switch, the tests and `just screens` read this list.
///
/// This is the only place, with the skin switch, that names a skin: layout
/// code reads the active [Skin] and never asks which it is
/// (test/design_system/skin/skin_identity_test.dart checks).
enum SkinId {
  shadowPaper('Shadow paper', _shadowPaper);

  const SkinId(this.label, this._build);

  final String label;
  final Skin Function() _build;

  Skin get skin => _build();

  /// The skin a new device starts in.
  static SkinId get fallback => values.first;

  /// The skin saved as [name], or null when there is none by that name (a
  /// skin since removed).
  static SkinId? byName(String? name) => values.asNameMap()[name];
}

Skin _shadowPaper() => shadow_paper.shadowPaper;
