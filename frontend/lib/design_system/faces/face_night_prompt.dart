part of 'face_content.dart';

/// What a night prompt asks of this phone, by the prompt's `kind`, one to
/// one: what its "You" face says, the board's title, and the words of its
/// button (what will happen with the picks; what passing is for this role).
enum NightPrompt {
  noChoice(
    'none',
    NightCopy.noChoice,
    CommonCopy.nightTitle,
    go: NightCopy.choose,
    pass: NightCopy.skip,
  ),
  seer(
    'seer',
    NightCopy.seer,
    NightCopy.seerTitle,
    go: NightCopy.see,
    pass: NightCopy.skip,
    seats: NightCopy.seerSeats,
    strip: NightCopy.seerCenter,
  ),
  robber(
    'robber',
    NightCopy.robber,
    NightCopy.robberTitle,
    go: NightCopy.swapWith,
    pass: NightCopy.keep,
  ),
  troublemaker(
    'troublemaker',
    NightCopy.troublemaker,
    NightCopy.troublemakerTitle,
    go: NightCopy.swap,
    pass: NightCopy.skip,
  ),
  drunk(
    'drunk',
    NightCopy.drunk,
    NightCopy.drunkTitle,
    go: NightCopy.swapWith,
    pass: NightCopy.chooseForMe,
  ),
  loneWerewolf(
    'lone_werewolf',
    NightCopy.loneWerewolf,
    NightCopy.loneWerewolfTitle,
    go: NightCopy.see,
    pass: NightCopy.skip,
  ),
  doppelgangerLook(
    'doppelganger_look',
    NightCopy.doppelgangerLook,
    NightCopy.doppelgangerTitle,
    go: NightCopy.copyCard,
    pass: NightCopy.skip,
  ),

  /// A kind this app does not know (the server added one): a plain board
  /// that still lets the player pick a card or skip, never a crash in a
  /// player's hand mid-game. The picks it takes are the prompt's `shapes`.
  generic(
    'generic',
    NightCopy.chooseNone,
    NightCopy.chooseNone,
    go: NightCopy.choose,
    pass: NightCopy.skip,
  );

  const NightPrompt(
    this.kind,
    this.instruction,
    this.title, {
    required this.go,
    required this.pass,
    this.seats,
    this.strip,
  });

  /// The server's name for it.
  final String kind;
  final String instruction;

  /// The board's headline: the role's night line in a few words for a
  /// phone with a choice; "The village sleeps" for a sleeper.
  final String title;

  /// The button once the picks are whole: what will happen to them ("See
  /// {cards}", "Swap with {cards}"); a sleeper has no button, and carries
  /// the plain "Choose {cards}" so no kind is ever without one.
  final Template go;

  /// The button with "You" alone picked: what passing is, for this role.
  final Words pass;

  /// The words this board adds above its seats and on the table's strip in
  /// place of "Center", with a rule saying "or" between them (the Seer's,
  /// who may pick from either: the owner chose it, 22 November 2026); null
  /// for every other prompt, whose board keeps the room empty.
  final String? seats;
  final String? strip;

  /// The prompt of [kind]; a kind this app does not know is the plain
  /// [generic] board, logged (a player is never thrown out mid-game for
  /// a role the server added).
  static NightPrompt fromKind(String kind) {
    final known = values.where((prompt) => prompt.kind == kind).firstOrNull;
    if (known != null) return known;
    logger.w('Unknown night prompt kind "$kind": showing the generic board');
    return generic;
  }
}
