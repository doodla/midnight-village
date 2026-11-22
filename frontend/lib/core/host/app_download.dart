import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'open_download_stub.dart'
    if (dart.library.js_interop) 'open_download_web.dart';

part 'app_download.g.dart';

/// Where the Android app is got: the short address `/app` on the web app's
/// own host (`frontend/vercel.json` sends it on to the one rolling release,
/// `docs/dev/deploy-vercel.md`, "Android app download"). No route of the
/// router is called `/app`: the host answers it before the app is ever opened.
const appDownloadPath = '/app';

/// Whether the app is offered for download here: only a page running in an
/// Android browser (the web build; Flutter reads the platform from the
/// browser). Never inside the Android app (not web), on iOS or on a desktop.
/// The one place that decides it; a test brings its own [AppDownload].
@visibleForTesting
bool offersAppDownload({required bool web, required TargetPlatform platform}) =>
    web && platform == TargetPlatform.android;

/// The download, offered by 01 as a quiet "Get the app": [open] hands the
/// browser the file. A provider that is null offers nothing.
class AppDownload {
  const AppDownload(this.open);

  final VoidCallback open;
}

@Riverpod(keepAlive: true)
AppDownload? appDownload(Ref ref) =>
    offersAppDownload(web: kIsWeb, platform: defaultTargetPlatform)
    ? const AppDownload(openAppDownload)
    : null;
