import 'template.dart';

export 'story_copy.dart';
part 'banner_copy.dart';
part 'card_copy.dart';
part 'common_copy.dart';
part 'deck_copy.dart';
part 'end_copy.dart';
part 'join_copy.dart';
part 'night_copy.dart';
part 'role_copy.dart';
part 'role_sheet_copy.dart';
part 'saw_copy.dart';
part 'scan_copy.dart';
part 'spoken_copy.dart';
part 'table_copy.dart';
part 'talk_copy.dart';
part 'vote_copy.dart';

// Every word a player reads, keyed by screen and state: the final copy of
// docs/specs/frontend/first-time-play.md, section 3. Nothing a player reads
// is written anywhere else (role names are the server's, in
// `models/role.dart`). `test/design_system/copy/copy_budget_test.dart`
// holds every line here to the spec's copy rules (section 1): word budgets
// per screen, headlines, buttons, sentences, the one question, the banned
// words, the banners. A `{gap}` is filled where the line is shown
// (`Template.fill`).
//
// Where this differs from the spec's text, the spec broke one of its own
// rules; each change is marked "Spec:" with the line it replaces.
//
// One file per screen's words (the parts above), so two pieces of work on two
// screens never edit the same file. A new group of words is a new part.
