part of 'field_recorder.dart';

/// One HTTP request on its way, as the field recorder sees it.
class _HttpMark implements HttpMark {
  _HttpMark(this._recorder, this._record);

  final FieldRecorder _recorder;
  final HttpRecord _record;

  void _name(RequestOptions options) {
    if (_record.method.isNotEmpty) return;
    final url = options.uri.toString();
    _record
      ..method = options.method.toUpperCase()
      ..path = cleanPath(url)
      ..url = url;
  }

  @override
  void left(RequestOptions? options) {
    _record.leftAt ??= _recorder.now();
    if (options != null) _name(options);
  }

  @override
  void arrived(int status, Map<String, List<String>> headers) {
    _record
      ..arrivedAt = _recorder.now()
      ..status = status;
    final timing = serverTiming(headers['server-timing']?.join(','));
    _record
      ..serverConnect = timing.connect
      ..serverTotal = timing.total;
  }

  @override
  Future<T> watch<T>(Future<T> sent) => sent.then(
    (answer) {
      _done(answer is Response ? answer : null, null);
      return answer;
    },
    onError: (Object error, StackTrace stack) {
      _done(null, error is DioException ? error : null);
      Error.throwWithStackTrace(error, stack);
    },
  );

  void _done(Response<Object?>? answer, DioException? failure) {
    _record.doneAt = _recorder.now();
    final options = answer?.requestOptions ?? failure?.requestOptions;
    if (options != null) _name(options);
    _record.status ??= answer?.statusCode ?? failure?.response?.statusCode;
    if (_record.serverTotal == null && answer != null) {
      final timing = serverTiming(answer.headers.value('server-timing'));
      _record
        ..serverConnect = timing.connect
        ..serverTotal = timing.total;
    }
    final url = _record.url;
    if (url != null) {
      final net = _recorder.resourceTiming?.call(
        url,
        (_record.leftAt ?? _record.queuedAt) - 1,
      );
      _record
        ..netStart = net?.start
        ..netEnd = net?.end
        ..url = null;
    }
    _recorder._answered(_record);
  }
}

/// One player request: its end is when the app has applied the answer.
class _RequestMark implements RequestMark {
  _RequestMark(this._recorder, this._tap);

  final FieldRecorder _recorder;
  final TapRecord _tap;

  @override
  void applied() => _recorder._applied(_tap);
}
