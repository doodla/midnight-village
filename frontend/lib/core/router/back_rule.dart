/// What Back does on a screen when nothing is open on top of it (owner's
/// rules, 22 November 2026). Every screen has one: `backRuleFor` in the
/// screen table names it for each `AppScreen`, `HomeGate` for its waits.
enum BackRule {
  /// The start (01): Back leaves the app.
  leavesApp,

  /// A waiting table (02): Back asks first, through the table's own leave
  /// confirmation ("Stay" / "Leave"); the screen answers it ([BackHandler]).
  asksToLeave,

  /// The set-up page (03): Back returns to the table (02); the screen
  /// answers it ([BackHandler]).
  closesToTable,

  /// A game, or a wait before the screen is known: Back does nothing. Only
  /// Leave exits a game.
  staysPut,
}
