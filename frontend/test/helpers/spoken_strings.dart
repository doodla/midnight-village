import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

// The words in a Dart file that could reach a screen or a screen reader, read
// from its syntax: what widget_strings_test.dart (the design system) and
// raw_values_test.dart (the screens) hold to "every word is in copy.dart".
// Not counted: a string with no letters (digits, a separator, copy joined
// with a space), the server's keys and kinds (lower_snake_case, the
// protocol's words), and what only a developer reads (a thrown error, an
// assertion's message, a pattern, a log line, a `toString`).

/// A key or a kind the server sends ("action_prompt", "doppelganger_look").
final _protocol = RegExp(r'^[a-z0-9_]+$');

/// What may stand in a widget file, and why.
const _allowed = <String>{
  // Where learned cues are stored on the device (learned_store.dart).
  'mv.learned.v1.',
};

final _letter = RegExp('[A-Za-z]');

/// The strings in [source] a player could see or hear.
List<String> spokenStrings(String source) {
  final visitor = _Visible();
  parseString(content: source, throwIfDiagnostics: false).unit.accept(visitor);
  return visitor.found;
}

class _Visible extends RecursiveAstVisitor<void> {
  final found = <String>[];

  @override
  void visitImportDirective(ImportDirective node) {}

  @override
  void visitPartDirective(PartDirective node) {}

  @override
  void visitPartOfDirective(PartOfDirective node) {}

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

  /// A line for the developer's log (`logger.w(...)`) never reaches a screen.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'RegExp') return;
    if (node.target case SimpleIdentifier(name: 'logger')) return;
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) => _add(node.value);

  /// Only the written parts count: the gaps are values from elsewhere. A
  /// written part is a word unless it is a key with an underscore in it
  /// (`'${kind}_seen'`): a bare lowercase part (`'${n}s'`, `'$n players'`)
  /// is a word a player reads.
  @override
  void visitStringInterpolation(StringInterpolation node) {
    final written = node.elements
        .whereType<InterpolationString>()
        .map((e) => e.value)
        .join();
    if (!_letter.hasMatch(written)) return;
    if (written.contains('_') && _protocol.hasMatch(written)) return;
    if (_allowed.contains(written)) return;
    found.add(node.toSource());
  }

  void _add(String value) {
    if (!_letter.hasMatch(value)) return;
    if (_protocol.hasMatch(value) || _allowed.contains(value)) return;
    found.add(value);
  }
}
