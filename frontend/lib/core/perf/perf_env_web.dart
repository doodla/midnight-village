import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show kIsWasm;
import 'package:web/web.dart' as web;

/// The page's own clock (`performance.now()`, ms since the page opened): the
/// clock a pointer event's time stamp and a frame's timings are on.
double perfNow() => web.window.performance.now();

/// The web address's query (`?perf=1`).
Map<String, String> pageQuery() => Uri.base.queryParameters;

/// What the phone and the browser say about themselves, once. Nothing about
/// the player: no storage, no address, no account.
Map<String, Object?> perfEnvironment() {
  final env = <String, Object?>{};
  void read(String name, Object? Function() what) {
    try {
      env[name] = what();
    } catch (_) {}
  }

  final nav = web.window.navigator;
  read('agent', () => nav.userAgent);
  read('cores', () => nav.hardwareConcurrency);
  read(
    'memory_gb',
    () => (nav as JSObject)
        .getProperty<JSNumber?>('deviceMemory'.toJS)
        ?.toDartDouble,
  );
  read('pixel_ratio', () => web.window.devicePixelRatio);
  read(
    'screen',
    () => '${web.window.screen.width}x${web.window.screen.height}',
  );
  read('window', () => '${web.window.innerWidth}x${web.window.innerHeight}');
  read('renderer', () => kIsWasm ? 'skwasm' : 'canvaskit');
  read('gpu', _gpu);
  read('main_bundle_ms', () => _loaded(RegExp(r'main\.dart\.(js|wasm)$')));
  read('engine_ms', () => _loaded(RegExp(r'(canvaskit|skwasm)\.wasm$')));
  read('page_ready_ms', () {
    final nav = web.window.performance.getEntriesByType('navigation').toDart;
    if (nav.isEmpty) return null;
    return (nav.first as web.PerformanceNavigationTiming)
        .domContentLoadedEventEnd
        .round();
  });
  return env;
}

/// Lets the browser keep a record of every request of a long game (it keeps
/// 250 by default, then drops new ones).
void perfPrepare() {
  try {
    web.window.performance.setResourceTimingBufferSize(5000);
  } catch (_) {}
}

/// The browser's own record of the request to [url] that started after
/// [after]: when it went out and when the whole answer was in.
({double start, double end})? perfResourceTiming(String url, double after) {
  try {
    for (final entry
        in web.window.performance.getEntriesByName(url, 'resource').toDart) {
      final timing = entry as web.PerformanceResourceTiming;
      if (timing.startTime >= after && timing.responseEnd > 0) {
        return (start: timing.startTime, end: timing.responseEnd);
      }
    }
  } catch (_) {}
  return null;
}

/// The graphics chip's name, as WebGL says it (Chrome gives it plainly).
String? _gpu() {
  final canvas = web.HTMLCanvasElement();
  final gl = canvas.getContext('webgl') as web.WebGLRenderingContext?;
  if (gl == null) return null;
  final info = gl.getExtension('WEBGL_debug_renderer_info');
  // UNMASKED_RENDERER_WEBGL
  final name = info != null
      ? gl.getParameter(0x9246)
      : gl.getParameter(web.WebGLRenderingContext.RENDERER);
  gl.getExtension('WEBGL_lose_context')?.callMethod<JSAny?>('loseContext'.toJS);
  return (name as JSString?)?.toDart;
}

/// When the file matching [name] had arrived (ms since the page opened),
/// from the browser's own record of what it loaded.
int? _loaded(RegExp name) {
  for (final entry
      in web.window.performance.getEntriesByType('resource').toDart) {
    final timing = entry as web.PerformanceResourceTiming;
    if (name.hasMatch(Uri.parse(timing.name).path)) {
      return timing.responseEnd.round();
    }
  }
  return null;
}
