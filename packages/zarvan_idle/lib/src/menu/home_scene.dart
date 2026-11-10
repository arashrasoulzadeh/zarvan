import 'dart:math' as math;
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
        Text,
        loadSpriteSheet,
        panelFrameAtlas,
        spawnWorldText;

import '../platformer/hud/upgrade_bar.dart' show UpgradeBar;
import 'art_sizes.dart';
import 'home_showcase.dart';
import 'menu_button.dart';
import 'menu_music.dart';

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

/// A round icon button in a top corner of the home page (settings, language...).
/// [icon] is the frame index in [HomeConfig.cornerIconsStem].
class HomeCorner {
  const HomeCorner({required this.id, required this.icon});

  /// Reaches [HomeConfig.onAction] (or opens the language dialog when it is
  /// [HomeConfig.settingsId]).
  final String id;
  final int icon;
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
    this.corners = const [],
    this.cornerFrameImage,
    this.cornerIconsStem,
    this.footerPlaqueImage,
    this.embersStem,
    this.safeInset = 20,
    this.showcase,
    this.badgeDotImage,
    this.music,
    this.musicLabel = 'Music',
    this.musicOnText = 'On',
    this.musicOffText = 'Off',
    this.musicFrameImage,
    this.musicFrameOffImage,
    this.musicIconsStem,
    this.musicIcon = 0,
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

  /// Round icon buttons in the top corners, first one on the leading side. Need
  /// [cornerFrameImage] (the round frame) and [cornerIconsStem] (an icon strip).
  final List<HomeCorner> corners;
  final String? cornerFrameImage;
  final String? cornerIconsStem;

  /// Plaque drawn behind [footer].
  final String? footerPlaqueImage;

  /// A `<stem>.png` + `.json` strip of glow dots that drift up the screen. Null
  /// keeps the page still.
  final String? embersStem;

  /// Margin kept clear on both sides for the part a tall phone crops.
  final double safeInset;

  /// The emblem layout: when set it replaces the logo, hero and button column
  /// (entries are ignored; the play plate and tabs report through [onAction]).
  final HomeShowcase? showcase;

  /// Red dot drawn on tabs with a badge.
  final String? badgeDotImage;

  /// The menu theme: played while this page shows, with a mute switch in the
  /// settings dialog worded `musicLabel: musicOnText / musicOffText`.
  final MenuMusic? music;
  final String musicLabel;
  final String musicOnText;
  final String musicOffText;

  /// The round frame of the music switch (on and off looks) and the icon strip
  /// and frame of its speaker; all null falls back to a plain menu button.
  final String? musicFrameImage;
  final String? musicFrameOffImage;
  final String? musicIconsStem;
  final int musicIcon;
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
  static const _frame = 'home_frame';
  static const _icons = 'home_icons';
  static const _plaque = 'home_plaque';
  static const _musicOn = 'home_music_on';
  static const _musicOff = 'home_music_off';
  static const _musicIcons = 'home_music_icons';
  static const _embers = 'home_embers';
  static const _emberCount = 16;
  static const _cornerSize = 20.0;
  static const _logoY = 38.0;

  final _cornerRects = <String, Rect>{};
  final _embersList = <_Ember>[];
  EntityId? _logoEntity;
  late final HomeShowcaseLayer? _layer = config.showcase == null
      ? null
      : HomeShowcaseLayer(
          config.showcase!,
          rtl: config.rtl,
          safeInset: config.safeInset,
        );
  double _time = 0;
  final _fit = ArtFitter();

  final _buttons = <MenuButton>[];
  final _langButtons = <MenuButton>[];
  MenuButton? _musicButton;
  Rect? _musicRect;
  EntityId? _musicFrameE, _musicIconE, _musicLabelE;
  eng.ModalDialog? _dialog;

  @override
  bool get showOnScreenControls => false;

  @override
  double? get ambientBrightness => 1;

