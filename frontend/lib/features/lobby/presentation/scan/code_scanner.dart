import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/app_logger.dart';

part 'code_scanner.g.dart';

/// Why the camera cannot be used. Both end the same way for the player (one
/// calm line, then typing); they are told apart for the logs and the tests.
enum ScanProblem {
  /// The player (or the browser, or the phone's settings) said no.
  refused,

  /// No camera, a page that may not use one (not https), or a browser
  /// without the means.
  unavailable,
}

/// The light a camera has, if it has one.
enum LightState { unavailable, off, on }

/// A camera that reads QR codes: one per opening of the scanner, made when
/// the player taps scan (the camera is not touched before) and disposed the
/// moment the scanner leaves (the camera stops with it). The screen talks to
/// this, never to a plugin, so a test or a picture brings its own.
abstract class CodeScanner {
  /// The live camera, filling its room: starts the camera when it is built,
  /// calls [onText] with the text of every code it sees, and [onProblem]
  /// once, instead of showing anything, when the camera cannot be used.
  Widget view({
    required ValueChanged<String> onText,
    required ValueChanged<ScanProblem> onProblem,
  });

  /// Stops the camera now (a code was read); [dispose] ends the scanner.
  Future<void> stop();

  /// The camera's light, [LightState.unavailable] where there is none (the
  /// web has none).
  ValueListenable<LightState> get light;
  Future<void> toggleLight();

  void dispose();
}

/// Makes the scanner a tap on scan opens.
typedef CodeScannerFactory = CodeScanner Function();

/// The camera the app uses: `mobile_scanner` (Android and the web). Tests and
/// the screen gallery override this with their own.
@Riverpod(keepAlive: true)
CodeScannerFactory codeScannerFactory(Ref ref) => MobileCodeScanner.new;

/// [CodeScanner] on `mobile_scanner`: QR codes only, the back camera.
class MobileCodeScanner implements CodeScanner {
  MobileCodeScanner()
    : _controller = MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        facing: CameraFacing.back,
      ) {
    _controller.addListener(_lightChanged);
  }

  final MobileScannerController _controller;
  final _light = ValueNotifier(LightState.unavailable);

  void _lightChanged() {
    _light.value = switch (_controller.value.torchState) {
      TorchState.on => LightState.on,
      TorchState.off => LightState.off,
      _ => LightState.unavailable,
    };
  }

  @override
  ValueListenable<LightState> get light => _light;

  @override
  Widget view({
    required ValueChanged<String> onText,
    required ValueChanged<ScanProblem> onProblem,
  }) => MobileScanner(
    controller: _controller,
    // The camera stops with the app in the background and starts with it.
    useAppLifecycleState: true,
    onDetect: (capture) {
      for (final code in capture.barcodes) {
        final text = code.rawValue;
        if (text != null) onText(text);
      }
    },
    errorBuilder: (context, error) {
      logger.d('No camera (${error.errorCode})');
      final problem = error.errorCode == MobileScannerErrorCode.permissionDenied
          ? ScanProblem.refused
          : ScanProblem.unavailable;
      // After this frame: the screen changes while it builds otherwise.
      WidgetsBinding.instance.addPostFrameCallback((_) => onProblem(problem));
      return const SizedBox.shrink();
    },
  );

  @override
  Future<void> stop() async {
    try {
      await _controller.stop();
    } catch (e) {
      logger.d('The camera did not stop cleanly ($e)');
    }
  }

  @override
  Future<void> toggleLight() async {
    try {
      await _controller.toggleTorch();
    } catch (e) {
      logger.d('No light ($e)');
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_lightChanged)
      ..dispose();
    _light.dispose();
  }
}
