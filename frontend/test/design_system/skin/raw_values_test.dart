import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/spoken_strings.dart';

// Screen code (lib/features/**/presentation/) takes its sizes from the skin
// and its words from copy.dart: a number written where a size, a gap, a
// padding, an offset, a radius, a duration or an opacity goes, or a sentence
// written in a widget, is a second source of truth that drifts.
//
// A number counts when it is written as the value of a named argument that is
// a size (`height: 13`, `padding: ...`, `duration: ...`, the list below), or
// as an argument of what makes one (`SizedBox`, `EdgeInsets.*`, `Offset`,
// `Size`, `Radius.circular`, `Duration`, `Opacity`, `withValues`...). Never
// counted: 0, 1 and 2 (none, whole, a pair), an index, a count, an
// alignment's fraction (`Alignment(0.5, 0)` is not a size).
//
// It fails only on what a change ADDS: screen code is compared with itself at
// the merge base with origin/main (where the branch left main, so main moving
// on adds nothing here), all files together (a value moved within a file, to
// another file, or with a renamed file is not new), so the screens that hold
// raw values today pass until someone adds one, and nobody keeps a number per
// file. Without a merge base it fails on GitHub (which fetches main's history)
// and, on a machine, says so and checks nothing.

const _screens = 'lib/features';

/// Named arguments whose value is a size, a place, a time or a strength.
const _sizeNames = {
  'width',
  'height',
  'size',
  'padding',
  'margin',
  'radius',
  'borderRadius',
  'elevation',
  'spacing',
  'runSpacing',
  'mainAxisSpacing',
  'crossAxisSpacing',
  'top',
  'bottom',
  'left',
  'right',
  'start',
  'end',
  'horizontal',
  'vertical',
  'all',
  'offset',
  'dx',
  'dy',
  'duration',
  'reverseDuration',
  'milliseconds',
  'microseconds',
  'seconds',
  'opacity',
  'alpha',
  'strokeWidth',
  'blurRadius',
  'spreadRadius',
  'minHeight',
  'maxHeight',
  'minWidth',
  'maxWidth',
  'thickness',
  'indent',
  'endIndent',
  'itemExtent',
  'gap',
  'angle',
  'turns',
  'scale',
  'extent',
  'cacheExtent',
  'iconSize',
  'splashRadius',
};

/// What makes a size, a place, a time or a strength from bare numbers.
const _sizeMakers = {
  'SizedBox',
  'EdgeInsets',
  'EdgeInsetsDirectional',
  'Offset',
  'Size',
  'Radius',
  'BorderRadius',
  'Duration',
  'Opacity',
  'withOpacity',
  'withValues',
  'withAlpha',
  'BoxConstraints',
  'Gap',
  'Transform',
};

const _harmless = {0, 1, 2};

/// The raw sizes and sentences in [source], each as its line's text (so a
/// line moved within the file is the same one).
List<String> rawValues(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final numbers = _Numbers(source);
  unit.accept(numbers);
  return [
    ...numbers.found,
    for (final words in spokenStrings(source)) 'words: $words',
  ];
}

class _Numbers extends RecursiveAstVisitor<void> {
  _Numbers(this.source);

  final String source;
  final found = <String>[];

  @override
  void visitIntegerLiteral(IntegerLiteral node) => _check(node, node.value);

  @override
  void visitDoubleLiteral(DoubleLiteral node) => _check(node, node.value);

  void _check(Literal node, num? value) {
    if (value == null || _harmless.contains(value)) return;
    if (!_inSizePlace(node)) return;
    final start = source.lastIndexOf('\n', node.offset) + 1;
    final end = source.indexOf('\n', node.offset);
    final line = source.substring(start, end < 0 ? source.length : end);
    found.add('size: ${line.trim()}');
  }

  /// Climbs from the number through arithmetic and a minus to the argument
  /// it is part of, and says whether that argument is a size.
  bool _inSizePlace(AstNode node) {
    AstNode? at = node;
    while (at != null) {
      final parent = at.parent;
      if (parent is NamedExpression) {
        if (_sizeNames.contains(parent.name.label.name)) return true;
        at = parent;
        continue;
      }
      if (parent is ArgumentList) return _makesSize(parent.parent);
      if (parent is BinaryExpression ||
          parent is PrefixExpression ||
          parent is ParenthesizedExpression ||
          parent is ConditionalExpression) {
        at = parent;
        continue;
      }
      return false;
    }
    return false;
  }

  bool _makesSize(AstNode? call) {
    final names = switch (call) {
      InstanceCreationExpression c => [
        c.constructorName.type.name.lexeme,
        c.constructorName.name?.name,
      ],
      MethodInvocation m => [
        m.methodName.name,
        if (m.target case SimpleIdentifier(:final name)) name,
      ],
      _ => const <String?>[],
    };
    return names.any(_sizeMakers.contains);
  }
}

String? _git(List<String> args) {
  final r = Process.runSync('git', args);
  return r.exitCode == 0 ? (r.stdout as String).trim() : null;
}

