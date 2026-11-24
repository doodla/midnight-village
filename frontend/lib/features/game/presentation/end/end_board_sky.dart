part of 'end_board_view.dart';

/// The square at dawn above the board: the sky plate under a dusk (the
/// skin's), then the gallows and the roofs, so the banner is the bright thing.
class _DawnSky extends StatelessWidget {
  const _DawnSky();

  @override
  Widget build(BuildContext context) => LayeredArt(
    LayeredSceneId.dawnGallows,
    travel: false,
    slots: {
      'sun': (context, geometry, slot, arrival) {
        final parts = context.skin.parts;
        final dusk = IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: parts.duskReach,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: parts.duskTint,
                    stops: parts.duskStops,
                  ),
                ),
              ),
            ),
          ),
        );
        // At night the moon is up behind the hills and the roofs.
        return Stack(
          children: [
            Positioned.fill(child: dusk),
            const Positioned.fill(child: NightMoon()),
          ],
        );
      },
    },
  );
}

/// The banner: the result by day ([day]); while the night plays, the step's
/// line, read out as each step comes and a screen reader's way on. Bone at
/// night: red is the result's (the Werewolf team won).
class _NightBanner extends StatelessWidget {
  const _NightBanner({required this.day});

  final Widget day;

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    if (night == null || !night.on) return day;
    return Semantics(
      liveRegion: true,
      button: true,
      label: night.line,
      onTap: night.next,
      excludeSemantics: true,
      child: BannerSlice.sentences(forms: [night.line]),
    );
  }
}
