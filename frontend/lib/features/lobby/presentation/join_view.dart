part of 'join_screen.dart';

// 01's view (`JoinView`): what is drawn and typed, with no providers. Part of
// join_screen.dart, which holds the screen that feeds it.

/// 01 drawn from plain values (the component sheet and the gallery draw it
/// too): [name] to start the field with, the link's [code], the numbers
/// under it, what is on its way ([busy]) and the last [banner].
class JoinView extends StatefulWidget {
  const JoinView({
    super.key,
    this.name = '',
    this.code,
    this.online,
    this.lastWon,
    this.busy,
    this.seated = false,
    this.banner,
    this.bannerAction,
    this.onBannerAction,
    this.openCode = false,
    this.draft,
    this.onDraft,
    this.scanner,
    this.scanning = false,
    this.scanned,
    this.onScanOpen,
    this.onScanClose,
    this.onScanLeft,
    this.onScanned,
    this.onGetApp,
    required this.onStart,
    required this.onJoin,
    this.onEdited,
    this.dress = defaultDress,
  });

  /// 01 is dressed in paper; [dress] is for a preview or a test.
  static const defaultDress = Dress.paper;
  final Dress dress;

  /// Which way in is the amber plaque: Join once the code field holds a
  /// whole code ([codeOpen] and [code]) or 01 is a table's [link], else
  /// Start a table. Exactly one at any moment.
  static JoinPlaque plaqueOf({
    required String? link,
    required bool codeOpen,
    required String code,
  }) => link != null || (codeOpen && code.length == codeLength)
      ? JoinPlaque.join
      : JoinPlaque.start;

  final String name;
  final String? code;

  /// Players at tables right now; null while unknown.
  final int? online;

  /// How this player's last game went; null with none.
  final bool? lastWon;

  final JoinWay? busy;
  final String? banner;

  /// The banner's button ("Try again", "Go there"), when it has one.
  final String? bannerAction;
  final VoidCallback? onBannerAction;

  /// The player sits at another table: the link's "Join" is not offered.
  final bool seated;

  /// Starts with "Join a table" opened (the gallery's state).
  final bool openCode;

  /// What the form held when this 01 was built (the one before it, when a
  /// way in made the app build it again), and where it keeps what is typed.
  final JoinDraft? draft;
  final ValueChanged<JoinDraft>? onDraft;

  /// Makes the camera the scan action opens; null: no scan action.
  final CodeScannerFactory? scanner;

  /// The scanner (01b) is open, with the code it read once it has one. Kept
  /// by the caller, which may build 01 again (the page reloaded).
  final bool scanning;
  final String? scanned;
  final VoidCallback? onScanOpen;
  final VoidCallback? onScanClose;

  /// This 01 is gone while the scanner was open.
  final VoidCallback? onScanLeft;
  final ValueChanged<String>? onScanned;

  /// "Get the app" at the foot: given only where the app can be downloaded
  /// (a page in an Android browser); null: no link.
  final VoidCallback? onGetApp;

  final ValueChanged<String> onStart;
  final void Function(String name, String code) onJoin;
  final VoidCallback? onEdited;

  /// The server's names: letters, digits and single spaces, 20 at most.
  static const nameLength = 20;

  /// The server's table codes: six letters and digits.
  static const codeLength = 6;

  /// The least width the code row has for the scan glyph beside the code: the
  /// code field keeps room for all six characters and the caret.
  static const scanBesideCodeFrom = 300.0;

  @override
  State<JoinView> createState() => _JoinViewState();
}

class _JoinViewState extends State<JoinView> {
  late final _name = TextEditingController(
    text: widget.draft?.name ?? widget.name,
  );
  late final _code = TextEditingController(text: widget.draft?.code);
  late var _codeOpen = widget.openCode || (widget.draft?.codeOpen ?? false);
  final _nameFocus = FocusNode();

  /// The code field was filled by a scan: it takes no focus.
  var _scannedIn = false;

  /// The scanner is on screen: asked for, and 01 is not a table's link.
  bool get _scanShown => widget.scanning && widget.code == null;

