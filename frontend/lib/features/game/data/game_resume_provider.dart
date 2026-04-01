import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/presentation/auth_notifier.dart';
import 'game_resume_service.dart';

part 'game_resume_provider.g.dart';

/// Provides the [GameResumeService] for checking active games on startup.
///
/// Kept alive so the cached result persists across navigations.
@Riverpod(keepAlive: true)
GameResumeService gameResumeService(Ref ref) {
  return GameResumeService(apiClient: ref.watch(authenticatedClientProvider));
}
