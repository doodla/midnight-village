import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'back_rule.dart';
import 'leave_web_stub.dart' if (dart.library.js_interop) 'leave_web.dart';

export 'back_rule.dart';

/// The app's one back policy: every Back, the phone's back button, its
/// back gesture (predictive back on Android) and the browser's Back, comes
/// here, on the one page the app has (`HomeGate`).
///
/// 1. A sheet or a dialog open on top is a route of its own: Back closes it
///    before anything reaches this policy (the navigator pops it).
/// 2. Else the last [BackHandler] that is open answers it: something open
///    on the screen (My night on 08, the code field on 01), or the screen
///    itself (02 asks to leave, 03 returns to 02).
/// 3. Else [rule]: only [BackRule.leavesApp] lets Back leave the app; every
///    other rule keeps the player where they are.
///
/// A sheet or dialog never outlives the screen it was opened on: when
/// [place] changes (another screen), every route above the page closes.
///
/// On Android, the system is told whether the app wants Back, so the back
/// gesture previews leaving only where Back leaves. On the web, the browser's
/// history holds one entry for the app over the page it came from
/// ([oneHistoryEntry]): the browser's Back arrives here as the phone's does,
/// and where Back leaves, the app steps back past its entry to the page
/// before ([leaveWebPage]; with none, a fresh tab, it stays and Back keeps
/// working).
class BackPolicy extends StatefulWidget {
  const BackPolicy({
    super.key,
    required this.rule,
    this.place,
    required this.child,
  });

  /// What Back does here when nothing is open.
  final BackRule rule;

  /// Which screen this is (any value that changes with the screen).
  final Object? place;
  final Widget child;

  /// The app runs in a browser (tests of the web's way pretend to).
  @visibleForTesting
  static bool web = kIsWeb;

  /// Leaves the app on the web (tests count it instead).
  @visibleForTesting
  static void Function() leaveWeb = leaveWebPage;

  @override
  State<BackPolicy> createState() => _BackPolicyState();
}

class _BackPolicyState extends State<BackPolicy> implements PopEntry<Object?> {
  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(false);

  ModalRoute<Object?>? _route;

  /// What answers Back, in the order each opened: the last answers first.
  final _handlers = <_BackHandlerState>[];

  _BackHandlerState? get _top {
    for (final handler in _handlers.reversed) {
      if (handler._answers) return handler;
    }
    return null;
  }

  /// Back may leave the app: the rule says so and nothing open answers it.
  /// (A change reaches the route and Android without a rebuild.) On the web
  /// the page never pops: [onPopInvokedWithResult] leaves by the browser's
  /// history.
  bool get _leaves => widget.rule == BackRule.leavesApp && _top == null;

  void _changed() => canPopNotifier.value = _leaves && !BackPolicy.web;

  void _add(_BackHandlerState handler) {
    _handlers
      ..remove(handler)
      ..add(handler);
    _changed();
  }

  void _remove(_BackHandlerState handler) {
    _handlers.remove(handler);
    _changed();
  }

  @override
  void onPopInvoked(bool didPop) {}

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) return;
    if (_top case final top?) {
      top.widget.onBack();
    } else if (_leaves && BackPolicy.web) {
      BackPolicy.leaveWeb();
    }
  }

  @override
  void initState() {
    super.initState();
    _changed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.unregisterPopEntry(this);
      _route = route;
      _route?.registerPopEntry(this);
    }
  }

  @override
  void didUpdateWidget(BackPolicy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule != widget.rule) _changed();
    if (oldWidget.place != widget.place) _closeAbove();
  }

  /// Closes every sheet and dialog over this page (after this frame: a
  /// navigator does not change while it builds). Their callers get no
  /// answer, so nothing they asked for is done on the screen that went.
  void _closeAbove() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final route = _route;
    if (!mounted || route == null || !route.isActive || route.isCurrent) {
      return;
    }
    route.navigator?.popUntil((r) => r == route || r.isFirst);
  });

  @override
  void dispose() {
    _route?.unregisterPopEntry(this);
    canPopNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _BackPolicyScope(state: this, child: widget.child);
}

