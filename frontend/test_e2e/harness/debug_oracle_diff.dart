/// Computes a shallow key-by-key diff between an expected and actual map, for
/// the machine-readable failure output (contract §D5). Only keys whose values
/// differ appear in the result, as `{key: {expected, actual}}`.
Map<String, Object?> diffMaps(
  Map<String, Object?> expected,
  Map<String, Object?> actual,
) {
  final diff = <String, Object?>{};
  final keys = {...expected.keys, ...actual.keys};
  for (final key in keys) {
    final e = expected[key];
    final a = actual[key];
    if (!_deepEquals(e, a)) {
      diff[key] = {'expected': e, 'actual': a};
    }
  }
  return diff;
}

bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Set && b is Set) {
    return a.length == b.length && a.containsAll(b);
  }
  return a == b;
}
