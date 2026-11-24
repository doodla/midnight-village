import 'package:flutter/widgets.dart';

/// Marks a layer that lies over the whole screen until one touch puts it
/// away: the first touch anywhere does only that, and what was under it can
/// be reached from the next.
///
/// It draws nothing and changes nothing. It is the kit saying so, where the
/// screen rules can read it (`test/helpers/screen_sweep.dart`): such a layer
/// may lie on the main action, as what a hold shows may, and the rules then
/// ask the one thing that makes that fair: one touch anywhere puts it away,
/// and the main action is reached after it.
class UntilTouched extends StatelessWidget {
  const UntilTouched({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