  @override
  Future<eng.AtlasRegistry> loadAssets() async {
    final r = eng.AtlasRegistry();
    final bg = await eng.SpriteAtlas.loadFullImageFromAssets(
      config.backgroundImage,
    );
    artSizes[config.backgroundImage] = Size(
      bg.image.width.toDouble(),
      bg.image.height.toDouble(),
    );
    r.register(_bg, bg);
    if (config.showcase == null) {
      r.register(
        _logo,
        await eng.SpriteAtlas.loadFullImageFromAssets(config.logoImage),
      );
    }
    await _layer?.registerAssets(r, dotImage: config.badgeDotImage);
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
    if (config.cornerFrameImage != null && config.cornerIconsStem != null) {
      r.register(
        _frame,
        await eng.SpriteAtlas.loadFullImageFromAssets(config.cornerFrameImage!),
      );
      r.register(
        _icons,
        (await eng.loadSpriteSheet(
          config.cornerIconsStem!,
          measurePivots: false,
        )).atlas,
      );
    }
    if (config.musicFrameImage != null && config.musicIconsStem != null) {
      for (final entry in {
        _musicOn: config.musicFrameImage!,
        _musicOff: config.musicFrameOffImage ?? config.musicFrameImage!,
      }.entries) {
        final a = await eng.SpriteAtlas.loadFullImageFromAssets(entry.value);
        artSizes[entry.value] = Size(
          a.image.width.toDouble(),
          a.image.height.toDouble(),
        );
        r.register(entry.key, a);
      }
      r.register(
        _musicIcons,
        (await eng.loadSpriteSheet(
          config.musicIconsStem!,
          measurePivots: false,
        )).atlas,
      );
    }
    if (config.footerPlaqueImage != null) {
      final plaque = await eng.SpriteAtlas.loadFullImageFromAssets(
        config.footerPlaqueImage!,
      );
      artSizes[config.footerPlaqueImage!] = Size(
        plaque.image.width.toDouble(),
        plaque.image.height.toDouble(),
      );
      r.register(_plaque, plaque);
    }
    if (config.embersStem != null) {
      r.register(
        _embers,
        (await eng.loadSpriteSheet(
          config.embersStem!,
          measurePivots: false,
        )).atlas,
      );
    }
    final stem = config.heroStem;
    if (stem != null) {
      r.register(
        _hero,
        (await eng.loadSpriteSheet(stem, measurePivots: false)).atlas,
      );
    }
    return r;
  }

  EntityId _sprite(
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
    return e;
  }

