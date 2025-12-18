import 'package:go_router/go_router.dart';

import 'routes.dart';

/// Application router configuration.
final appRouter = GoRouter(
  routes: $appRoutes,
  debugLogDiagnostics: true,
);
