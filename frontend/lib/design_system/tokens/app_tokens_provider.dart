import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_tokens.dart';
import 'midnight_village_theme.dart';

part 'app_tokens_provider.g.dart';

@Riverpod(keepAlive: true)
class ActiveTheme extends _$ActiveTheme {
  @override
  AppTokens build() => const MidnightVillageTheme();

  void switchTheme(AppTokens theme) {
    state = theme;
  }
}