  @override
  Future<void> populate(
    World world,
    eng.SceneController scenes,
    GameState state,
  ) async {
    final w = world.width.toDouble(), h = world.height.toDouble();
    final bgE = _sprite(world, _bg, 'full', w / 2, h / 2, w / 180, h / 320, 0);
    _fit.addStretch(bgE, config.backgroundImage, w, h, 180, 320);
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
      tint: config.showcase != null ? 0x1A000000 : 0x66000000,
    );
    final layer = _layer;
    if (layer != null) {
      layer.populate(world);
    } else {
      _populateClassic(world);
    }
    _buildCorners(world);
    if (config.embersStem != null) _buildEmbers(world);
    _buildFooter(world, h);
    if (config.languages.isNotEmpty || config.music != null) {
      _buildDialog(world);
    }
    config.music?.enter();
  }

  void _populateClassic(World world) {
    final w = world.width.toDouble();
    final ls = config.logoSize;
    _logoEntity = _sprite(
      world,
      _logo,
      'full',
      w / 2,
      _logoY,
      ls.width / 160,
      ls.width / 160,
      4,
    );
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
  }

  /// The offline-earnings line, on its plaque; above the torches when the
  /// emblem layout owns the bottom of the screen.
  void _buildFooter(World world, double h) {
    if (config.footer.isEmpty) return;
    final w = world.width.toDouble();
    final y = config.showcase != null ? 92.0 : 308.0;
    final plaqueW = config.showcase != null ? 84.0 : 120.0;
    if (config.footerPlaqueImage != null) {
      // Drawn 120 wide with the art's own aspect.
      final pe = _sprite(
        world,
        _plaque,
        'full',
        w / 2,
        y,
        120 / 47,
        120 / 47,
        5,
      );
      _fit.add(pe, config.footerPlaqueImage!, plaqueW, 47);
    }
    eng.spawnWorldText(
      world,
      w / 2,
      y,
      config.footer,
      fontSize: 5.6,
      colorArgb: 0xFF9FE08A,
      zIndex: 6,
      maxWidth: plaqueW - 20,
      rtl: config.rtl ? true : null,
    );
  }

  void _buildCorners(World world) {
    if (config.cornerFrameImage == null || config.cornerIconsStem == null) {
      return;
    }
    final w = world.width.toDouble();
    for (var i = 0; i < config.corners.length && i < 2; i++) {
      final c = config.corners[i];
      // The first button sits on the leading side, so Persian mirrors it.
      final leading = (i == 0) != config.rtl;
      final cx = leading
          ? config.safeInset + _cornerSize / 2
          : w - config.safeInset - _cornerSize / 2;
      const cy = 14.0;
      _sprite(
        world,
        _frame,
        'full',
        cx,
        cy,
        _cornerSize / 53,
        _cornerSize / 53,
        8,
      );
      _sprite(world, _icons, '${c.icon}', cx, cy, 11 / 32, 11 / 32, 9);
      _cornerRects[c.id] = Rect.fromCenter(
        center: Offset(cx, cy),
        width: _cornerSize,
        height: _cornerSize,
      );
    }
  }

  void _buildEmbers(World world) {
    final rnd = math.Random(7);
    final w = world.width.toDouble(), h = world.height.toDouble();
    for (var i = 0; i < _emberCount; i++) {
      final kind = rnd.nextInt(4);
      final e = _Ember(
        x: rnd.nextDouble() * w,
        y: rnd.nextDouble() * h,
        speed: 6 + rnd.nextDouble() * 10,
        sway: 3 + rnd.nextDouble() * 5,
        phase: rnd.nextDouble() * math.pi * 2,
        baseX: 0,
      )..baseX = rnd.nextDouble() * w;
      e.entity = _sprite(world, _embers, '$kind', e.baseX, e.y, 0.9, 0.9, 3);
      _embersList.add(e);
    }
  }

  void _buildDialog(World world) {
    final d = _dialog = eng.ModalDialog.spawn(
      world,
      rect: Rect.fromLTRB(30, 104, 150, config.music == null ? 200 : 214),
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
        cy: config.music == null ? 158 : 150,
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
    final music = config.music;
    if (music != null) {
      if (config.musicFrameImage != null && config.musicIconsStem != null) {
        _buildMusicSwitch(world, d, music);
      } else {
        final b = _musicButton = MenuButton.spawn(
          world,
          atlasId: _btn,
          id: 'music',
          label: _musicText(music),
          cx: 90,
          cy: 188,
          width: 60,
          style: music.muted ? 'secondary' : 'primary',
          fontSize: 6,
          rtl: config.rtl,
          zIndex: 160,
        );
        _musicRect = b.rect;
        d
          ..add(b.sprite)
          ..add(b.text);
      }
    }
  }

  /// A round speaker button and its label, a compact row for the dialog: the
  /// frame is pressed-in and the speaker dimmed while the music is off.
  void _buildMusicSwitch(World world, eng.ModalDialog d, MenuMusic music) {
    const size = 22.0, y = 188.0;
    final rtl = config.rtl;
    final bx = rtl ? 118.0 : 62.0;
    final tx = rtl ? 82.0 : 98.0;
    final frame = _sprite(
      world,
      music.muted ? _musicOff : _musicOn,
      'full',
      bx,
      y,
      size / 210,
      size / 210,
      160,
    );
    _fit.add(
      frame,
      music.muted
          ? (config.musicFrameOffImage ?? config.musicFrameImage!)
          : config.musicFrameImage!,
      size,
      210,
    );
    final icon = _sprite(
      world,
      _musicIcons,
      '${config.musicIcon}',
      bx,
      y,
      13 / 64,
      13 / 64,
      161,
      tint: music.muted ? 0x66FFFFFF : null,
    );
    final text = eng.spawnWorldText(
      world,
      tx,
      y,
      _musicText(music),
      fontSize: 6.5,
      colorArgb: 0xFFF6E7B4,
      zIndex: 161,
      maxWidth: 46,
      rtl: rtl ? true : null,
      fontFamily: config.showcase?.fontFamily,
    );
    _musicFrameE = frame;
    _musicIconE = icon;
    _musicLabelE = text;
    _musicRect = Rect.fromLTRB(40, y - 14, 140, y + 14);
    d
      ..add(frame)
      ..add(icon)
      ..add(text);
  }

  /// Shows the music switch's current state.
  void _refreshMusic(World world, MenuMusic music) {
    final sprites = world.componentsOf<eng.Sprite>();
    final texts = world.componentsOf<eng.Text>();
    final text = _musicLabelE;
    final label = _musicText(music);
    if (text != null) texts.get(text)?.text = label;
    final frame = _musicFrameE;
    if (frame != null) {
      sprites.get(frame)?.atlasId = music.muted ? _musicOff : _musicOn;
    }
    final icon = _musicIconE;
    if (icon != null) {
      sprites.get(icon)?.tintArgb = music.muted ? 0x66FFFFFF : null;
    }
    final b = _musicButton;
    if (b != null) {
      b.setStyle(world, music.muted ? 'secondary' : 'primary');
      texts.get(b.text)?.text = label;
    }
  }

  String _musicText(MenuMusic m) =>
      '${config.musicLabel}: ${m.muted ? config.musicOffText : config.musicOnText}';

  @override
  void update(double dt, World world) {
    _dialog?.update(dt);
    _layer?.update(dt, world);
    _fit.apply(world);
    _time += dt;
    final pos = world.componentsOf<Position>();
    // The logo floats a little, so the page is never frozen.
    final logo = _logoEntity;
    if (logo != null) {
      pos.get(logo)?.y = _logoY + math.sin(_time * 1.6) * 1.2;
    }
    final h = world.height.toDouble();
    for (final e in _embersList) {
      e.y -= e.speed * dt;
      if (e.y < -8) e.y = h + 8;
      final p = pos.get(e.entity);
      if (p == null) continue;
      p.x = e.baseX + math.sin(_time * 0.9 + e.phase) * e.sway;
      p.y = e.y;
    }
  }

  @override
  void handleTap(
    World world,
    eng.SceneController scenes,
    Offset worldPosition,
  ) {
    final d = _dialog;
    if (d != null && d.isOpen) {
      final music = config.music;
      final mr = _musicRect;
      if (music != null && mr != null && mr.contains(worldPosition)) {
        // `muted` flips at once; the audio call finishes in the background.
        music.toggle();
        _refreshMusic(world, music);
        return;
      }
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
    for (final c in _cornerRects.entries) {
      if (!c.value.contains(worldPosition)) continue;
      if (c.key == config.settingsId && d != null) {
        d.open();
      } else {
        config.onAction(c.key, scenes);
      }
      return;
    }
    final id = _layer?.hit(worldPosition);
    if (id != null) {
      if (id == config.settingsId && d != null) {
        d.open();
      } else {
        config.onAction(id, scenes);
      }
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

/// One drifting glow dot of the home page.
class _Ember {
  _Ember({
    required this.x,
    required this.y,
    required this.speed,
    required this.sway,
    required this.phase,
    required this.baseX,
  });

  double x;
  double y;
  double baseX;
  final double speed;
  final double sway;
  final double phase;
  late final EntityId entity;
}
