import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

void main() {
  test("the app's theme is the one look's", () {
    final app = ProviderContainer();
    addTearDown(app.dispose);
    expect(
      app.read(appThemeProvider).extension<Skin>(),
      same(SkinId.fallback.skin),
    );
  });

  test('a skin is swapped whole, never blended', () {
    final a = SkinId.shadowPaper.skin;
    final b = a.copyWith(dimmed: a.dimmed / 2);
    expect(a.lerp(b, 0.5), same(a));
    expect(a.lerp(b, 0.99), same(a));
    expect(a.lerp(b, 1), same(b));
  });
}
