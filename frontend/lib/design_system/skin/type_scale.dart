/// The type scale the app is built with. ONE private switch, used only to
/// render the owner's options (`docs/design/type-audit.md`): build or test
/// with `--dart-define=TYPE_SCALE=compact` (or `tight`). Without it the scale
/// is [today], the shipped one. Once the owner picks, the losing scales and
/// this switch are deleted and the winning numbers become the only ones.
enum TypeScale {
  /// The shipped sizes (the mocks', rebalanced once on the first screen and
  /// the table).
  today,

  /// Names 18, screen titles 28, body 15, labels 12.
  compact,

  /// Names 16, screen titles 24, everything else a step under compact.
  tight;

  /// The scale this build is made with.
  static final current = _fromName(
    const String.fromEnvironment('TYPE_SCALE', defaultValue: 'today'),
  );

  /// The value of the running scale.
  static T pick<T>({required T today, required T compact, required T tight}) =>
      switch (current) {
        TypeScale.today => today,
        TypeScale.compact => compact,
        TypeScale.tight => tight,
      };

  static TypeScale _fromName(String name) => switch (name) {
    'compact' => TypeScale.compact,
    'tight' => TypeScale.tight,
    _ => TypeScale.today,
  };
}
