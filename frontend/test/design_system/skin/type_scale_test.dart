import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/skins/shadow_paper.dart';
import 'package:midnight_village/design_system/skin/type_scale.dart';

// The type-size review's options (docs/design/type-audit.md): the shipped
// scale is the default, and each option keeps to its numbers.

Set<double> _sizes(TypeScale scale) => {
  for (final MapEntry(key: role, value: style) in shadowPaperType(
    scale,
  ).roles.entries)
    if (!role.startsWith('timer') && role != 'heroRole') style.fontSize!,
};

void main() {
  test('the shipped scale is today unless a build says otherwise', () {
    expect(TypeScale.current, TypeScale.today);
  });

  test('no option sets a role under 12', () {
    for (final scale in TypeScale.values) {
      for (final MapEntry(key: role, value: style) in shadowPaperType(
        scale,
      ).roles.entries) {
        expect(
          style.fontSize,
          greaterThanOrEqualTo(12),
          reason: '$scale $role',
        );
      }
    }
  });

  test('the options name names at 18 and 16, titles at 28 and 24', () {
    final compact = shadowPaperType(TypeScale.compact);
    final tight = shadowPaperType(TypeScale.tight);
    expect(compact.name.fontSize, 18);
    expect(compact.screenTitle.fontSize, 28);
    expect(tight.name.fontSize, 16);
    expect(tight.screenTitle.fontSize, 24);
  });

  test('the timers and the role on a held face stay as big as today', () {
    final today = shadowPaperType(TypeScale.today);
    for (final scale in [TypeScale.compact, TypeScale.tight]) {
      final type = shadowPaperType(scale);
      expect(type.timer.fontSize, today.timer.fontSize);
      expect(type.timerVote.fontSize, today.timerVote.fontSize);
      expect(type.timerSmall.fontSize, today.timerSmall.fontSize);
      expect(type.timerCompact.fontSize, today.timerCompact.fontSize);
      expect(type.heroRole.fontSize, today.heroRole.fontSize);
    }
  });

  test('the options use fewer distinct sizes than today', () {
    final today = _sizes(TypeScale.today).length;
    expect(_sizes(TypeScale.compact).length, lessThan(today));
    expect(_sizes(TypeScale.tight).length, lessThan(today));
  });

  test('every option reads smaller than today, role for role', () {
    final today = shadowPaperType(TypeScale.today).roles;
    for (final scale in [TypeScale.compact, TypeScale.tight]) {
      for (final MapEntry(key: role, value: style) in shadowPaperType(
        scale,
      ).roles.entries) {
        expect(
          style.fontSize,
          lessThanOrEqualTo(today[role]!.fontSize!),
          reason: '$scale $role',
        );
      }
    }
  });
}
