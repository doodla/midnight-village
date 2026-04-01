import 'dart:async';
import 'dart:math' show min;

import 'package:web_socket_channel/web_socket_channel.dart' as wsc;

import '../logging/app_logger.dart';
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
    Duration maxBackoff = const Duration(seconds: 30),
    WebSocketChannelFactory? channelFactory,
  }) : _url = url,
       _tokenStorage = tokenStorage,
       _initialBackoff = initialBackoff,
       _maxBackoff = maxBackoff,
       _channelFactory = channelFactory ?? _defaultFactory,
       _currentBackoff = initialBackoff;

  final String _url;
  final TokenStorage _tokenStorage;
  final Duration _initialBackoff;
  final Duration _maxBackoff;
  final WebSocketChannelFactory _channelFactory;

  Duration _currentBackoff;
  bool _disposed = false;

  Timer? _reconnectTimer;
  WebSocketChannelInterface? _currentChannel;
  StreamSubscription<dynamic>? _channelSubscription;

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
  /// Emits [WebSocketConnectionState.connecting] immediately. If the factory
  /// fails, begins the backoff reconnect loop automatically.
  Future<void> connect() async {
    if (_disposed) return;
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
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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

    try {
      final channel = _channelFactory(uri);

      unawaited(_channelSubscription?.cancel() ?? Future.value());
      _channelSubscription = null;
      _currentChannel = channel;
      _currentBackoff = _initialBackoff; // reset backoff on successful connect

      _emitState(WebSocketConnectionState.connected);

      _channelSubscription = channel.stream.listen(
        (event) {
          if (!_disposed) _messageController.add(event);
        },
        onError: (Object _) {
          if (!_disposed) _onChannelClosed();
        },
        onDone: () {
          if (!_disposed) _onChannelClosed();
        },
        cancelOnError: false,
      );
    } catch (e, stack) {
      logger.w('WebSocket connect failed', error: e, stackTrace: stack);
      if (_disposed) return;
      if (!isReconnect) {
        // Emit disconnected once before entering the reconnect loop so
        // listeners see the full state transition.
        _emitState(WebSocketConnectionState.disconnected);
      }
      _scheduleReconnect();
    }
  }

  void _onChannelClosed() {
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
  void send(dynamic data) => _channel.sink.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    _isClosed = true;
    await _channel.sink.close(code, reason);
  }

  @override
  bool get isClosed => _isClosed;
}
