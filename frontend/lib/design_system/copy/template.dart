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

  @override
  String toString() => raw;
}
