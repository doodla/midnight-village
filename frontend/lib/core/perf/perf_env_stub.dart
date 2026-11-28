final _clock = Stopwatch()..start();

/// Off the web: a clock from the app's start (the recorder is web only; tests
/// bring their own clock).
double perfNow() => _clock.elapsedMicroseconds / 1000;

/// No web address off the web.
Map<String, String> pageQuery() => const {};

Map<String, Object?> perfEnvironment({bool gpu = true}) => const {};

void perfPrepare() {}

({double start, double end})? perfResourceTiming(String url, double after) =>
    null;

void perfClearResourceTimings() {}
