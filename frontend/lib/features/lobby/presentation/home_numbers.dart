import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/healing/healing.dart';
import '../../../core/logging/app_logger.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/home_service.dart';
import '../domain/where_am_i.dart';
import 'lobby_notifier.dart';

part 'home_numbers.g.dart';

/// 01's "{n} at tables" (`GET /stats/online/`, no login), retried until it
/// answers.
@Riverpod(retry: retryForever)
Future<OnlineStats> onlineStats(Ref ref) =>
    ref.watch(homeServiceProvider).fetchOnline();

/// This player's last finished game, for 01's "You won last game" / "You
/// lost last game": null when signed out or with no finished game.
@Riverpod(retry: retryForever)
Future<RecentGame?> lastGame(Ref ref) async {
  if (ref.watch(authProvider) is! AuthAuthenticated) return null;
  final games = await ref.watch(lobbyServiceProvider).fetchRecentGames();
  return games.firstOrNull;
}

/// Where this app is served from, for the link a QR code and Share carry:
/// the page's own address on the web; `--dart-define=PUBLIC_ORIGIN=...`
/// elsewhere; null when neither (then the table shows its code alone).
@Riverpod(keepAlive: true)
Uri? appOrigin(Ref ref) {
  const configured = String.fromEnvironment('PUBLIC_ORIGIN');
  if (configured.isNotEmpty) return Uri.parse(configured);
  // The page's own origin, whatever address it was opened at (`/join/<code>`
  // included).
  if (kIsWeb) return Uri.parse(Uri.base.origin);
  return null;
}

/// Hands a link to the system's share sheet (02's Share). Only where there
/// is none, or it fails, is the link copied instead; true then, so the
/// screen says "Copied". (No mail fallback on the web: a mail window is not
/// a share sheet.)
typedef ShareLink = Future<bool> Function(Uri link);

@Riverpod(keepAlive: true)
ShareLink shareLink(Ref ref) => (link) async {
  final text = link.toString();
  try {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, mailToFallbackEnabled: false),
    );
    if (result.status != ShareResultStatus.unavailable) return false;
  } catch (e) {
    logger.d('No share sheet ($e)');
  }
  await Clipboard.setData(ClipboardData(text: text));
  return true;
};

/// The link that opens 01 ready to join table [code]: `<origin>/join/<code>`,
/// a path the web host serves the app for (`vercel.json`) and Android opens
/// in the app (App Links, `docs/dev/deploy-vercel.md`). Only [origin]'s
/// scheme, host, port and base path are kept.
Uri joinLink(Uri origin, String code) {
  final base = origin.path.replaceFirst(RegExp(r'/+$'), '');
  return Uri(
    scheme: origin.scheme,
    host: origin.host,
    port: origin.hasPort ? origin.port : null,
    path: '$base/join/$code',
  );
}
