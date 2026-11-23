/// Not the web: there is no page to reload and no `/commit.txt` to read.
Future<String?> fetchLiveBuild() async => null;

Future<bool> renewServiceWorker() async => true;

Future<void> reloadPage() async {}
