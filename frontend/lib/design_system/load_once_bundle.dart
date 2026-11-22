import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The bundle the app's pictures are read from ([DefaultAssetBundle] over
/// the app, and `SkinLoader`): on the web, [LoadOnceBundle] over the root
/// bundle; elsewhere the root bundle itself (no network under it).
final AssetBundle appAssets = kIsWeb ? LoadOnceBundle(rootBundle) : rootBundle;

/// Reads each file once per run and hands the same bytes to every later
/// read. A picture is decoded at each size it is drawn (`ArtImage.decodedFor`:
/// a role's portrait in a held face and in a thumbnail), and every decode
/// reads the file: on the web each read is a request, so without this one
/// picture crosses the network once per size, the later ones as
/// revalidations the server must answer. A read that fails is forgotten, so
/// the next one asks again.
class LoadOnceBundle extends AssetBundle {
  LoadOnceBundle(this._inner);

  final AssetBundle _inner;
  final _reads = <String, Future<ByteData>>{};

  @override
  Future<ByteData> load(String key) => _reads.putIfAbsent(key, () {
    final read = _inner.load(key);
    read.then<void>(
      (_) {},
      onError: (Object _) {
        _reads.remove(key);
      },
    );
    return read;
  });

  @override
  Future<ImmutableBuffer> loadBuffer(String key) async {
    final bytes = await load(key);
    return ImmutableBuffer.fromUint8List(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      _inner.loadString(key, cache: cache);

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) => _inner.loadStructuredData(key, parser);

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) => _inner.loadStructuredBinaryData(key, parser);

  @override
  void evict(String key) {
    _reads.remove(key);
    _inner.evict(key);
  }

  @override
  void clear() {
    _reads.clear();
    _inner.clear();
  }
}
