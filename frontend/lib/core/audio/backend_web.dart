import 'dart:ui_web' as ui_web;

import 'audio_backend.dart';
import 'web_audio_backend.dart';

/// The web: Web Audio, with assets at the URL Flutter serves them from.
AudioBackend platformBackend() =>
    WebAudioBackend(urlOf: ui_web.assetManager.getAssetUrl);

/// The page's `visibilitychange` tells the engine (`WebAudioBackend.listen`).
const backendWatchesVisibility = true;
