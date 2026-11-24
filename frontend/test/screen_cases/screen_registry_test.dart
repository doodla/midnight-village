import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'not_yet_swept.dart';
import 'sweep_run.dart';

// Every screen state `just screens` draws is swept (sweep_run.dart) unless it
// is on the to-do list in not_yet_swept.dart, so a new state is swept the
// moment it is in the catalogue: there is no second place to add it. The
// to-do list only shrinks: what is on it is still a state of the catalogue,
// and nothing is on it that main's list did not have.

const _list = 'test/screen_cases/not_yet_swept.dart';

final _key = RegExp(r"^\s*'([^']+)':", multiLine: true);

/// The ids on the to-do list at origin/main, or null when git cannot say
/// (no git, no origin/main, or main has no list yet).
Set<String>? _onMainsList() {
  final prefix = Process.runSync('git', ['rev-parse', '--show-prefix']);
  if (prefix.exitCode != 0) return null;
  final path = '${(prefix.stdout as String).trim()}$_list';
  final shown = Process.runSync('git', ['show', 'origin/main:$path']);
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
}
