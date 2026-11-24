// Which widgets each catalogue state draws: the names of the widget classes in
// its tree, written to build/state_widgets.json. `tool/piece_check.py` turns
// class names into files and so knows which states a changed file can reach.
// Nothing is drawn to a picture here: a state is built, settled and walked.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_catalogue.dart';

const _out = String.fromEnvironment(
  'STATE_WIDGETS_OUT',
  defaultValue: 'build/state_widgets.json',
);

void main() {
  final seen = <String, List<String>>{};

  tearDownAll(() {
    File(_out)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(seen));
  });

  for (final entry in screenCatalogue) {
    final build = entry.build;
    if (build == null) continue;
    testWidgets(entry.id, (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Errors while it is up are other tests' business: this only reads the tree.
      final report = FlutterError.onError;
      FlutterError.onError = (_) {};
      final names = <String>{};
      void walk() {
        for (final element in tester.allElements) {
          // `Foo<Bar>` is the class Foo
          names.add(element.widget.runtimeType.toString().split('<').first);
        }
      }

      try {
        await build(tester);
        walk();
        // A state changes as it settles (a reveal, a sheet): what it draws on
        // the way counts too.
        for (var i = 0; i < (entry.frames ?? 10); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        walk();
      } catch (_) {
        // a state that cannot be built is always rendered: it gets no entry
        FlutterError.onError = report;
        return;
      }
      FlutterError.onError = report;
      seen[entry.id] = names.toList()..sort();
    });
  }
}
