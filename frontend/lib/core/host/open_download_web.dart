import 'package:web/web.dart' as web;

import 'app_download.dart' show appDownloadPath;

/// Opens the short address: the host sends the browser on to the file, which
/// the browser downloads (the page stays where it is).
void openAppDownload() => web.window.location.assign(appDownloadPath);
