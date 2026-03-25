import 'package:midnight_village/design_system/models/role.dart';

abstract class ThemeAssets {
  String get themeId;
  String roleCardPath(RoleId role);
  String get cardBackPath;
}

class MidnightVillageAssets implements ThemeAssets {
  const MidnightVillageAssets();

  @override
  String get themeId => 'midnight-village';

  @override
  String roleCardPath(RoleId role) =>
      'assets/themes/midnight-village/roles/${role.name}.svg';

  @override
  String get cardBackPath => 'assets/themes/midnight-village/card-back.svg';
}
