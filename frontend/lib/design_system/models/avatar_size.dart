// OLD LOOK: delete when 02 Table and the game screens (04 to 11) are rebuilt
@Deprecated(
  'OLD LOOK: delete when 02 Table and the game screens (04 to 11) are rebuilt. Build screens from lib/design_system/primitives/ instead.',
)
library;

enum AvatarSize {
  small(32),
  medium(48),
  large(64);

  const AvatarSize(this.pixels);
  final double pixels;
}
