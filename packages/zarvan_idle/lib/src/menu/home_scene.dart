import 'dart:ui' show Offset, Rect, Size;

import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    as eng
    show
        AtlasRegistry,
        ModalDialog,
        Scene,
        SceneController,
        Sprite,
        SpriteAtlas,
        loadSpriteSheet,
        panelFrameAtlas,
        spawnWorldText;

import '../platformer/hud/upgrade_bar.dart' show UpgradeBar;
import 'menu_button.dart';

/// One button of the home page; [id] reaches [HomeConfig.onAction].
class HomeEntry {
  const HomeEntry({
    required this.id,
    required this.label,
    this.primary = false,
  });

  final String id;
  final String label;

  /// The big blue call-to-action look.
  final bool primary;
}

/// A language the settings dialog offers.
class LanguageOption {
  const LanguageOption(this.code, this.label);

  final String code;
  final String label;
}

/// Everything a [HomeScene] shows, as data: the art, the buttons, the texts.
class HomeConfig {
  const HomeConfig({
    required this.backgroundImage,
    required this.logoImage,
    required this.buttonImage,
    required this.panelImage,
    required this.entries,
    required this.onAction,
    this.logoSize = const Size(140, 41),
    this.heroStem,
    this.heroHeight = 100,
    this.footer = '',
    this.rtl = false,
    this.settingsId = 'settings',
    this.languages = const [],
    this.activeLanguage = '',
    this.languageTitle = 'Language',
    this.onLanguage,
    this.buttonWidth = 100,
  });

  /// Full-screen background, and the title logo drawn over it.
  final String backgroundImage;
  final String logoImage;
  final Size logoSize;

  /// A `<stem>.png` + `.json` idle strip; its first frame stands in the middle.
  final String? heroStem;
  final double heroHeight;

  /// `ui_button_atlas.png` and `ui_panel_9slice.png`.
  final String buttonImage;
  final String panelImage;

  /// The buttons, top to bottom.
  final List<HomeEntry> entries;

  /// A line under the buttons (e.g. offline earnings).
  final String footer;
  final bool rtl;
  final double buttonWidth;

  /// Called with a tapped entry's id, except [settingsId] when [languages] is
  /// not empty: that one opens the language dialog.
  final void Function(String id, eng.SceneController scenes) onAction;
  final String settingsId;
  final List<LanguageOption> languages;
  final String activeLanguage;
  final String languageTitle;

  /// Called with the code of the language picked in the dialog.
  final void Function(String code, eng.SceneController scenes)? onLanguage;
}

/// The home page: background, logo, hero and a column of buttons, plus a
/// language dialog (an engine `ModalDialog`, so the page blurs and pauses
/// behind it). Pure data in, one callback out; the game decides where
/// "Play" goes.
class HomeScene extends eng.Scene {
  HomeScene(this.config);

  final HomeConfig config;

  static const _bg = 'home_bg';
  static const _logo = 'home_logo';
  static const _hero = 'home_hero';
  static const _btn = 'home_btn';
  static const _panel = 'home_panel';

  final _buttons = <MenuButton>[];
  final _langButtons = <MenuButton>[];
  eng.ModalDialog? _dialog;

  @override
  bool get showOnScreenControls => false;

  @override
  double? get ambientBrightness => 1;

  @override
  Future<eng.AtlasRegistry> loadAssets() async {
    final r = eng.AtlasRegistry();
    r.register(
      _bg,
      await eng.SpriteAtlas.loadFullImageFromAssets(config.backgroundImage),
    );
    r.register(
      _logo,
      await eng.SpriteAtlas.loadFullImageFromAssets(config.logoImage),
    );
    r.register(
      _btn,
      UpgradeBar.atlasFor(
        await eng.SpriteAtlas.loadFullImageFromAssets(config.buttonImage),
      ),
    );
    r.register(
      _panel,
      eng.panelFrameAtlas(
        await eng.SpriteAtlas.loadFullImageFromAssets(config.panelImage),
        24,
      ),
    );
    final stem = config.heroStem;
    if (stem != null) {
      r.register(
        _hero,
        (await eng.loadSpriteSheet(stem, measurePivots: false)).atlas,
      );
    }
    return r;
  }

