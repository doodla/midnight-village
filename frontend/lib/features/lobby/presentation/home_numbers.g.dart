// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_numbers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 01's "{n} at tables" (`GET /stats/online/`, no login), retried until it
/// answers.

@ProviderFor(onlineStats)
const onlineStatsProvider = OnlineStatsProvider._();

/// 01's "{n} at tables" (`GET /stats/online/`, no login), retried until it
/// answers.

final class OnlineStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<OnlineStats>,
          OnlineStats,
          FutureOr<OnlineStats>
        >
    with $FutureModifier<OnlineStats>, $FutureProvider<OnlineStats> {
  /// 01's "{n} at tables" (`GET /stats/online/`, no login), retried until it
  /// answers.
  const OnlineStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: retryForever,
        name: r'onlineStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onlineStatsHash();

  @$internal
  @override
  $FutureProviderElement<OnlineStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OnlineStats> create(Ref ref) {
    return onlineStats(ref);
  }
}

String _$onlineStatsHash() => r'605d2ef9c1938e98a3b256234ec6981446cc6347';

/// This player's last finished game, for 01's "You won last game" / "You
/// lost last game": null when signed out or with no finished game.

@ProviderFor(lastGame)
const lastGameProvider = LastGameProvider._();

/// This player's last finished game, for 01's "You won last game" / "You
/// lost last game": null when signed out or with no finished game.

final class LastGameProvider
    extends
        $FunctionalProvider<
          AsyncValue<RecentGame?>,
          RecentGame?,
          FutureOr<RecentGame?>
        >
    with $FutureModifier<RecentGame?>, $FutureProvider<RecentGame?> {
  /// This player's last finished game, for 01's "You won last game" / "You
  /// lost last game": null when signed out or with no finished game.
  const LastGameProvider._()
    : super(
        from: null,
        argument: null,
        retry: retryForever,
        name: r'lastGameProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastGameHash();

  @$internal
  @override
  $FutureProviderElement<RecentGame?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RecentGame?> create(Ref ref) {
    return lastGame(ref);
  }
}

String _$lastGameHash() => r'0c2a882f13815d96015b753ec579fb9bb63cb5c8';

/// Where this app is served from, for the link a QR code and Share carry:
/// the page's own address on the web; `--dart-define=PUBLIC_ORIGIN=...`
/// elsewhere; null when neither (then the table shows its code alone).

@ProviderFor(appOrigin)
const appOriginProvider = AppOriginProvider._();

/// Where this app is served from, for the link a QR code and Share carry:
/// the page's own address on the web; `--dart-define=PUBLIC_ORIGIN=...`
/// elsewhere; null when neither (then the table shows its code alone).

final class AppOriginProvider extends $FunctionalProvider<Uri?, Uri?, Uri?>
    with $Provider<Uri?> {
  /// Where this app is served from, for the link a QR code and Share carry:
  /// the page's own address on the web; `--dart-define=PUBLIC_ORIGIN=...`
  /// elsewhere; null when neither (then the table shows its code alone).
  const AppOriginProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appOriginProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appOriginHash();

  @$internal
  @override
  $ProviderElement<Uri?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Uri? create(Ref ref) {
    return appOrigin(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Uri? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Uri?>(value),
    );
  }
}

String _$appOriginHash() => r'f5b8b468c93e34b6365eb52740798c241f56127e';

@ProviderFor(shareLink)
const shareLinkProvider = ShareLinkProvider._();

final class ShareLinkProvider
    extends $FunctionalProvider<ShareLink, ShareLink, ShareLink>
    with $Provider<ShareLink> {
  const ShareLinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareLinkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareLinkHash();

  @$internal
  @override
  $ProviderElement<ShareLink> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShareLink create(Ref ref) {
    return shareLink(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShareLink value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShareLink>(value),
    );
  }
}

String _$shareLinkHash() => r'f3ace4a4048ebe9d82ec56989f305242fb105849';