  @override
  void initState() {
    super.initState();
    // A scanner left open by a screen that is gone is not this one's to show:
    // only a tap starts the camera.
    if (widget.scanning && widget.scanned == null && widget.code != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onScanClose?.call(),
      );
    }
    _name.addListener(_changed);
    _code.addListener(_changed);
  }

  /// What was typed when [_changed] last ran: a controller tells of a moved
  /// cursor or selection too (a field gaining focus selects), which is no
  /// edit and must not clear the banner of a refusal.
  late var _typed = (_name.text, _code.text);

  void _changed() {
    final typed = (_name.text, _code.text);
    if (typed == _typed) return;
    _typed = typed;
    widget.onEdited?.call();
    _keep();
    setState(() {});
  }

  void _open(bool open) {
    setState(() => _codeOpen = open);
    _keep();
  }

  void _keep() => widget.onDraft?.call(
    JoinDraft(name: _name.text, code: _code.text, codeOpen: _codeOpen),
  );

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _codeFocus.dispose();
    _nameFocus.dispose();
    // The scanner belongs to this 01 and the tap that opened it: leaving 01
    // (to a table, to a link) ends it, unless a join it started is on its way.
    // Otherwise the camera would start by itself on the next 01.
    if (widget.scanning) {
      final left = widget.onScanLeft;
      Future.microtask(() => left?.call());
    }
    super.dispose();
  }

  /// The scanner read a table's code. With a name typed, the join goes at
  /// once (the same path as Join) while the scanner shows the code; without
  /// one, 01 is back with the code in its field and the name field asking.
  void _scanned(String code) {
    if (_named && widget.busy == null && !widget.seated) {
      // The code goes in its field too, so a refused join leaves it there
      // (no focus taken: the phone's keyboard stays down).
      _scannedIn = true;
      _code.text = code;
      _open(true);
      widget.onScanned?.call(code);
      widget.onJoin(_typedName, code);
    } else {
      _code.text = code;
      _open(true);
      widget.onScanClose?.call();
      if (!_named) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _nameFocus.requestFocus(),
        );
      }
    }
  }

  /// "Type the code": the camera cannot be used.
  void _typeInstead() {
    _open(true);
    widget.onScanClose?.call();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _codeFocus.requestFocus(),
    );
  }

  final _codeFocus = FocusNode();

  /// Enter in the name field does what the screen offers first: from a link,
  /// Join; else the way to join (a guest's first step, never a table of
  /// their own by accident): the code field opens, or with a code typed,
  /// Join.
  void _nameEntered(String? link) {
    if (!_named || widget.busy != null || widget.seated) return;
    if (link != null) {
      widget.onJoin(_typedName, link);
    } else if (_codeOpen && _coded) {
      widget.onJoin(_typedName, _code.text);
    } else {
      _open(true);
      _codeFocus.requestFocus();
    }
  }

  final _nameNudge = GlobalKey<NudgeState>();

  /// A tap on what needs a name before there is one: the cursor goes to the
  /// name field and it is nudged, so the button never looks dead.
  void _needName() {
    _nameFocus.requestFocus();
    _nameNudge.currentState?.nudge();
  }

  String get _typedName => _name.text.trim();
  bool get _named => _typedName.isNotEmpty;
  bool get _coded => _code.text.length == JoinView.codeLength;

  /// Which way in is the amber plaque now (one at any moment).
  JoinPlaque get _plaque => JoinView.plaqueOf(
    link: widget.code,
    codeOpen: _codeOpen,
    code: _code.text,
  );

  @override
  Widget build(BuildContext context) => DressScope(
    dress: widget.dress,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    final busy = widget.busy;
    final idle = busy == null;
    final link = widget.code;
    final plaque = _plaque;

    final banner = widget.banner;
    final make = widget.scanner;
    final scan = make == null || link != null
        ? null
        : GlyphButton(
            glyph: (ink) => ScanGlyph(color: ink),
            semanticLabel: ScanCopy.scan,
            onPressed: idle && !widget.seated ? widget.onScanOpen : null,
            size: _codeOpen ? ButtonSize.compact : ButtonSize.large,
          );
    // Back closes the scanner, then the code field ("Join a table" again).
    return BackHandler(
      open: _codeOpen && link == null && !_scanShown,
      onBack: () => _open(false),
      child: _scanShown && make != null
          ? BackHandler(
              onBack: widget.onScanClose ?? () {},
              child: ScanView(
                makeScanner: make,
                code: widget.scanned,
                onCode: _scanned,
                onBack: widget.onScanClose ?? () {},
                onType: _typeInstead,
                joining: busy == JoinWay.join,
              ),
            )
          : ScreenFrame(
              ground: GroundKind.night,
              // Its one light is the lantern by the door in the picture.
              mood: MoodKind.lantern,
              topArt: skin.art.streetDoor,
              // The village takes the height the form leaves: the form sits
              // low, under the thumb, on the picture's foreground.
              topArtLayout: TopArtLayout.fill,
              // The numbers and "Get the app" are quiet lines: on a short
              // phone or above the keyboard they follow the form (reached by
              // scrolling) rather than take the room its buttons need.
              actionsFollow: true,
              body: Builder(
                builder: (context) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: Space.lgPlus,
                  children: [
                    Semantics(
                      header: true,
                      child: FitLine(JoinCopy.title, style: type.heroTitle),
                    ),
                    // The one light is the mood's lantern (the lit door in
                    // the picture): no second pool round the name.
                    Nudge(
                      key: _nameNudge,
                      child: SkinField.paper(
                        controller: _name,
                        focusNode: _nameFocus,
                        hint: JoinCopy.nameHint,
                        semanticLabel: JoinCopy.nameHint,
                        autofocus: widget.name.isEmpty,
                        maxLength: JoinView.nameLength,
                        inputFormatters: [_NameFormatter()],
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _nameEntered(link),
                      ),
                    ),
                    // A refusal stays where the eye is: between the name and
                    // the code.
                    if (banner != null)
                      Notice(
                        message: banner,
                        action: widget.onBannerAction == null
                            ? null
                            : widget.bannerAction,
                        onAction: widget.onBannerAction,
                      ),
                    if (link != null && widget.seated)
                      const SizedBox.shrink()
                    else if (link != null)
                      _join(
                        plaque: plaque,
                        code: link,
                        size: ButtonSize.large,
                        busy: busy,
                      )
                    else ...[
                      if (_codeOpen)
                        LayoutBuilder(
                          builder: (context, room) => Row(
                            spacing: Space.smPlus,
                            children: [
                              Expanded(
                                child: SkinField.code(
                                  controller: _code,
                                  focusNode: _codeFocus,
                                  hint: JoinCopy.codeHint,
                                  semanticLabel: JoinCopy.codeHint,
                                  autofocus: _named && !_scannedIn,
                                  maxLength: JoinView.codeLength,
                                  inputFormatters: [_CodeFormatter()],
                                  textInputAction: TextInputAction.go,
                                  onSubmitted: (_) {
                                    if (_plaque == JoinPlaque.join &&
                                        _named &&
                                        widget.busy == null) {
                                      widget.onJoin(_typedName, _code.text);
                                    }
                                  },
                                ),
                              ),
                              // Only where the code keeps its room (the
                              // narrowest phones show the whole code, and
                              // scan is one Back away).
                              if (room.maxWidth >= JoinView.scanBesideCodeFrom)
                                ?scan,
                              _join(
                                plaque: plaque,
                                code: _coded ? _code.text : null,
                                size: ButtonSize.compact,
                                busy: busy,
                              ),
                            ],
                          ),
                        )
                      else
                        Row(
                          spacing: Space.smPlus,
                          children: [
                            Expanded(
                              child: _scrap(
                                label: JoinCopy.joinTable,
                                busy: busy,
                                own: null,
                                act: () => _open(true),
                              ),
                            ),
                            ?scan,
                          ],
                        ),
                      _start(plaque: plaque, busy: busy),
                    ],
                  ],
                ),
              ),
              actions: [
                if (_JoinFoot.shows(
                  online: widget.online,
                  lastWon: widget.lastWon,
                  link: link,
                  onGetApp: widget.onGetApp,
                ))
                  _JoinFoot(
                    online: widget.online,
                    lastWon: widget.lastWon,
                    link: link,
                    onGetApp: widget.onGetApp,
                  ),
              ],
            ),
    );
  }
}