/// Where this branch left main: the merge base of HEAD and origin/main, or
/// null when git cannot say (no git, no origin/main, a shallow history).
String? mergeBase() => _git(['merge-base', 'HEAD', 'origin/main']);

/// Screen code as it was at [base]: every screen file there, and the file
/// each screen file now was before it was moved or renamed into place (a
/// moved file is not new code). Paths as git names them from here
/// (frontend/).
List<String> _atBase(String base) {
  final before = <String>[];
  final listed = _git(['ls-tree', '-r', '--name-only', base, '--', _screens]);
  for (final path in (listed ?? '').split('\n')) {
    if (!_isScreenCode(path)) continue;
    final shown = _git(['show', '$base:./$path']);
    if (shown != null) before.add(shown);
  }
  final renamed = _git([
    'diff',
    '-M',
    '--name-status',
    '--relative',
    base,
    '--',
    '.',
  ]);
  for (final line in (renamed ?? '').split('\n')) {
    final parts = line.split('\t');
    if (parts.length != 3 || !parts[0].startsWith('R')) continue;
    if (_isScreenCode(parts[1]) || !_isScreenCode(parts[2])) continue;
    final shown = _git(['show', '$base:./${parts[1]}']);
    if (shown != null) before.add(shown);
  }
  return before;
}

bool _isScreenCode(String path) =>
    path.startsWith('$_screens/') &&
    path.contains('/presentation/') &&
    path.endsWith('.dart') &&
    !path.endsWith('.g.dart') &&
    !path.endsWith('.freezed.dart') &&
    !path.startsWith('$_screens/debug/');

/// What [now] holds that [before] did not, each as often as it is new.
List<String> added(List<String> now, List<String> before) {
  final left = <String, int>{};
  for (final v in before) {
    left[v] = (left[v] ?? 0) + 1;
  }
  return [
    for (final v in now)
      if ((left[v] = (left[v] ?? 0) - 1) < 0) v,
  ];
}

void main() {
  test('screen code adds no raw size and no sentence of its own', () {
    final base = mergeBase();
    if (base == null) {
      const why =
          'no merge base with origin/main here (no git, no origin/main, or a '
          'shallow history): nothing to compare with';
      if (Platform.environment['GITHUB_ACTIONS'] == 'true') {
        fail(
          '$why. GitHub must fetch main\'s history (the workflow\'s '
          '"Fetch main" step).',
        );
      }
      // ignore: avoid_print
      print('raw_values_test: skipped, $why.');
      markTestSkipped(why);
      return;
    }
    // Every value screen code held at the merge base, wherever it was: a
    // value that moved (to another place in its file, or to another file)
    // is not new.
    final before = [for (final text in _atBase(base)) ...rawValues(text)];
    final now = <(String, String)>[
      for (final file in Directory(_screens).listSync(recursive: true))
        if (file is File && _isScreenCode(file.path))
          for (final value in rawValues(file.readAsStringSync()))
            (file.path, value),
    ];
    final found = [
      for (final value in added([for (final (_, v) in now) v], before))
        '$value, in ${{for (final (path, v) in now)
          if (v == value) path}.join(', ')}',
    ];
    expect(
      found,
      isEmpty,
      reason:
          'A size, a gap, a padding, an offset, a radius, a duration or an '
          'opacity in screen code is a token: `Space` and `Motion` '
          '(lib/design_system/layout/, lib/design_system/motion/), the skin '
          '(`context.skin.shape`, `.parts`, `.type`; '
          'lib/design_system/skin/skins/shadow_paper.dart). Words a player '
          'reads or hears are in lib/design_system/copy/copy.dart. A token '
          'that is missing is added there, never written in the screen.',
    );
  });

  test('the guard sees what it is for', () {
    for (final bad in [
      'final w = SizedBox(height: 13);',
      'final p = EdgeInsets.all(10);',
      'final p = EdgeInsets.symmetric(horizontal: 3 * 4.0);',
      'final d = Duration(milliseconds: 250);',
      'final o = Offset(0, -6);',
      'final c = color.withValues(alpha: 0.6);',
      "final t = Text('\${n}s');",
      "final t = Text('Ready');",
    ]) {
      expect(rawValues(bad), isNotEmpty, reason: bad);
    }
    for (final fine in [
      'final w = SizedBox(height: Space.md);',
      'final p = EdgeInsets.all(0);',
      'final a = Alignment(0.5, 0);',
      'final x = list[3];',
      'final n = players.length > 4;',
      'final d = Duration(seconds: deadline);',
      "final k = json['action_prompt'];",
      "final k = '\${kind}_seen';",
    ]) {
      expect(rawValues(fine), isEmpty, reason: fine);
    }
  });

  test('only what a change adds is new', () {
    expect(added(['a', 'a', 'b'], ['a', 'b', 'c']), ['a']);
    expect(added(['a'], const []), ['a']);
  });
}
