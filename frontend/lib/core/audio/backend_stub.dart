import 'audio_backend.dart';
import 'silent_backend.dart';

/// Not the web: silence (`backend_web.dart` is the web's).
AudioBackend platformBackend() => SilentBackend();

/// Whether the platform tells the engine itself when the app is hidden (the
/// web does, from the page; elsewhere `Sounds` listens to the app's
/// lifecycle).
const backendWatchesVisibility = false;
