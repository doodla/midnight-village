import 'package:flutter/foundation.dart';

/// A line of copy with named gaps, `{name}`, filled where it is shown. The
/// gaps are not words (first-time play spec, copy rule 1), so the copy
/// budget test counts the line as written here.
@immutable
class Template {
  const Template(this.raw);

  final String raw;

  static final _gap = RegExp(r'\{(\w+)\}');

  /// The gaps' names, in order.
  Iterable<String> get gaps => _gap.allMatches(raw).map((m) => m[1]!);

  /// The line with every gap filled from [values], which must name each gap
  /// and nothing else.
  String fill(Map<String, Object> values) {
    assert(
      setEquals(values.keys.toSet(), gaps.toSet()),
      '"$raw" fills ${gaps.toSet()}, given ${values.keys.toSet()}',
    );
    return raw.replaceAllMapped(_gap, (m) => '${values[m[1]]}');
  }

  /// The line with its gaps filled by [values], in the order they come.
  String fillIn(List<Object> values) {
    assert(values.length == gaps.length, '"$raw" fills ${gaps.length}');
    var i = 0;
    return raw.replaceAllMapped(_gap, (_) => '${values[i++]}');
  }

  @override
  String toString() => raw;
}
