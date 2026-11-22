import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/lobby/domain/table_link.dart';
import 'package:midnight_village/features/lobby/presentation/home_numbers.dart';

// What a scan or a paste may hold, and the link a table shares.

void main() {
  group('tableCodeFrom reads a table link', () {
    const code = 'V9YC2J';

    test('in the path form, of any origin', () {
      for (final link in [
        'https://midnight-village-app-anthelion.vercel.app/join/$code',
        'http://localhost:3000/join/$code',
        'https://play.example.org/join/$code/',
        'https://play.example.org/join/$code?from=qr',
        'https://play.example.org/join/$code#top',
        'https://play.example.org/app/join/$code',
        '/join/$code',
        'join/$code',
      ]) {
        expect(tableCodeFrom(link), code, reason: link);
      }
    });

    test('in any case, and with spaces round it', () {
      expect(tableCodeFrom('https://x.example/join/v9yc2j'), code);
      expect(tableCodeFrom('  https://x.example/join/V9yC2j \n'), code);
    });
  });

  group('tableCodeFrom reads a bare code', () {
    test('in any case', () {
      expect(tableCodeFrom('V9YC2J'), 'V9YC2J');
      expect(tableCodeFrom('v9yc2j'), 'V9YC2J');
      expect(tableCodeFrom('V9yC2j'), 'V9YC2J');
    });

    test('with spaces in it or round it', () {
      expect(tableCodeFrom(' V9YC2J '), 'V9YC2J');
      expect(tableCodeFrom('V9Y C2J'), 'V9YC2J');
      expect(tableCodeFrom('v9y c2j\n'), 'V9YC2J');
      expect(tableCodeFrom('V 9 Y C 2 J'), 'V9YC2J');
    });
  });

  group('tableCodeFrom ignores anything else', () {
    test('without a word', () {
      for (final junk in [
        '',
        '   ',
        'hello',
        'V9YC2',
        'V9YC2JK',
        'V9YC-J',
        'https://example.com',
        'https://example.com/about',
        'https://example.com/rejoin/V9YC2J',
        'https://example.com/join/V9YC2JK',
        'https://example.com/join/V9YC',
        'https://example.com/join/',
        'WIFI:T:WPA;S:cafe;P:secret;;',
        'BEGIN:VCARD\nFN:Ana\nEND:VCARD',
        'two words here',
        // Not the server's alphabet (no 0, O, I, 1 or L): never a table's.
        '123456',
        'HELLO2',
        'V9YC1J',
        'https://example.com/join/V9YC1J',
        'https://example.com/join/OOOOOO',
      ]) {
        expect(tableCodeFrom(junk), isNull, reason: junk);
      }
    });
  });

  group('joinLink', () {
    test('is the origin and /join/<code>, a path and no fragment', () {
      expect(
        joinLink(Uri.parse('https://midnight.example'), 'V9YC2J').toString(),
        'https://midnight.example/join/V9YC2J',
      );
      expect(
        joinLink(Uri.parse('https://midnight.example/'), 'V9YC2J').toString(),
        'https://midnight.example/join/V9YC2J',
      );
    });

    test('keeps a port and a base path, drops what the page had after', () {
      expect(
        joinLink(
          Uri.parse('http://localhost:3000/?x=1#top'),
          'V9YC2J',
        ).toString(),
        'http://localhost:3000/join/V9YC2J',
      );
      expect(
        joinLink(Uri.parse('https://x.example/app/'), 'V9YC2J').toString(),
        'https://x.example/app/join/V9YC2J',
      );
    });

    test('is a link tableCodeFrom reads back', () {
      final link = joinLink(Uri.parse('https://x.example'), 'AB32CD');
      expect(tableCodeFrom(link.toString()), 'AB32CD');
    });
  });
}
