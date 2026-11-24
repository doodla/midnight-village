// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

// The type scale is the owner's choice of 23 November 2026 ("Tight sizes, but
// keep the serif names"; docs/design/type-audit.md). It has one home: the skin's
// type roles. This guard fails when a text size, weight or face is set anywhere
// else in lib/, so a number cannot sneak back in; the caps per role are in
// skin_contract_test.dart ("every type role is inside the scale's caps").

/// The one file that defines the tokens: the only place a text size, weight or
/// face is a number.
const _tokens = 'design_system/skin/skins/shadow_paper.dart';

/// What sets or changes a text size, weight or face by hand.
final _setsStyle = RegExp(
  r'fontSize\s*:|fontWeight\s*:|fontFamily\s*:|fontStyle\s*:|\bTextStyle\(',
);

/// What scales text without a size: `.apply(fontSizeFactor:` and
/// `fontSizeDelta:`, a `TextScaler.linear(` or `.clamp(`, a text scale set on
/// a `MediaQuery` (`MediaQueryData(`, `copyWith(textScaler:`, a minimum scale
/// factor, the old `textScaleFactor`). `TextScaler.noScaling` (a number that
/// keeps its size when the text grows) and `withClampedTextScaling` with only
/// a maximum (the board and the held face stop growing) never shrink text, and
/// are allowed.
final _scalesText = RegExp(
  r'fontSizeFactor|fontSizeDelta|TextScaler\.(linear|clamp)\(|'
  r'MediaQueryData\(|copyWith\(\s*textScaler|minScaleFactor|textScaleFactor',
);

/// A `FittedBox` or `Transform.scale` whose child is text: a second way to
/// shrink words below the floor. (A box around a whole layout is not caught by
/// a regex; the gallery's reading floor measures what is drawn.)
final _wrapsText = RegExp(
  r'(FittedBox|Transform\.scale)\([^;]{0,240}?child:\s*(const\s+)?'
  r'(Text|Text\.rich|RichText|FitLine|FitWords)\(',
  dotAll: true,
);

/// An exact place where a style is set or text is scaled outside the tokens:
/// the file, the trimmed line, and why. Each is a role made smaller to fit its
/// room (a fit of a token, never a size of its own). Debug screens
/// (`features/debug/`) are not a player's and are left out of the scan.
class _Site {
  const _Site(this.path, this.line, this.why);

  final String path;
  final String line;
  final String why;

  String get key => '$path: $line';
}

const _sites = [
  _Site(
    'design_system/skin/skin_theme.dart',
    'final quiet = TextStyle(color: g.quietText);',
    'a colour only, no size',
  ),
  _Site(
    'design_system/skin/skin_theme.dart',
    'fontFamily: type.body.fontFamily,',
    'the theme\'s family is the body token\'s own',
  ),
  _Site(
    'design_system/primitives/fit_line.dart',
    'fontSize: style.fontSize! * factor,',
    'FitWords: a role set smaller until the words fit its room',
  ),
  _Site(
    'design_system/primitives/face_down_card_words.dart',
    'style: base.copyWith(fontSize: fontSize),',
    'a face-up card\'s role name measured at a size that fits its card',
  ),
  _Site(
    'design_system/primitives/face_down_card_words.dart',
    'final style = base.copyWith(fontSize: size);',
    'a face-up card\'s role name set to fit its card (never under 12)',
  ),
  _Site(
    'design_system/primitives/timer_band.dart',
    'style: TextStyle(fontSize: size * unitShare),',
    'the clock\'s unit ("s") drawn at a share of its number',
  ),
  _Site(
    'design_system/primitives/timer_band.dart',
    'return FittedBox(',
    'ClockFigure: a clock\'s figure scaled down to its room',
  ),
  _Site(
    'design_system/primitives/world_timer.dart',
    'child: FittedBox(',
    'the night panel\'s number scaled down to its room',
  ),
  _Site(
    'design_system/primitives/face_down_card_words.dart',
    'fontSize: widget.nameSize,',
    'the one name size the board solved for every card',
  ),
  _Site(
    'design_system/primitives/player_row.dart',
    ': size.nameStyle(skin.typography).copyWith(fontSize: scoped);',
    'the one name size the two-up table rows share',
  ),
  _Site(
    'design_system/teach/hold_cue.dart',
    'fontSize: cue.fontSize! * fit,',
    'the cue word fitted into the hold ring',
  ),
  _Site(
    'design_system/night/board_layout.dart',
    'final oneLine = _lineHeight(nameStyle.copyWith(fontSize: size), scaler);',
    'the board measuring a name at a candidate size',
  ),
  _Site(
    'features/lobby/presentation/at_table_view.dart',
    '.copyWith(fontSize: size);',
    'the two-up rows measuring a name at a candidate size',
  ),
];

