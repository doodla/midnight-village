import 'package:flutter/widgets.dart';

/// Text kept to one line that is set smaller rather than broken or clipped:
/// for names that must never break mid-word ("Doppelganger", "Troublemaker").
class FitLine extends StatelessWidget {
  const FitLine(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false, style: style),
  );
}
