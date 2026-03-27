import 'package:go_router/go_router.dart';

import '../config/env.dart';
import 'routes.dart';

/// Application router configuration.
final appRouter = GoRouter(routes: $appRoutes, debugLogDiagnostics: Env.isDev);
