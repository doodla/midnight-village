import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

// The type scale is the owner's choice of 23 November 2026 ("Tight sizes, but
// keep the serif names"; docs/design/type-audit.md). It has one home: the skin's
// type roles. This guard fails when a text size, weight or face is set anywhere
// else in lib/, so a number cannot sneak back in; the caps per role are in
// skin_contract_test.dart ("every type role is inside the scale's caps").

/// What sets a text style by hand.
final _setsStyle = RegExp(
  r'fontSize\s*:|fontWeight\s*:|fontFamily\s*:|fontStyle\s*:|TextStyle\(',
);

/// Where a style may be set outside the skin: each is a role made smaller to
/// fit its room (a fit of a token, never a size of its own), with how many
/// lines, so a second one in the same file fails too. Debug screens
/// (`features/debug/`) are not a player's and are left out of the scan.
const _fits = {
  'design_system/primitives/fit_line.dart': (
    1,
    'FitLine and FitWords: a role set smaller until the words fit',
  ),
  'design_system/primitives/band.dart': (
    1,
    'the unit ("s") drawn at a share of its number',
  ),
  'design_system/primitives/face_down_card.dart': (
    1,
    'the one name size the board solved for every card',
  ),
  'design_system/primitives/player_row.dart': (
    1,
    'the one name size the two-up table rows share',
  ),
  'design_system/teach/hold_cue.dart': (
    1,
    'the cue word fitted into the hold ring',
  ),
  'design_system/night/board_layout.dart': (
    1,
    'the board measuring a name at a candidate size',
  ),
  'features/lobby/presentation/at_table_screen.dart': (
    1,
    'the two-up rows measuring a name at a candidate size',
  ),
};

String _withoutComments(String source) => source
    .split('\n')
    .map((line) {
      final at = line.indexOf('//');
      return at < 0 ? line : line.substring(0, at);
    })
    .join('\n');

void main() {
  test(
    'no text size, weight or face is set outside the skin\'s type roles',
    () {
      final lib = Directory('lib');
      final counts = <String, int>{};
      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        final path = file.path.substring('lib/'.length);
        if (!path.endsWith('.dart') ||
            path.endsWith('.g.dart') ||
            path.endsWith('.freezed.dart') ||
            path.startsWith('design_system/skin/') ||
            path.startsWith('features/debug/')) {
          continue;
        }
        final found = _withoutComments(
          file.readAsStringSync(),
        ).split('\n').where(_setsStyle.hasMatch).length;
        if (found > 0) counts[path] = found;
      }
      final stray = [
        for (final MapEntry(key: path, value: found) in counts.entries)
          if (found > (_fits[path]?.$1 ?? 0))
            '$path sets a text style by hand on $found line(s), '
                '${_fits[path]?.$1 ?? 0} allowed',
      ];
      expect(
        stray,
        isEmpty,
        reason:
            'Use a role from the skin (context.skin.typography). A size '
            'outside the roles is a second source of truth; a role that is '
            'missing is added in design_system/skin/skins/shadow_paper.dart '
            'and held to a cap in skin_contract_test.dart.',
      );
      final stale = [
        for (final MapEntry(key: path, value: (allowed, why)) in _fits.entries)
          if ((counts[path] ?? 0) < allowed) '$path ($why) no longer needs it',
      ];
      expect(stale, isEmpty, reason: 'Remove it from the allow-list.');
    },
  );

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
    expect(type.timer.fontSize, 84);
    expect(type.timerVote.fontSize, 76);
    expect(type.timerSmall.fontSize, 64);
    expect(type.timerCompact.fontSize, 27);
    expect(type.heroRole.fontSize, 46);
  });

  test('no role is under the reading floor of 12', () {
    for (final MapEntry(key: role, value: style)
        in SkinId.fallback.skin.typography.roles.entries) {
      expect(style.fontSize, greaterThanOrEqualTo(12), reason: role);
    }
  });
}
