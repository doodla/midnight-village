import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/env.dart';
import '../../core/perf/beacon.dart';
import '../../core/perf/field_beacon.dart';
import '../../core/perf/field_recorder.dart';
import '../../core/perf/perf.dart';
import '../../core/perf/perf_env.dart';
import '../../core/perf/perf_report.dart';
import '../../core/perf/perf_switch.dart';
import '../../core/storage/tab_storage.dart';
import '../../core/update/build_id.dart';
import '../layout/space.dart';
import '../primitives/text_action.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'control_kind.dart';

/// Switches the field recorder on, web only, called once before the app
/// runs:
/// - with its strip when this tab asked for it (`?perf=1`, remembered for
///   the tab; `?perf=0` switches it off): kept on the phone, copied by hand;
/// - else quietly on a build with a commit (the live app): no strip, and a
///   summary at each game's end (and of the play before a hidden tab) goes
///   to the server (`FieldBeacon`). A build with no commit (a local run, the
///   tests) stays off and sends nothing.
///
/// Nothing here can stop the app: anything that throws leaves the recorder
/// off.
void startPerfField() {
  if (!kIsWeb) return;
  try {
    final strip = perfSwitchedOn(pageQuery(), openTabStorage());
    if (!strip && !quietField) return;
    perfPrepare();
    if (!strip) {
      final url = '${Env.apiUrl}/observe/summary/';
      final (beacon, _) = startQuietField(
        now: perfNow,
        send: (summary) => sendBeacon(url, summary),
        environment: () => perfEnvironment(gpu: false),
        resourceTiming: perfResourceTiming,
        sent: perfClearResourceTimings,
      );
      whenHidden(beacon.hidden);
      return;
    }
    final recorder = FieldRecorder(
      now: perfNow,
      controlAt: controlAt,
      environment: perfEnvironment(),
      resourceTiming: perfResourceTiming,
    )..install();
    Perf.recorder = recorder;
    _strip = recorder;
  } catch (_) {
    _strip = null;
    Perf.recorder = const PerfOff();
  }
}

/// The quiet recorder and its beacon, switched on: the live app's, and a
/// test run's with `--dart-define=FIELD_QUIET=true` (`test/flutter_test_config.dart`,
/// `test_e2e/flutter_test_config.dart`: every screen and the harness with it
/// on). Returns the beacon and what switches both off.
(FieldBeacon, void Function()) startQuietField({
  required double Function() now,
  required bool Function(String summary) send,
  Map<String, Object?> Function()? environment,
  ({double start, double end})? Function(String url, double after)?
  resourceTiming,
  void Function()? sent,
}) {
  final recorder = FieldRecorder(
    now: now,
    controlAt: controlAt,
    resourceTiming: resourceTiming,
  )..install();
  Perf.recorder = recorder;
  final beacon = FieldBeacon(
    recorder: recorder,
    commit: BuildId.mine,
    send: send,
    environment: environment,
    sent: sent,
  );
  recorder.screenChanged = beacon.screenShown;
  return (
    beacon,
    () {
      beacon.screenShown('');
      recorder.uninstall();
      Perf.recorder = const PerfOff();
    },
  );
}

/// The quiet mode: on for a build with a commit; `--dart-define=FIELD_QUIET=true`
/// switches it on in a build without one (`just phone-frames`, to measure
/// what it costs).
const bool quietField =
    bool.fromEnvironment('FIELD_QUIET') ||
    (BuildId.mine != BuildId.local && BuildId.mine != '');

FieldRecorder? _strip;

/// The field recorder's strip under the app, when `?perf=1` asked for it;
/// otherwise the app itself, untouched (also while the quiet mode records).
Widget perfStripAround(Widget app) => switch (_strip) {
  final FieldRecorder recorder => PerfStrip(recorder: recorder, child: app),
  _ => app,
};

/// A strip of paper pinned at the bottom edge, above the system bar, with
/// the last tap's times. The app sits above it (pushed up by its height,
/// never under it); tapped, it opens the summary over the app. It repaints
/// only when a tap finishes, on a layer of its own. Hidden while the
/// keyboard is up.
class PerfStrip extends StatefulWidget {
  const PerfStrip({super.key, required this.recorder, required this.child});

  final FieldRecorder recorder;
  final Widget child;

  @override
  State<PerfStrip> createState() => _PerfStripState();
}

class _PerfStripState extends State<PerfStrip> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom > 0;
    return Stack(
      children: [
        Column(
          // The strip runs edge to edge.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: !keyboard,
                child: widget.child,
              ),
            ),
            if (!keyboard)
              _Strip(
                recorder: widget.recorder,
                bottom: media.padding.bottom > media.viewPadding.bottom
                    ? media.padding.bottom
                    : media.viewPadding.bottom,
                onTap: () => setState(() => _open = !_open),
              ),
          ],
        ),
        if (_open)
          Positioned.fill(
            child: PerfOwn(
              child: _Summary(
                recorder: widget.recorder,
                onClose: () => setState(() => _open = false),
              ),
            ),
          ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.recorder,
    required this.bottom,
    required this.onTap,
  });

  final FieldRecorder recorder;
  final double bottom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PerfOwn(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: GroundScope(
            ground: GroundKind.paper,
            fill: true,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Space.md,
                Space.xs,
                Space.md,
                Space.xs + bottom,
              ),
              child: ValueListenableBuilder(
                valueListenable: recorder.finished,
                builder: (context, tap, _) => Text(
                  stripLine(tap),
                  // Two lines always: the strip keeps its height.
                  maxLines: 2,
                  style: context.skin.typography.caption.copyWith(
                    color: context.ground.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The summary: the report as it would be pasted, its two copies and
/// Clear. Over the app, from the bottom edge; a tap on the scrim, or on the
/// strip again, closes it.
class _Summary extends StatefulWidget {
  const _Summary({required this.recorder, required this.onClose});

  final FieldRecorder recorder;
  final VoidCallback onClose;

  @override
  State<_Summary> createState() => _SummaryState();
}

class _SummaryState extends State<_Summary> {
  late String _report = _read();
  String? _said;

  String get _commit => BuildId.isReal(BuildId.mine) ? BuildId.mine : '';

  String _read() => shortReport(widget.recorder, commit: _commit);

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _said = PerfWords.copied);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final height = MediaQuery.sizeOf(context).height;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: ColoredBox(color: skin.scrim),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height * 0.8),
            child: GroundScope(
              ground: GroundKind.paper,
              fill: true,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(child: _Body(report: _report)),
                      const SizedBox(height: Space.sm),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          TextAction(
                            label: _said ?? PerfWords.copyReport,
                            onPressed: () => _copy(_report),
                          ),
                          TextAction(
                            label: PerfWords.copyAll,
                            onPressed: () => _copy(
                              fullReport(widget.recorder, commit: _commit),
                            ),
                          ),
                          TextAction(
                            label: PerfWords.clear,
                            onPressed: () {
                              widget.recorder.clear();
                              setState(() {
                                _report = _read();
                                _said = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report});

  final String report;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final ink = context.ground.text;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(PerfWords.legs, style: type.body.copyWith(color: ink)),
          const SizedBox(height: Space.sm),
          Text(report, style: type.caption.copyWith(color: ink)),
        ],
      ),
    );
  }
}
