import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;

import 'package:web_socket_channel/web_socket_channel.dart' as wsc;

import '../logging/app_logger.dart';
import '../perf/perf.dart';
import '../storage/token_storage.dart';
import 'websocket_channel.dart';

/// Factory type for creating underlying WebSocket channels.
///
/// The default factory wraps the real `web_socket_channel` package.
/// Inject a mock factory in tests via the [ReconnectingWebSocket] constructor.
typedef WebSocketChannelFactory = WebSocketChannelInterface Function(Uri uri);

/// Production WebSocket client with automatic exponential-backoff reconnection.
///
/// On disconnect or failed connection attempt, [ReconnectingWebSocket] waits
/// [initialBackoff] before retrying. Each failed attempt doubles the wait up
/// to [maxBackoff]. On a successful connection, the backoff resets to
/// [initialBackoff].
///
/// JWT is re-read from [tokenStorage] on every connection attempt so that
/// a token refreshed by [AuthInterceptor] is always used.
///
/// Usage:
/// ```dart
/// final ws = ReconnectingWebSocket(url: wsUrl, tokenStorage: storage);
/// await ws.connect();
/// ws.stream.listen(handleEvent);
/// ws.send({'type': 'ready'});
/// ws.dispose();
/// ```
class ReconnectingWebSocket implements WebSocketChannelInterface {
  ReconnectingWebSocket({
    required String url,
    required TokenStorage tokenStorage,
    Duration initialBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(seconds: 2),
    Duration openTimeout = const Duration(seconds: 10),
    WebSocketChannelFactory? channelFactory,
  }) : _url = url,
       _openTimeout = openTimeout,
       _tokenStorage = tokenStorage,
       _initialBackoff = initialBackoff,
       _maxBackoff = maxBackoff,
       _channelFactory = channelFactory ?? _defaultFactory,
       _currentBackoff = initialBackoff;

  final String _url;
  final TokenStorage _tokenStorage;
  final Duration _initialBackoff;

  /// The longest wait between two attempts. Short on purpose: nothing else
  /// brings a socket back (a resume and the healing reads go over HTTP), and
  /// after a deploy the server gives phones seconds, not half a minute, to be
  /// back before it counts them away. A table is a handful of phones, so there
  /// is no crowd to hold off. (Until "connected" meant "open", the backoff was
  /// reset on every attempt and a phone retried every second.)
  final Duration _maxBackoff;

  /// The longest an opening connection is waited for before it counts as
  /// failed and the next attempt is scheduled. It bounds a server that never
  /// answers; a healthy one answers in a fraction of a second, and nothing
  /// waits this out.
  final Duration _openTimeout;
  final WebSocketChannelFactory _channelFactory;

  /// Counts connection attempts, so what a superseded attempt hears late (its
  /// channel closing, its opening failing) is not taken for the current one's.
  int _attempt = 0;
  final _firstOpen = Completer<void>();

  Duration _currentBackoff;
  bool _disposed = false;

  Timer? _reconnectTimer;
  final _openTimers = <Timer>{};
  WebSocketChannelInterface? _currentChannel;
  StreamSubscription<dynamic>? _channelSubscription;

  // ---------------------------------------------------------------------------
  // The beat: "connected" is believed only while frames keep coming.
  // ---------------------------------------------------------------------------

  /// Whether this server sends beats (`{"type": "beat", "every": s}`, every
  /// socket, every `every` seconds), and how often. Learned from the first
  /// beat any socket hears; until then (an older server) "connected" is
  /// believed as it is.
  static Duration? _beatEvery;

  /// Forgets what was learned of the server's beat (tests).
  static void forgetTheBeat() => _beatEvery = null;

  /// Fires when this connection has heard nothing for about two beats and a
  /// half: it is dead though it looks open (a phone that slept, a network that
  /// changed under it), so it is closed and opened again, and opening again
  /// reads everything the screen depends on.
  Timer? _silence;

  /// Fires when a beat is overdue: [verify] then opens the socket again.
  Timer? _overdueTimer;
  bool _overdue = false;

  /// Drops the connection of the current attempt (closes it; the usual
  /// "disconnected", then the reconnect).
  void Function()? _dropCurrent;

