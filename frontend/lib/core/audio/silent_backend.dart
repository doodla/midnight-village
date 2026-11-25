import 'audio_backend.dart';
import 'sound_set.dart';

/// No sound: every platform but the web, until Android has its own backend
/// (a later piece). It decodes nothing, so the engine never asks it to play.
class SilentBackend implements AudioBackend {
  bool _open = false;

  @override
  bool get isOpen => _open;

  @override
  void open(double gain) => _open = true;

  @override
  void discard() => _open = false;

  @override
  AudioState get state => AudioState.running;

  @override
  double get now => 0;

  @override
  double get baseLatency => 0;

  @override
  Future<void> resume() async {}

  @override
  Future<void> suspend() async {}

  @override
  bool canDecode(String path) => false;

  @override
  Future<void> fetch(String path) async {}

  @override
  Future<Clip> decode(String path) =>
      Future.error(UnsupportedError('no sound on this platform'));

  @override
  void release(Clip clip) {}

  @override
  void master(double to, double seconds) {}

  @override
  void fire(Clip clip) {}

  @override
  Voice loop(
    Clip clip,
    ThemeVariant variant, {
    required double at,
    required double offset,
    required double fadeIn,
    LoopPoints? points,
  }) => Voice(clip, variant);

  @override
  void fadeOut(
    Voice voice,
    double seconds, {
    double? at,
    void Function()? ended,
  }) => ended?.call();

  @override
  void listen({
    required void Function(bool activates) gesture,
    required void Function(bool shown) visible,
  }) {}
}
