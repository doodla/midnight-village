import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every night input in a test (the table, a prompt and what it lets a phone
/// pick, the faces, the results) is read from a payload the server recorded
/// (contract_samples/, through `recordedMe` in sheet_data.dart), never made
/// up. The language keeps most of it: the results, the seats, the pick rule
/// and the prompt have no public constructor, only parsers. This scans
/// `test/` and `test_screens/` for the ways that remain: a face put together
/// by hand, a prompt kind chosen by hand, a parser fed a literal map.
void main() {
  final rules = <(String, RegExp, String)>[
    (
      'a night face put together by hand (read it with NightReport)',
      RegExp(r'FaceContent\.(nightYou|copied|myNight)\(|FacePage\('),
      'FaceContent.nightYou(dealt: RoleId.seer, prompt: p)',
    ),
    (
      'a prompt kind chosen by hand (read it with ChoosePrompt.fromMe)',
      RegExp(r'NightPrompt\.(?!values\b|fromKind\b)\w+'),
      'final p = NightPrompt.seer;',
    ),
    (
      'a night parser fed a literal map (parse a recorded sample)',
      RegExp(
        r'\.(fromMe|fromPrompt|fromEntry|fromEntries|fromPlayer|seatsOf)\(\s*'
        r'(const\s+)?(<[^>]*>)?[\[{]',
      ),
      "ChoosePrompt.fromMe({'stage': 'w2'})",
    ),
  ];

  final files = [
    for (final root in ['test', 'test_screens'])
      ...Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('night_fixture_sources_test.dart')),
  ];

  for (final (what, pattern, example) in rules) {
    test('the rule against $what catches it', () {
      expect(pattern.hasMatch(example), isTrue);
    });

    test('no test builds $what', () {
      final offenders = [
        for (final file in files)
          for (final match in pattern.allMatches(file.readAsStringSync()))
            '${file.path}: ${match.group(0)}',
      ];
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  }
}