  /// A frame came on the current connection: the clocks start again.
  void _heard() {
    _silence?.cancel();
    _overdueTimer?.cancel();
    _overdue = false;
    final every = _beatEvery;
    if (every == null) return;
    _silence = Timer(every * 2.5, () {
      logger.w('WebSocket silent past two beats: opening it again');
      _dropCurrent?.call();
    });
    _overdueTimer = Timer(every * 1.2, () => _overdue = true);
  }

  /// Whether [event] is the server's beat (it is not passed on): it also
  /// teaches how often beats come.
  static bool _isBeat(dynamic event) {
    if (event is! String || event.length > 80 || !event.contains('"beat"')) {
      return false;
    }
    try {
      final frame = jsonDecode(event);
      if (frame is! Map || frame['type'] != 'beat') return false;
      final every = frame['every'];
      if (every is num && every > 0) {
        _beatEvery = Duration(milliseconds: (every * 1000).round());
      }
      return true;
    } on FormatException {
      return false;
    }
  }

  /// The app came back to the foreground: a socket that missed a beat while
  /// the phone was away may be dead though it looks open, so it is opened
  /// again now (opening reads everything again). One that is down is tried at
  /// once. Nothing is done for a socket that is hearing its beats.
  void verify() {
    if (_disposed) return;
    if (_reconnectTimer?.isActive ?? false) {
      _reconnectTimer?.cancel();
      unawaited(_doConnect(isReconnect: true));
    } else if (_overdue) {
      _dropCurrent?.call();
    }
  }

  final _messageController = StreamController<dynamic>.broadcast(sync: true);
  final _stateController = StreamController<WebSocketConnectionState>.broadcast(
    sync: true,
  );

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Broadcast stream of connection state transitions.
  Stream<WebSocketConnectionState> get connectionState =>
      _stateController.stream;

  // ---------------------------------------------------------------------------
  // WebSocketChannelInterface
  // ---------------------------------------------------------------------------

  @override
  Stream<dynamic> get stream => _messageController.stream;

  /// Completes the first time a connection is open, or at [dispose]; never
  /// with an error (a failed opening is tried again, it is not the end). It
  /// stays complete through later drops: [connectionState] says what the
  /// socket is now.
  @override
  Future<void> get ready => _firstOpen.future;

  @override
  void send(dynamic data) => _currentChannel?.send(data);

  @override
  Future<void> close([int? code, String? reason]) async => dispose();