String _withoutComments(String source) => source
    .split('\n')
    .map((line) {
      final at = line.indexOf('//');
      return at < 0 ? line : line.substring(0, at);
    })
    .join('\n');

/// Every hand-set style, scaling or text wrapper in lib/, as `path: line`.
List<String> _hits() {
  final hits = <String>[];
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File) continue;
    final path = file.path.substring('lib/'.length);
    if (!path.endsWith('.dart') ||
        path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path == _tokens ||
        path.startsWith('features/debug/')) {
      continue;
    }
    final source = _withoutComments(file.readAsStringSync());
    final lines = source.split('\n');
    for (final line in lines) {
      if (_setsStyle.hasMatch(line) || _scalesText.hasMatch(line)) {
        hits.add('$path: ${line.trim()}');
      }
    }
    for (final match in _wrapsText.allMatches(source)) {
      final start = source.lastIndexOf('\n', match.start) + 1;
      final end = source.indexOf('\n', match.start);
      hits.add('$path: ${source.substring(start, end).trim()}');
    }
  }
  return hits;
}

void main() {
  test('no text size, weight, face or scale is set outside the tokens, '
      'except at the named sites', () {
    final hits = _hits();
    final allowed = {for (final site in _sites) site.key};
    final stray = [
      for (final hit in hits)
        if (!allowed.contains(hit)) hit,
    ];
    expect(
      stray,
      isEmpty,
      reason:
          'Use a role from the skin (context.skin.typography). A size or a '
          'scale outside the roles is a second source of truth; a role that '
          'is missing is added in $_tokens and held to a cap in '
          'skin_contract_test.dart. A fit of a role to its room is a named '
          'site in this test.',
    );
    final stale = [
      for (final site in _sites)
        if (!hits.contains(site.key)) '${site.key} (${site.why})',
    ];
    expect(stale, isEmpty, reason: 'No longer there: remove it from _sites.');
  });

  test('the guard sees what it is for', () {
    for (final bad in [
      'x.apply(fontSizeFactor: 0.8)',
      'x.apply(fontSizeDelta: -2)',
      'TextScaler.linear(0.8)',
      'MediaQuery(data: MediaQueryData(), child: c)',
      'data.copyWith(textScaler: s)',
      'MediaQuery.withClampedTextScaling(minScaleFactor: 0.5, child: c)',
    ]) {
      expect(_scalesText.hasMatch(bad), isTrue, reason: bad);
    }
    for (final fine in [
      'TextScaler.noScaling',
      'MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: c)',
    ]) {
      expect(_scalesText.hasMatch(fine), isFalse, reason: fine);
    }
    for (final bad in [
      'FittedBox(fit: BoxFit.scaleDown, child: Text(a))',
      'Transform.scale(scale: 0.5, child: const Text("a"))',
      'FittedBox(\n fit: BoxFit.scaleDown,\n child: FitWords(a, style: s))',
    ]) {
      expect(_wrapsText.hasMatch(bad), isTrue, reason: bad);
    }
    expect(
      _wrapsText.hasMatch('FittedBox(child: PlayerToken(owner))'),
      isFalse,
    );
  });

  test('the scale is the owner\'s: names 16 in the serif, questions 24, '
      'body 14, buttons 15, labels 12, timers and your role as they were', () {
    final type = SkinId.fallback.skin.typography;
    expect(type.name.fontSize, 16);
    expect(type.name.fontFamily, 'Gloock');
    expect(type.screenTitle.fontSize, 24);
    expect(type.headline.fontSize, 24);
    expect(type.body.fontSize, 14);
    expect(type.buttonLabel.fontSize, 15);
    expect(type.caption.fontSize, 12);
    expect(
      type.timerTalk.fontSize,
      40,
      reason: 'the square: the owner chose it',
    );
    expect(type.timerVote.fontSize, 76);
    expect(type.timerSmall.fontSize, 64);
    expect(type.heroRole.fontSize, 46);
  });

  test('no role is under the reading floor of 12', () {
    for (final MapEntry(key: role, value: style)
        in SkinId.fallback.skin.typography.roles.entries) {
      expect(style.fontSize, greaterThanOrEqualTo(12), reason: role);
    }
  });
}