  void _sprite(
    World w,
    String atlas,
    String region,
    double x,
    double y,
    double sx,
    double sy,
    int z, {
    int? tint,
  }) {
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(x, y));
    w.componentsOf<eng.Sprite>().set(
      e,
      eng.Sprite(
        atlas,
        region,
        scaleX: sx,
        scaleY: sy,
        zIndex: z,
        tintArgb: tint,
      ),
    );
  }

  @override
  Future<void> populate(
    World world,
    eng.SceneController scenes,
    GameState state,
  ) async {
    final w = world.width.toDouble(), h = world.height.toDouble();
    _sprite(world, _bg, 'full', w / 2, h / 2, w / 180, h / 320, 0);
    // A dark wash so the buttons read over the busy art.
    _sprite(
      world,
      _panel,
      'f11',
      w / 2,
      h / 2,
      (w + 20) / 48,
      (h + 20) / 27,
      1,
      tint: 0x66000000,
    );
    final ls = config.logoSize;
    _sprite(world, _logo, 'full', w / 2, 38, ls.width / 160, ls.width / 160, 4);
    if (config.heroStem != null) {
      final s = config.heroHeight / 128;
      _sprite(world, _hero, '0', w / 2, 118, s, s, 3);
    }
    var y = 182.0;
    for (final e in config.entries) {
      _buttons.add(
        MenuButton.spawn(
          world,
          atlasId: _btn,
          id: e.id,
          label: e.label,
          cx: w / 2,
          cy: y,
          width: config.buttonWidth,
          style: e.primary ? 'primary' : 'secondary',
          fontSize: 8.5,
          rtl: config.rtl,
        ),
      );
      y += 44;
    }
    if (config.footer.isNotEmpty) {
      eng.spawnWorldText(
        world,
        w / 2,
        308,
        config.footer,
        fontSize: 6.5,
        colorArgb: 0xFF9FE08A,
        zIndex: 6,
        maxWidth: 150,
        rtl: config.rtl ? true : null,
      );
    }
    if (config.languages.isNotEmpty) _buildDialog(world);
  }

  void _buildDialog(World world) {
    final d = _dialog = eng.ModalDialog.spawn(
      world,
      rect: const Rect.fromLTRB(30, 110, 150, 200),
      z: 150,
      frameAtlasId: _panel,
      title: config.languageTitle,
      rtl: config.rtl,
    );
    final n = config.languages.length;
    for (var i = 0; i < n; i++) {
      final l = config.languages[i];
      final cx = 90 + (i - (n - 1) / 2) * 50;
      final b = MenuButton.spawn(
        world,
        atlasId: _btn,
        id: l.code,
        label: l.label,
        cx: cx,
        cy: 158,
        width: 46,
        style: l.code == config.activeLanguage ? 'primary' : 'secondary',
        fontSize: 6.5,
        zIndex: 160,
      );
      _langButtons.add(b);
      d
        ..add(b.sprite)
        ..add(b.text);
    }
  }

  @override
  void update(double dt, World world) => _dialog?.update(dt);

  @override
  void handleTap(
    World world,
    eng.SceneController scenes,
    Offset worldPosition,
  ) {
    final d = _dialog;
    if (d != null && d.isOpen) {
      for (final b in _langButtons) {
        if (b.rect.contains(worldPosition)) {
          config.onLanguage?.call(b.id, scenes);
          d.close();
          return;
        }
      }
      if (d.closesOn(worldPosition)) d.close();
      return;
    }
    for (final b in _buttons) {
      if (!b.rect.contains(worldPosition)) continue;
      if (b.id == config.settingsId && d != null) {
        d.open();
      } else {
        config.onAction(b.id, scenes);
      }
      return;
    }
  }
}