  @override
  bool get isClosed => _disposed;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts the initial connection attempt.
  ///
  /// Emits [WebSocketConnectionState.connecting] immediately, and
  /// [WebSocketConnectionState.connected] when the server has accepted the
  /// connection. If it cannot be opened, begins the backoff reconnect loop.
  Future<void> connect() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _currentBackoff = _initialBackoff;
    await _doConnect(isReconnect: false);
  }

  /// Cancels any pending reconnect timer and releases all resources.
  ///
  /// After [dispose], [isClosed] is `true`. No further reconnection attempts
  /// will be made.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_firstOpen.isCompleted) _firstOpen.complete();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _silence?.cancel();
    _overdueTimer?.cancel();
    for (final timer in _openTimers) {
      timer.cancel();
    }
    _openTimers.clear();
    unawaited(_channelSubscription?.cancel() ?? Future.value());
    _channelSubscription = null;
    unawaited(_currentChannel?.close() ?? Future.value());
    _currentChannel = null;
    unawaited(_messageController.close());
    unawaited(_stateController.close());
  }

  // ---------------------------------------------------------------------------
  // Internal connection logic
  // ---------------------------------------------------------------------------

  Future<void> _doConnect({required bool isReconnect}) async {
    if (_disposed) return;
    _emitState(WebSocketConnectionState.connecting);

    final token = await _tokenStorage.accessToken;
    if (_disposed) return;

    final uri = _buildUri(token);
    final attempt = ++_attempt;
    var over = false;

    // This attempt's connection is gone (it never opened, or it closed): once.
    void lost() {
      if (over || _disposed || attempt != _attempt) return;
      over = true;
      _onChannelClosed();
    }

    final WebSocketChannelInterface channel;
    try {
      channel = _channelFactory(uri);
    } catch (e, stack) {
      logger.w('WebSocket connect failed', error: e, stackTrace: stack);
      if (!isReconnect) {
        // Emit disconnected once before entering the reconnect loop so
        // listeners see the full state transition.
        _emitState(WebSocketConnectionState.disconnected);
      }
      _scheduleReconnect();
      return;
    }

    unawaited(_channelSubscription?.cancel() ?? Future.value());
    // An earlier attempt's channel is never left open behind this one: the
    // server would hold a socket nobody listens to.
    final earlier = _currentChannel;
    if (earlier != null && !earlier.isClosed) unawaited(earlier.close());
    _currentChannel = channel;
    // Listened to from the start: nothing the server sends once the
    // connection opens can arrive before there is a listener.
    _channelSubscription = channel.stream.listen(
      (event) {
        if (!_disposed && attempt == _attempt) {
          Perf.recorder.socketMessage(_url, event);
          _heard();
          if (_isBeat(event)) return _heard(); // it may have taught the pace
          _messageController.add(event);
        }
      },
      onError: (Object _) => lost(),
      onDone: lost,
      cancelOnError: false,
    );

    // Making the channel only STARTS the connection. "Connected" is said when
    // the server has accepted it, and not before: whoever reads state again on
    // "connected" must not read before the socket can hear what follows.
    final opened = Completer<void>();
    // Each attempt has its own timer: one that is superseded still gives up.
    late final Timer giveUp;
    giveUp = Timer(_openTimeout, () {
      _openTimers.remove(giveUp);
      if (!opened.isCompleted) {
        opened.completeError(TimeoutException('not open in $_openTimeout'));
      }
    });
    _openTimers.add(giveUp);
    unawaited(
      channel.ready.then(
        (_) {
          if (!opened.isCompleted) opened.complete();
        },
        onError: (Object e) {
          if (!opened.isCompleted) opened.completeError(e);
        },
      ),
    );
    try {
      await opened.future;
    } catch (e) {
      logger.w('WebSocket did not open', error: e);
      if (!over && !_disposed && attempt == _attempt) {
        unawaited(channel.close());
        lost();
      }
      return;
    } finally {
      giveUp.cancel();
      _openTimers.remove(giveUp);
    }
    if (over || _disposed || attempt != _attempt) return;
    _currentBackoff = _initialBackoff; // an open connection resets the backoff
    if (!_firstOpen.isCompleted) _firstOpen.complete();
    _dropCurrent = () {
      if (over || _disposed || attempt != _attempt) return;
      unawaited(channel.close());
      lost();
    };
    _heard(); // its first beat is due within two and a half
    _emitState(WebSocketConnectionState.connected);
  }

  void _onChannelClosed() {
    _silence?.cancel();
    _overdueTimer?.cancel();
    _overdue = false;
    _dropCurrent = null;
    _emitState(WebSocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _emitState(WebSocketConnectionState.reconnecting);

    final backoff = _currentBackoff;
    _currentBackoff = Duration(
      milliseconds: min(
        _currentBackoff.inMilliseconds * 2,
        _maxBackoff.inMilliseconds,
      ),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(backoff, () {
      if (!_disposed) unawaited(_doConnect(isReconnect: true));
    });
  }

  Uri _buildUri(String? token) {
    final base = Uri.parse(_url);
    final params = Map<String, String>.from(base.queryParameters);
    if (token != null) {
      params['token'] = token;
    }
    return base.replace(queryParameters: params);
  }

  void _emitState(WebSocketConnectionState state) {
    if (!_disposed && !_stateController.isClosed) {
      Perf.recorder.socketState(_url, state);
      _stateController.add(state);
    }
  }

  // ---------------------------------------------------------------------------
  // Default factory (production)
  // ---------------------------------------------------------------------------

  static WebSocketChannelInterface _defaultFactory(Uri uri) =>
      _LiveWebSocketChannel(wsc.WebSocketChannel.connect(uri));
}

/// Adapts [wsc.WebSocketChannel] from the `web_socket_channel` package to
/// [WebSocketChannelInterface].
class _LiveWebSocketChannel implements WebSocketChannelInterface {
  _LiveWebSocketChannel(this._channel);

  final wsc.WebSocketChannel _channel;
  bool _isClosed = false;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  Future<void> get ready => _channel.ready;

  @override
  void send(dynamic data) => _channel.sink.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    _isClosed = true;
    await _channel.sink.close(code, reason);
  }

  @override
  bool get isClosed => _isClosed;
}
