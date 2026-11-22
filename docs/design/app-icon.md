# The app icon and launch screen

What a phone or a browser shows before and around the game: the launcher icon, the
name under it, the launch screen, the task switcher, the browser tab and the
installed web app. All of it comes from one mark, cut from the existing art.

## The mark: the moon over the house

A square window onto the Join screen's own scene (`art/scenes/street-door.jpg`): the
full moon, the gable under it and its lit lantern. Its dark tones are pressed toward
the night ground so the bone moon reads first at 48 px, and the amber window is the
one warm point. Nothing is drawn by hand: every pixel is the original art, cropped,
toned within the palette and masked.

Tried and not shipped (still made by `just app-icon <dir>` for review):

- **The lantern token** (`art/tokens/lantern.jpg`): reads well, but it is one of the
  ten seat tokens, so the app would look like a player's badge.

## The files

`frontend/tool/app_icon.py` makes every one of them; `just app-icon` (from
`frontend/`) runs it. Deterministic: a second run changes no byte.

| Where | What |
|---|---|
| `android/.../mipmap-anydpi-v26/ic_launcher*.xml` | The adaptive icon (Android 8+): background colour `ic_launcher_background` (the night ground), foreground and monochrome layers. |
| `mipmap-<density>/ic_launcher_foreground.webp` | The 108 dp layer; the moon, the roof's peak and the lantern sit inside the 66 dp circle every mask keeps (round, squircle, square). |
| `mipmap-<density>/ic_launcher_monochrome.webp` | The themed icon (Android 13+): the moon's disc with the roof cut out of it and the lit window. |
| `mipmap-<density>/ic_launcher.webp`, `ic_launcher_round.webp` | Older launchers: the visible 72 dp at 48 dp, rounded or round. |
| `drawable-<density>/launch_mark.webp` | The launch mark: the safe circle, 192 dp. |
| `values/styles.xml`, `values-v31/styles.xml`, `drawable/launch_background.xml`, `drawable/splash_icon.xml` | The launch: the night ground and the mark, before Android 12 (a window background) and from 12 (the splash screen API), the same size and place, so nothing jumps; then the night ground until Flutter's first frame. No `values-night`: one look whatever the phone's dark mode. |
| `web/favicon.png`, `web/icons/Icon-{192,512}.png`, `Icon-maskable-*.png`, `apple-touch-icon.png` | The browser tab, the installed web app (maskable: the safe circle is the inner 80%) and iOS's home screen. |
| `web/icons/launch-mark.webp`, `web/index.html`, `web/flutter_bootstrap.js` | The page before Flutter paints: the night ground and the mark; removed on Flutter's first frame. |

The names: the launcher label, the manifest's `name` and `short_name`, the page
`<title>` and the task switcher (`MaterialApp.title`) are all "Midnight Village"
(`JoinCopy.title`). The application id stays `com.midnightvillage.midnight_village`, so a
new APK installs over the old one.

The status and navigation bars: transparent over every screen, their icons light on the
night ground and dark on paper (`lib/design_system/skin/system_bars.dart`, declared by
`ScreenFrame` and `SheetScaffold`).

`frontend/test/platform/launcher_resources_test.dart` checks it all without an Android
SDK: every XML well formed, every resource it names present in every density at its
size, the names, and the night colour the same in the skin, the Android colours, the
manifest and the page.

## Changing it

Change the mark (`MOON` in the script: the window's centre and size in the source's
pixels, the tone press, the monochrome cut), run `just app-icon`, and look at the result
on light and dark wallpapers under the three masks before committing. A new look
("skin") would bring its own mark.
