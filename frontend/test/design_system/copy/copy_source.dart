import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Every string written in the Dart file at [path] (imports aside), as its
/// value, with the strings that interpolate (copy is never built in place:
/// gaps are `{name}`, filled by `Template.fill`).
({List<String> strings, List<String> interpolated}) stringsIn(String path) {
  final unit = parseString(content: File(path).readAsStringSync()).unit;
  final visitor = _Strings();
  unit.accept(visitor);
  return (strings: visitor.strings, interpolated: visitor.interpolated);
}

class _Strings extends RecursiveAstVisitor<void> {
  final strings = <String>[];
  final interpolated = <String>[];

  @override
  void visitImportDirective(ImportDirective node) {}

  @override
  void visitAdjacentStrings(AdjacentStrings node) => _add(node);

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) => _add(node);

  @override
  void visitStringInterpolation(StringInterpolation node) =>
      interpolated.add(node.toSource());

  void _add(StringLiteral node) {
    final value = node.stringValue;
    if (value == null) {
      interpolated.add(node.toSource());
    } else {
      strings.add(value);
    }
  }
}
