import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

// Every word a player sees or hears is in lib/design_system/copy/copy.dart
// (first-time play spec, section 1), so the widgets that draw the first-time
// play screens hold none: this reads their syntax and fails on any string
// that could reach a screen or a screen reader. Not counted: a string with
// no letters (digits, a separator, copy joined with a space), the server's
// keys and kinds (lower_snake_case, the protocol's words), and what only a
// developer reads (a thrown error, an assertion's message, a pattern, a
// `toString`).

const _folders = [
  'lib/design_system/primitives',
  'lib/design_system/faces',
  'lib/design_system/night',
  'lib/design_system/teach',
];

/// A key or a kind the server sends ("action_prompt", "doppelganger_look").
final _protocol = RegExp(r'^[a-z0-9_]+$');

/// What may stand in a widget file, and why.
const _allowed = <String>{
  // Where learned cues are stored on the device (learned_store.dart).
  'mv.learned.v1.',
};

final _letter = RegExp('[A-Za-z]');

List<String> spokenStrings(String source) {
  final visitor = _Visible();
  parseString(content: source).unit.accept(visitor);
  return visitor.found;
}

class _Visible extends RecursiveAstVisitor<void> {
  final found = <String>[];

  @override
  void visitImportDirective(ImportDirective node) {}

  @override
  void visitPartDirective(PartDirective node) {}

  @override
  void visitThrowExpression(ThrowExpression node) {}

  @override
  void visitAssertStatement(AssertStatement node) {}

  @override
  void visitAssertInitializer(AssertInitializer node) {}

  @override
  void visitAnnotation(Annotation node) {}

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != 'toString') super.visitMethodDeclaration(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme != 'RegExp') {
      super.visitInstanceCreationExpression(node);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'RegExp') super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) => _add(node.value);

  /// Only the written parts count: the gaps are values from elsewhere.
  @override
  void visitStringInterpolation(StringInterpolation node) => _add(
    node.elements.whereType<InterpolationString>().map((e) => e.value).join(),
    source: node.toSource(),
  );

  void _add(String value, {String? source}) {
    if (!_letter.hasMatch(value)) return;
    if (_protocol.hasMatch(value) || _allowed.contains(value)) return;
    found.add(source ?? value);
  }
}

void main() {
  test('the first-time play widgets hold no words of their own', () {
    final found = [
      for (final folder in _folders)
        for (final file in Directory(folder).listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              !file.path.endsWith('.g.dart'))
            for (final string in spokenStrings(file.readAsStringSync()))
              '${file.path}: "$string"',
    ];
    expect(found, isEmpty);
  });

  test('the scan finds a label written in a widget', () {
    expect(spokenStrings("final b = Text('Working');"), ['Working']);
    expect(
      spokenStrings("final s = Semantics(label: 'You, \$name');"),
      hasLength(1),
    );
    expect(spokenStrings("final k = json['action_prompt'];"), isEmpty);
    expect(spokenStrings("void f() => throw FormatException('No');"), isEmpty);
  });
}