class _BackPolicyScope extends InheritedWidget {
  const _BackPolicyScope({required this.state, required super.child});

  final _BackPolicyState state;

  @override
  bool updateShouldNotify(_BackPolicyScope oldWidget) =>
      state != oldWidget.state;
}

/// Something open that Back closes first, or a screen that answers Back
/// itself (by its [BackRule]): while [open], Back calls [onBack] instead of
/// doing what the screen's rule says. The last one opened answers first.
/// Outside a [BackPolicy] (a gallery picture, a test of one view) it does
/// nothing.
class BackHandler extends StatefulWidget {
  const BackHandler({
    super.key,
    this.open = true,
    required this.onBack,
    required this.child,
  });

  final bool open;
  final VoidCallback onBack;
  final Widget child;

  @override
  State<BackHandler> createState() => _BackHandlerState();
}

class _BackHandlerState extends State<BackHandler> {
  _BackPolicyState? _policy;
  var _leaving = false;

  /// Open, and on the screen being shown (a screen on its way out, under a
  /// change of screen, answers nothing).
  bool get _answers => widget.open && !_leaving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _leaving = BackMute.of(context);
    final policy = context
        .getInheritedWidgetOfExactType<_BackPolicyScope>()
        ?.state;
    if (policy != _policy) {
      _policy?._remove(this);
      _policy = policy;
      if (widget.open) policy?._add(this);
    } else {
      policy?._changed();
    }
  }

  @override
  void didUpdateWidget(BackHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open == widget.open) return;
    // Opened again: it is the last one opened.
    if (widget.open) {
      _policy?._add(this);
    } else {
      _policy?._remove(this);
    }
  }

  @override
  void dispose() {
    _policy?._remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A screen on its way out ([muted]): no [BackHandler] under it answers
/// Back (the screen arriving does). `SceneSwitcher` sets it on what leaves.
class BackMute extends InheritedWidget {
  const BackMute({super.key, required this.muted, required super.child});

  final bool muted;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackMute>()?.muted ?? false;

  @override
  bool updateShouldNotify(BackMute oldWidget) => muted != oldWidget.muted;
}

/// [router] with the browser's history held to one entry for the app, on top
/// of the page it was opened from (the engine's single-entry history):
///
/// - Every change of address replaces that entry, so history never fills
///   with game steps, and a reload finds the same one entry (none added).
/// - The browser's Back lands on the page under it, which the engine turns
///   into the phone's Back ([BackPolicy]) and puts the app's entry back;
///   where Back leaves (01), the app steps off its entry to the page before.
/// - An address typed in the bar is still opened by the router.
///
/// go_router itself asks for a history entry per change of address; this
/// reports each change in its place. Elsewhere than the web it changes
/// nothing (the platform ignores both messages). The same router gets the
/// same wrapper on every build.
RouterConfig<T> oneHistoryEntry<T>(RouterConfig<T> router) =>
    (_oneEntry[router] ??= RouterConfig<T>(
          routeInformationProvider: _OneHistoryEntry(
            router.routeInformationProvider!,
          ),
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          backButtonDispatcher: router.backButtonDispatcher,
        ))
        as RouterConfig<T>;

final _oneEntry = Expando<Object>('oneHistoryEntry');

class _OneHistoryEntry extends RouteInformationProvider {
  _OneHistoryEntry(this._router);

  final RouteInformationProvider _router;
  Uri? _reported;

  @override
  RouteInformation get value => _router.value;

  @override
  void addListener(VoidCallback listener) => _router.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _router.removeListener(listener);

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    final uri = routeInformation.uri;
    if (uri == _reported && type == RouteInformationReportingType.none) {
      return;
    }
    _reported = uri;
    unawaited(SystemNavigator.selectSingleEntryHistory());
    unawaited(SystemNavigator.routeInformationUpdated(uri: uri, replace: true));
  }

  @override
  String toString() => '${objectRuntimeType(this, '_OneHistoryEntry')}($value)';
}
