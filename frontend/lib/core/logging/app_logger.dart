import 'package:logger/logger.dart';

import '../config/env.dart';

/// Global application logger.
///
/// Log levels filtered by environment:
/// - Dev: debug and above
/// - Prod: warning and above
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: Env.isDev,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: Env.isDev ? Level.debug : Level.warning,
);
