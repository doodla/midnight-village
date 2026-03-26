import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_tokens.dart';
import 'firelit_gothic_theme.dart';

part 'app_tokens_provider.g.dart';

@Riverpod(keepAlive: true)
class ActiveTheme extends _$ActiveTheme {
  @override
  AppTokens build() => const FirelitGothicTheme();

  void switchTheme(AppTokens theme) {
    state = theme;
  }
}
