import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../update/build_id.dart';
import 'insights_route.dart';

/// Vercel's own scripts, served by every Vercel deployment at these paths:
/// Speed Insights (the browser's Core Web Vitals, INP among them: tap to the
/// next frame) and Web Analytics (page views; it counts once the owner
/// switches it on in the dashboard, and is quiet until then).
const speedInsightsScript = '/_vercel/speed-insights/script.js';
const webAnalyticsScript = '/_vercel/insights/script.js';

web.HTMLScriptElement? _speed;

/// Loads both scripts, once, after the app's start (`main.dart`, beside
/// `webStartDone`): nothing of them is on the way to the first picture. The
/// web vitals they read are kept by the browser from the page's start, so
/// loading late loses none. Only on a build with a commit: a local run or a
/// test loads nothing.
///
/// What they report is the route, never the address: each script is told
/// the route pattern (`data-route`, `data-path`: Speed Insights then reports
/// that path and drops the query) and both rewrite the address in
/// `beforeSend` (`insightsUrl`), so a table's code (`/join/<code>`) never
/// leaves the phone. The route follows the app's navigation
/// (`currententrychange`, and `popstate` where there is no Navigation API).
void startVercelInsights() {
  if (!BuildId.isReal(BuildId.mine) || _speed != null) return;
  try {
    final window = web.window as JSObject;
    final rewrite = ((JSObject data) {
      final url = data.getProperty<JSString?>('url'.toJS)?.toDart;
      if (url != null) data.setProperty('url'.toJS, insightsUrl(url).toJS);
      return data;
    }).toJS;
    // Each script reads its queue when it loads (the snippet Vercel's docs
    // give for plain HTML, with the redaction first in it).
    window.setProperty(
      'siq'.toJS,
      [
        ['beforeSend'.toJS, rewrite].toJS,
      ].toJS,
    );
    window.setProperty(
      'vaq'.toJS,
      [
        ['beforeSend'.toJS, rewrite].toJS,
      ].toJS,
    );
    _speed = _script(speedInsightsScript);
    _route();
    void follow(web.Event _) => _route();
    final navigation = window.getProperty<JSObject?>('navigation'.toJS);
    navigation?.callMethod<JSAny?>(
      'addEventListener'.toJS,
      'currententrychange'.toJS,
      follow.toJS,
    );
    web.window.addEventListener('popstate', follow.toJS);
    web.document.body?.append(_speed!);
    web.document.body?.append(_script(webAnalyticsScript));
  } catch (_) {}
}

web.HTMLScriptElement _script(String src) => web.HTMLScriptElement()
  ..src = src
  ..defer = true;

/// Tells Speed Insights the route shown now.
void _route() {
  final route = insightsRoute(web.window.location.pathname);
  _speed
    ?..setAttribute('data-route', route)
    ..setAttribute('data-path', route);
}
