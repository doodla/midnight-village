import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/perf/field_beacon.dart';
import 'package:midnight_village/core/perf/perf_records.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';

import 'perf_kit.dart';

/// The words a summary may hold are the server's closed lists
/// (`backend/apps/observe/vocabulary.py`): the app's screens, controls and
/// the server's routes. Each is read here from both sides; a new screen, a
/// new kind of control or a new route fails this until both sides name it,
/// so nothing the phone measures is dropped unseen.
void main() {
  final vocabulary = serverFile('apps/observe/vocabulary.py');
  final summary = serverFile('apps/observe/summary.py');

  test('every screen the recorder can name is one the server keeps', () {
    final home = File(
      'lib/features/lobby/presentation/home_gate.dart',
    ).readAsStringSync();
    final places = {
      for (final m in RegExp(r"BackRule\.\w+,\s*'(\w+)'").allMatches(home))
        m.group(1)!,
    };
    expect(places, isNotEmpty);
    expect(quotedWords(vocabulary, 'SCREENS'), {
      for (final s in AppScreen.values) s.name,
      ...places,
      'opening',
    });
  });

  test('every kind of control is one the server keeps', () {
    final kinds = File(
      'lib/design_system/perf/control_kind.dart',
    ).readAsStringSync();
    expect(quotedWords(vocabulary, 'CONTROLS'), {
      for (final m in RegExp(r"=> '(\w+)'").allMatches(kinds)) m.group(1)!,
      'other',
    });
  });

  test('a path keeps exactly the words of the server\'s routes', () {
    final words = <String>{};
    final files = [
      File('../backend/config/urls.py'),
      ...Directory('../backend/apps')
          .listSync()
          .whereType<Directory>()
          .map((d) => File('${d.path}/urls.py'))
          .where((f) => f.existsSync()),
    ];
    for (final file in files) {
      for (final m in RegExp(
        r'path\(\s*"([^"]*)"',
      ).allMatches(file.readAsStringSync())) {
        final route = m.group(1)!;
        if (route.startsWith('admin')) continue;
        words.addAll(
          route.split('/').where((s) => s.isNotEmpty && !s.contains('<')),
        );
      }
    }
    expect(apiWords, words);
  });

  test('the parts of a summary have the names the server keeps', () {
    expect(quotedWords(summary, 'CHANGE_LEGS'), {'first', 'content'});
    expect(quotedWords(summary, 'REQUEST_LEGS'), {
      'round',
      'server',
      'connect',
      'outside',
    });
    expect(quotedWords(summary, 'ENDS'), {FieldBeacon.endOfGame, 'hidden'});
    expect(quotedWords(summary, 'COLD_KINDS'), {'boot', 'db_wake'});
  });
}
