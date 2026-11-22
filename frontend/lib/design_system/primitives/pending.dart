import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../copy/copy.dart';

/// Why a request did not work, in the words its control shows (6 words at
/// most, first-time play spec: "Banners and errors").
@immutable
class RequestFailure {
  const RequestFailure(this.words, {this.canRetry = true, this.resend = true});

  /// "Not sent." (no answer: it may not have arrived), or the server's
  /// reason in the player's words ("That table is playing now.").
  final String words;

  /// "Try again" helps: nothing the player did was wrong.
  final bool canRetry;

  /// "Try again" sends the request again. False: the request was answered
  /// and it is the read of the next screen that is failing, which "Try again"
  /// reads again (the request is never sent twice for it).
  final bool resend;

  /// No answer came (or a 5xx): the one failure "Try again" is for.
  static const notSent = RequestFailure(BannerCopy.notSent);

  /// The request was answered; the screen it leads to cannot be read.
  static const offline = RequestFailure(BannerCopy.offline, resend: false);
}

/// A request the server refused with words of its own: [Pending.run] shows
/// [why] (never "Not sent.", which is only for a request that did not
/// reach it).
class RequestRefused implements Exception {
  const RequestRefused(this.why, {this.canRetry = false});

  final String why;
  final bool canRetry;

  @override
  String toString() => 'RequestRefused: $why';
}

/// What a control's request is doing.
enum PendingPhase {
  /// Nothing sent (or the last one worked).
  idle,

  /// Sent, no answer yet (and, for a request that leads to another screen,
  /// that screen not up yet).
  busy,

  /// The last request did not work: [Pending.failure] says how.
  failed,
}

/// One control's request: the state a tapped control shows.
///
/// - The tap answers in the same frame: [run] sets busy and tells its
///   listeners before it sends anything, so the control's `busy` look (the
///   `BusyMark` beside its label) is on the next frame.
/// - A second tap while it is busy does nothing ([run] returns false and
///   sends nothing).
/// - The request goes out through [playerRequest], the one door.
/// - It settles to done ([PendingPhase.idle]), or to a [RequestFailure]
///   with the control's own "Try again" ([retry]: the very same request,
///   as first made). The failure lives and dies with the control: when the
///   screen goes, so does it; it can never appear later or on another
///   screen.
/// - For a request that leads to another screen, [run]'s `settle` keeps the
///   control busy past the answer until that screen is up, so the button is
///   never live again in the gap between the answer and the next screen.
///   `settle` is the read that names the next screen (it is made again by
///   itself until it answers; its failure is not this request's).
///
/// Nothing here waits: no minimum time, no assumed length.
class Pending extends ChangeNotifier {
  PendingPhase _phase = PendingPhase.idle;
  RequestFailure? _failure;
  Future<void> Function()? _last;
  Future<bool> Function(bool again)? _lastSettle;
  bool _disposed = false;

  PendingPhase get phase => _phase;
  bool get busy => _phase == PendingPhase.busy;
  bool get failed => _phase == PendingPhase.failed;

  /// How the last request failed; null unless [failed].
  RequestFailure? get failure => _failure;

  /// Sends [send] now unless one is on its way. True when it worked.
  ///
  /// [settle] reads the screen the request leads to: true when it is named,
  /// false when the read is failing (`readAnswered`); [again] is true for a
  /// "Try again" of that read. A failing read frees the control (it does not
  /// spin for as long as the phone is out of reach) and says "One moment"
  /// with "Try again".
  Future<bool> run(
    Future<void> Function() send, {
    Future<bool> Function(bool again)? settle,
  }) async {
    if (busy || _disposed) return false;
    _last = send;
    _lastSettle = settle;
    _set(PendingPhase.busy);
    try {
      await send();
    } catch (e) {
      logger.d('A request did not work ($e)');
      if (_disposed) return false;
      _failure = e is RequestRefused
          ? RequestFailure(e.why, canRetry: e.canRetry)
          : RequestFailure.notSent;
      _set(PendingPhase.failed);
      return false;
    }
    if (_disposed) return true;
    return _settle(settle, again: false);
  }

  Future<bool> _settle(
    Future<bool> Function(bool again)? settle, {
    required bool again,
  }) async {
    var named = true;
    if (settle != null) {
      try {
        named = await settle(again);
      } catch (e) {
        logger.d('The screen after a request is not read yet ($e)');
        named = false;
      }
    }
    if (_disposed) return true;
    if (named) {
      _set(PendingPhase.idle);
    } else {
      _failure = RequestFailure.offline;
      _set(PendingPhase.failed);
    }
    return true;
  }

  /// "Try again": the last request, as first made; or, when it was
  /// answered and the next screen could not be read, that read again.
  Future<bool> retry() {
    final again = _last;
    if (again == null || busy) return Future.value(false);
    if (_failure?.resend == false) {
      _set(PendingPhase.busy);
      return _settle(_lastSettle, again: true);
    }
    return run(again, settle: _lastSettle);
  }

  /// Forgets a failure (the player is doing something else).
  void clear() {
    if (failed) _set(PendingPhase.idle);
  }

  void _set(PendingPhase phase) {
    _phase = phase;
    if (phase != PendingPhase.failed) _failure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
