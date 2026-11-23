// The gallery's parts cover the catalogue: every screen is rendered by exactly
// one part, and there is a test file for every part. Runs with `just screens`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'screen_catalogue.dart';
import 'screens_run.dart';

void main() {
  test('every catalogue entry is in exactly one part', () {
    final seen = <String>[
      for (var shard = 1; shard <= screenShards; shard++)
        ...entriesOfShard(shard).map((e) => e.id),
    ];

    expect(
      seen.toSet().length,
      seen.length,
      reason: 'an entry is in two parts',
    );
    expect(seen.toSet(), screenCatalogue.map((e) => e.id).toSet());
  });

  test('the parts are about the same size', () {
    final sizes = [
      for (var shard = 1; shard <= screenShards; shard++)
        entriesOfShard(shard).where((e) => e.build != null).length,
    ];

    expect(
      sizes.reduce((a, b) => a > b ? a : b) -
          sizes.reduce((a, b) => a < b ? a : b),
      lessThanOrEqualTo(1),
    );
  });

  test('there is one test file per part, and no other', () {
    final files = Directory('test_screens')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where(
          (name) => RegExp(r'^screens_\d+of\d+_test\.dart$').hasMatch(name),
        )
        .toSet();

    expect(files, {
      for (var shard = 1; shard <= screenShards; shard++)
        'screens_${shard}of${screenShards}_test.dart',
    });
  });
}
