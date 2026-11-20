import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';

// The one game the component sheet's pages show: five at the table, Classic
// for five (2 Werewolves, Seer, Robber, Troublemaker, Drunk, Insomniac,
// Villager). Every page is Ana's phone; only what her held faces say
// changes with her card (the Villager, or the Seer), the rest of every page
// being the same for any card. Dev dies holding a Werewolf card (he was
// dealt another: Esme the Troublemaker swapped it to him), and the village
// wins.

const ana = NightSeat(id: 1, name: 'Ana', token: TokenId.crow);
const ben = NightSeat(id: 2, name: 'Ben', token: TokenId.key);
const cleo = NightSeat(id: 3, name: 'Cleo', token: TokenId.moth);
const dev = NightSeat(id: 4, name: 'Dev', token: TokenId.bell);
const esme = NightSeat(id: 5, name: 'Esme', token: TokenId.thorn);

/// The table, in seat order.
const fiveSeats = [ana, ben, cleo, dev, esme];

/// Ten at the table, with a long name.
const tenSeats = [
  ...fiveSeats,
  NightSeat(id: 6, name: 'Florentyna-Bartholomew', token: TokenId.antler),
  NightSeat(id: 7, name: 'Gus', token: TokenId.hare),
  NightSeat(id: 8, name: 'Hal', token: TokenId.lantern),
  NightSeat(id: 9, name: 'Ida', token: TokenId.spindle),
  NightSeat(id: 10, name: 'Jo', token: TokenId.scythe),
];

/// Tonight's deck, as the strips and the builder count it.
const deckCounts = {
  RoleId.werewolf: 2,
  RoleId.seer: 1,
  RoleId.robber: 1,
  RoleId.troublemaker: 1,
  RoleId.drunk: 1,
  RoleId.insomniac: 1,
  RoleId.villager: 1,
};

/// The deck builder's order (S03).
const deckOrder = [
  RoleId.werewolf,
  RoleId.minion,
  RoleId.mason,
  RoleId.seer,
  RoleId.robber,
  RoleId.troublemaker,
  RoleId.drunk,
  RoleId.insomniac,
  RoleId.hunter,
  RoleId.tanner,
  RoleId.doppelganger,
  RoleId.villager,
];

/// Ana's card on a page: what her held faces say.
enum Viewer {
  villager(RoleId.villager, NightPrompt.noChoice, SleptResult()),
  seer(
    RoleId.seer,
    NightPrompt.seer,
    SeerPlayerResult(name: 'Cleo', role: RoleId.werewolf),
  );

  const Viewer(this.role, this.prompt, this.saw);

  final RoleId role;
  final NightPrompt prompt;
  final NightResult saw;

  FaceContent get card => FaceContent.roleText(role);
  FaceContent get you => FaceContent.nightYou(dealt: role, prompt: prompt);
  FaceContent get sawFace => FaceContent.saw(saw);
  FaceContent get myNight => FaceContent.myNight(dealt: role, saw: saw);
}
