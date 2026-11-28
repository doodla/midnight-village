import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/server_clock.dart';

// The phone's idea of the server's clock only ever moves forward: each answer
// says the server's clock had reached at least some moment, and the highest
// such floor wins. The owner's recording (28 November 2026) showed the talk's
// clock jump back 2 to 3 seconds every few seconds: each `/me/` answer carried
// the live host's held `Date` and set the clock back to it.

void main() {
  final start = DateTime.utc(2026, 11, 28, 9, 21, 31);
  late DateTime phone;
  late ServerClock clock;

  setUp(() {
    phone = start;
    clock = ServerClock(() => phone);
  });

  void pass(int ms) => phone = phone.add(Duration(milliseconds: ms));

  test(
    'an answer whose Date is older than one already heard changes nothing',
    () {
      clock.heard(start, stamp: true);
      pass(5000);
      // The live host's Date, held 4 seconds.
      expect(
        clock.heard(start.add(const Duration(seconds: 1)), stamp: true),
        isFalse,
      );
      expect(clock.now(), start.add(const Duration(seconds: 5)));
    },
  );

  test('an answer that knows more moves it forward, and only forward', () {
    clock.heard(start.subtract(const Duration(seconds: 15)), stamp: true);
    pass(1000);
    expect(
      clock.heard(start.add(const Duration(seconds: 1)), stamp: true),
      isTrue,
    );
    expect(clock.now(), start.add(const Duration(seconds: 1)));
  });

  test('a view pushed as its stage opens sets the clock to the opening', () {
    clock.heard(start.subtract(const Duration(seconds: 400)), stamp: true);
    pass(200);
    clock.heard(start.add(const Duration(milliseconds: 150)));
    expect(clock.now(), start.add(const Duration(milliseconds: 150)));
  });

  test("with no Date ever read the phone's own clock is one more floor", () {
    clock.heard(start.subtract(const Duration(minutes: 3)));
    expect(clock.now(), start);
    clock.heard(start.add(const Duration(seconds: 2)));
    expect(clock.now(), start.add(const Duration(seconds: 2)));
  });

  test("a phone whose own clock is minutes off reads the server's", () {
    phone = start.add(const Duration(minutes: 7));
    clock.heard(start, stamp: true);
    pass(3000);
    expect(
      clock.until(start.add(const Duration(seconds: 20))),
      const Duration(seconds: 17),
    );
  });
}
