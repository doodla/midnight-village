/// The route Vercel's Speed Insights and Web Analytics are told for a web
/// address: the app's route pattern, never what fills it. A table's link is
/// `<origin>/join/<code>`: it is reported as `/join/[code]`, so no code is in
/// what the scripts send, and every page of one kind is counted together.
/// Anything the app does not route is `/[other]` (a typed address could hold
/// anything).
String insightsRoute(String path) {
  final parts = path.split('/').where((s) => s.isNotEmpty).toList();
  return switch (parts) {
    [] => '/',
    ['join', _] => '/join/[code]',
    ['game', _] => '/game/[id]',
    ['debug'] => '/debug',
    _ => '/[other]',
  };
}

/// [url] with its path made [insightsRoute] and its query and fragment
/// dropped (`?perf=1`, anything).
String insightsUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return insightsRoute('');
  return '${uri.origin}${insightsRoute(uri.path)}';
}
