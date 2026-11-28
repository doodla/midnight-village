import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'not_yet_swept.dart';
import 'settled_not_yet.dart';
import 'sweep_run.dart';

// Every screen state `just screens` draws is swept (sweep_run.dart) unless it
// is on the to-do list in not_yet_swept.dart, so a new state is swept the
// moment it is in the catalogue: there is no second place to add it. The
// to-do list only shrinks: what is on it is still a state of the catalogue,
// and nothing is on it that main's list did not have. So with settled_test's
// to-do (settled_not_yet.dart), whose keys are id prefixes.

const _list = 'test/screen_cases/not_yet_swept.dart';
const _settledList = 'test/screen_cases/settled_not_yet.dart';

final _key = RegExp(r"^\s*'([^']+)':", multiLine: true);

/// The keys of a to-do list at origin/main, or null when git cannot say
/// (no git, no origin/main, or main has no list yet).
Set<String>? _onMainsList([String list = _list]) {
  final prefix = Process.runSync('git', ['rev-parse', '--show-prefix']);
  if (prefix.exitCode != 0) return null;
  final path = '${(prefix.stdout as String).trim()}$list';
  // Where this branch left main, not main as it is now: the list on main
  // only shrinks, so a branch that is merely behind it would seem to have
  // added what main has since taken off.
  final left = Process.runSync('git', ['merge-base', 'origin/main', 'HEAD']);
  final base = left.exitCode == 0
      ? (left.stdout as String).trim()
      : 'origin/main';
  final shown = Process.runSync('git', ['show', '$base:$path']);
  if (shown.exitCode != 0) return null;
  return {for (final m in _key.allMatches(shown.stdout as String)) m.group(1)!};
}

void main() {
  test('the to-do list names only states the sweep would hold', () {
    final swept = {for (final e in sweptEntries()) e.id};
    final stale = [
      for (final id in notYetSwept.keys)
        if (!swept.contains(id)) id,
    ];
    expect(
      stale,
      isEmpty,
      reason:
          'Not a swept state of the catalogue (renamed, removed, or a '
          'component sheet page): take it off $_list.',
    );
  });

  test('the to-do list only shrinks: nothing on it that main did not have', () {
    final onMain = _onMainsList();
    if (onMain == null) {
      markTestSkipped('no list at origin/main to compare with');
      return;
    }
    final added = [
      for (final id in notYetSwept.keys)
        if (!onMain.contains(id)) id,
    ];
    expect(
      added,
      isEmpty,
      reason:
          'A screen state was put on the to-do list. A new or changed state '
          'meets the screen rules (test/helpers/screen_sweep.dart) before it '
          'is handed over: fix what the sweep says. The list is for states '
          'that failed before the rules were written.',
    );
  });

  test('the settled to-do names only screens the sweep holds', () {
    final swept = [for (final e in sweptEntries()) e.id];
    final stale = [
      for (final prefix in settledNotYet.keys)
        if (!swept.any((id) => id.startsWith(prefix))) prefix,
    ];
    expect(
      stale,
      isEmpty,
      reason: 'No swept state starts with these: take them off $_settledList.',
    );
  });

  test('the settled to-do only shrinks: each key narrows one main had', () {
    final onMain = _onMainsList(_settledList);
    if (onMain == null) {
      markTestSkipped('no settled list at origin/main to compare with');
      return;
    }
    final added = [
      for (final prefix in settledNotYet.keys)
        if (!onMain.any(prefix.startsWith)) prefix,
    ];
    expect(
      added,
      isEmpty,
      reason:
          'Something was put on $_settledList, or a key there was widened. '
          'A state meets the settled rules (test/helpers/settled_parts.dart) '
          'before it is handed over: fix what settled_test.dart says.',
    );
  });
}
