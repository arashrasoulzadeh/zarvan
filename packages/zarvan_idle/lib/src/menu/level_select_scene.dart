import 'dart:ui' show Offset, Rect, Size;

import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    as eng
    show
        AtlasRegistry,
        Scene,
        SceneController,
        Sprite,
        SpriteAtlas,
        Text,
        TextAlignment,
        loadSpriteSheet,
        panelFrameAtlas,
        spawnPanelFrame,
        spawnWorldText;

import '../platformer/hud/upgrade_bar.dart' show UpgradeBar;
import 'art_sizes.dart';
import 'menu_button.dart';
import 'menu_music.dart';

/// One zone of the level list: a card with a thumbnail, a name and a line
/// under it. [thumbImages] are stacked full-image layers (sky, then hills...).
class ZoneCard {
  const ZoneCard({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.thumbImages,
  });

  final String key;
  final String title;
  final String subtitle;
  final List<String> thumbImages;
}

/// Data of a [LevelSelectScene].
class LevelSelectConfig {
  const LevelSelectConfig({
    required this.backgroundImage,
    required this.buttonImage,
    required this.panelImage,
    required this.nodesStem,
    required this.zones,
    required this.unlocked,
    required this.onOpen,
    required this.onBack,
    this.titleBannerImage,
    this.washAlpha = 0x55,
    this.title = 'World map',
    this.backLabel = 'Back',
    this.rtl = false,
    this.enterLabel = 'Enter',
    this.lockedLabel = 'Locked',
    this.safeInset = 20,
    this.music,
  });

  final String backgroundImage;
  final String buttonImage;
  final String panelImage;

  /// Ribbon drawn behind the title; null draws the title on the map.
  final String? titleBannerImage;

  /// Opacity (0-255) of the dark wash over the map, so the art still shows.
  final int washAlpha;

  /// `ui_level_node` strip: 0 locked, 1 current, 2 cleared, 3 boss.
  final String nodesStem;
  final List<ZoneCard> zones;

  /// How many zones (from the first) the player may enter; read every time the
  /// page is drawn, so progress made in a battle shows when the list returns.
  final int Function() unlocked;

  /// Called with the tapped, unlocked zone.
  final void Function(ZoneCard zone, eng.SceneController scenes) onOpen;
  final void Function(eng.SceneController scenes) onBack;
  final String title;
  final String backLabel;
  final bool rtl;

  /// Label of the button under the focused zone when it can be entered.
  final String enterLabel;

  /// Label of that button while the focused zone is still locked.
  final String lockedLabel;

  /// Margin kept clear on both sides for the part a tall phone crops.
  final double safeInset;

  /// The menu theme, kept playing while this screen shows.
  final MenuMusic? music;
}

/// The world map as a carousel: the focused zone is one large framed card with
/// its name, stage range and a status mark, its neighbours peek in from the
/// sides, and a row of dots shows the position. Arrow buttons or a tap on a
/// neighbour move the focus (the row slides); "Enter" opens an unlocked zone,
/// and stays disabled on a locked one. Built from [LevelSelectConfig] only, so
/// any idle game can drive it.
class LevelSelectScene extends eng.Scene {
  LevelSelectScene(this.config) : _index = _startIndex(config);

  final LevelSelectConfig config;

  static const _bg = 'map_bg';
  static const _btn = 'map_btn';
  static const _panel = 'map_panel';
  static const _nodes = 'map_nodes';
  static const _banner = 'map_banner';
  static String _thumb(String zone, int layer) => 'map_t_${zone}_$layer';

  // Hero card geometry in world units (the world is 180 x 320).
  static const _frameW = 132.0, _frameH = 112.0;
  static const _artW = 120.0, _artH = 100.0;
  static const _centerY = 108.0;
  static const _sideScale = 0.72, _spacing = 100.0;
  static const _slideSpeed = 520.0;

  /// The current zone, so the map opens on where the player left off.
  static int _startIndex(LevelSelectConfig c) =>
      (c.unlocked() - 1).clamp(0, c.zones.isEmpty ? 0 : c.zones.length - 1);

  int _index;
  double _slide = 0;
  final _fit = ArtFitter();
  final _cardEntities = <EntityId>[];
  final _infoEntities = <EntityId>[];
  late MenuButton _prev, _next, _back, _enter;

  /// Where each visible card is, for taps: the zone index it stands for.
  final _cardRects = <Rect, int>{};

  @override
  bool get showOnScreenControls => false;

  @override
  double? get ambientBrightness => 1;

  /// The zone in focus; exposed so a game (and tests) can read where the
  /// carousel stands.
  int get focusedIndex => _index;

  @override
  Future<eng.AtlasRegistry> loadAssets() async {
    final r = eng.AtlasRegistry();
    Future<eng.SpriteAtlas> full(String p) =>
        eng.SpriteAtlas.loadFullImageFromAssets(p);
    final bg = await full(config.backgroundImage);
    artSizes[config.backgroundImage] = Size(
      bg.image.width.toDouble(),
      bg.image.height.toDouble(),
    );
    r.register(_bg, bg);
    r.register(_btn, UpgradeBar.atlasFor(await full(config.buttonImage)));
    r.register(_panel, eng.panelFrameAtlas(await full(config.panelImage), 24));
    if (config.titleBannerImage != null) {
      r.register(_banner, await full(config.titleBannerImage!));
    }
    r.register(
      _nodes,
      (await eng.loadSpriteSheet(config.nodesStem, measurePivots: false)).atlas,
    );
    for (final z in config.zones) {
      for (var i = 0; i < z.thumbImages.length; i++) {
        r.register(_thumb(z.key, i), await full(z.thumbImages[i]));
      }
    }
    return r;
  }

  @override
  Future<void> populate(
    World world,
    eng.SceneController scenes,
    GameState state,
  ) async {
    final w = world.width.toDouble(), h = world.height.toDouble();
    EntityId sprite(
      String a,
      String reg,
      double x,
      double y,
      double sx,
      double sy,
      int z, {
      int? tint,
    }) {
      final e = world.spawn();
      world.componentsOf<Position>().set(e, Position(x, y));
      world.componentsOf<eng.Sprite>().set(
        e,
        eng.Sprite(a, reg, scaleX: sx, scaleY: sy, zIndex: z, tintArgb: tint),
      );
      return e;
    }

    final bgE = sprite(_bg, 'full', w / 2, h / 2, w / 180, h / 320, 0);
    _fit.addStretch(bgE, config.backgroundImage, w, h, 180, 320);
    sprite(
      _panel,
      'f11',
      w / 2,
      h / 2,
      (w + 20) / 48,
      (h + 20) / 27,
      1,
      tint: config.washAlpha << 24,
    );
    if (config.titleBannerImage != null) {
      // 78x37 art, drawn 104 wide.
      sprite(_banner, 'full', w / 2, 19, 104 / 78, 104 / 78, 5);
    }
    eng.spawnWorldText(
      world,
      w / 2,
      19,
      config.title,
      fontSize: 9,
      colorArgb: 0xFFFFE38A,
      zIndex: 6,
      maxWidth: 140,
      rtl: config.rtl ? true : null,
    );
    const rowY = 250.0;
    _prev = MenuButton.spawn(
      world,
      atlasId: _btn,
      id: 'prev',
      label: config.rtl ? '›' : '‹',
      cx: config.rtl ? w - config.safeInset - 16 : config.safeInset + 16,
      cy: rowY,
      width: 34,
      fontSize: 9,
    );
    _next = MenuButton.spawn(
      world,
      atlasId: _btn,
      id: 'next',
      label: config.rtl ? '‹' : '›',
      cx: config.rtl ? config.safeInset + 16 : w - config.safeInset - 16,
      cy: rowY,
      width: 34,
      fontSize: 9,
    );
    _enter = MenuButton.spawn(
      world,
      atlasId: _btn,
      id: 'enter',
      label: config.enterLabel,
      cx: w / 2,
      cy: rowY,
      width: 64,
      style: 'primary',
      fontSize: 8,
      rtl: config.rtl,
    );
    _back = MenuButton.spawn(
      world,
      atlasId: _btn,
      id: 'back',
      label: config.backLabel,
      cx: w / 2,
      cy: h - 22,
      width: 60,
      fontSize: 7.5,
      rtl: config.rtl,
    );
    _build(world);
    config.music?.enter();
  }

  /// Horizontal centre of the card [offset] places from the focused one;
  /// mirrored in Persian, where "next" is on the left.
  double _cardX(double w, int offset) =>
      w / 2 + (config.rtl ? -offset : offset) * _spacing;

  /// Redraws the cards, dots and captions for [_index].
  void _build(World world, {int slideFrom = 0}) {
    for (final e in [..._cardEntities, ..._infoEntities]) {
      world.destroy(e);
    }
    _cardEntities.clear();
    _infoEntities.clear();
    _cardRects.clear();
    final unlocked = config.unlocked();
    final w = world.width.toDouble();
    for (var off = -2; off <= 2; off++) {
      final i = _index + off;
      if (i < 0 || i >= config.zones.length) continue;
      _spawnCard(world, w, i, off, locked: i >= unlocked, unlocked: unlocked);
    }
    // The row starts displaced by the move that just happened and eases home.
    _slide = slideFrom * _spacing;
    _shiftCards(world, _slide);

    final zone = config.zones[_index];
    final locked = _index >= unlocked;
    for (final (text, dy, size, color) in [
      (zone.title, 184.0, 8.5, locked ? 0xFF9A9078 : 0xFFFFE38A),
      (zone.subtitle, 198.0, 5.6, 0xFFD8C48A),
    ]) {
      _infoEntities.add(
        eng.spawnWorldText(
          world,
          w / 2,
          dy,
          text,
          fontSize: size,
          colorArgb: color,
          zIndex: 14,
          maxWidth: 150,
          rtl: config.rtl ? true : null,
          align: eng.TextAlignment.center,
        ),
      );
    }
    _spawnDots(world, w);
    _enter.setStyle(world, locked ? 'disabled' : 'primary');
    world.componentsOf<eng.Text>().get(_enter.text)?.text = locked
        ? config.lockedLabel
        : config.enterLabel;
    _prev.setStyle(world, _index > 0 ? 'secondary' : 'disabled');
    _next.setStyle(
      world,
      _index < config.zones.length - 1 ? 'secondary' : 'disabled',
    );
  }

  void _spawnCard(
    World world,
    double w,
    int i,
    int off, {
    required bool locked,
    required int unlocked,
  }) {
    final z = config.zones[i];
    final s = off == 0 ? 1.0 : _sideScale;
    final lift = off == 0 ? 10 : 0;
    final cx = _cardX(w, off), cy = _centerY;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: _frameW * s,
      height: _frameH * s,
    );
    if (off.abs() <= 1) _cardRects[rect] = i;
    for (final e in eng.spawnPanelFrame(
      world,
      atlasId: _panel,
      rect: rect,
      source: const Size(96, 75),
      inset: 24,
      corner: 7 * s,
      zIndex: 10 + lift,
    )) {
      world.componentsOf<eng.Sprite>().get(e)?.tintArgb = locked
          ? 0xCC0A0A14
          : 0xE0140A06;
      _cardEntities.add(e);
    }
    final dim = off == 0 ? null : 0xFF8A8A98;
    for (var l = 0; l < z.thumbImages.length; l++) {
      final e = world.spawn();
      world.componentsOf<Position>().set(e, Position(cx, cy));
      world.componentsOf<eng.Sprite>().set(
        e,
        eng.Sprite(
          _thumb(z.key, l),
          'full',
          scaleX: _artW * s / 480,
          scaleY: _artH * s / 320,
          zIndex: 12 + lift + l,
          tintArgb: locked ? 0xFF606070 : dim,
        ),
      );
      _cardEntities.add(e);
    }
    final node = locked ? '0' : (i == unlocked - 1 ? '1' : '2');
    final mark = world.spawn();
    world.componentsOf<Position>().set(
      mark,
      Position(
        cx + (config.rtl ? -1 : 1) * (_frameW / 2 - 12) * s,
        cy - (_frameH / 2 - 12) * s,
      ),
    );
    world.componentsOf<eng.Sprite>().set(
      mark,
      eng.Sprite(
        _nodes,
        node,
        scaleX: 14 * s / 32,
        scaleY: 14 * s / 32,
        zIndex: 20 + lift,
      ),
    );
    _cardEntities.add(mark);
  }

  /// One square per zone under the captions; the focused one is wider and gold.
  void _spawnDots(World world, double w) {
    const dot = 4.0, gap = 4.0, wide = 9.0;
    final n = config.zones.length;
    final total = (n - 1) * (dot + gap) + wide;
    var x = w / 2 - total / 2;
    for (var i = 0; i < n; i++) {
      final width = i == _index ? wide : dot;
      final cx = x + width / 2;
      x += width + gap;
      final e = world.spawn();
      // Mirrored in Persian: the first zone is the rightmost dot.
      world.componentsOf<Position>().set(
        e,
        Position(config.rtl ? w - cx : cx, 214),
      );
      world.componentsOf<eng.Sprite>().set(
        e,
        eng.Sprite(
          _panel,
          'f11',
          scaleX: width / 48,
          scaleY: dot / 27,
          zIndex: 14,
          tintArgb: i == _index ? 0xFFFFE38A : 0xFF6A5A40,
        ),
      );
      _infoEntities.add(e);
    }
  }

  void _shiftCards(World world, double dx) {
    if (dx == 0) return;
    final pos = world.componentsOf<Position>();
    for (final e in _cardEntities) {
      final p = pos.get(e);
      if (p != null) p.x += dx;
    }
  }

  /// Moves the focus to [i] (clamped) and slides the row in from that side.
  void _focus(World world, int i) {
    final to = i.clamp(0, config.zones.length - 1);
    if (to == _index) return;
    final dir = to > _index ? 1 : -1;
    _index = to;
    _build(world, slideFrom: config.rtl ? -dir : dir);
  }

  @override
  void update(double dt, World world) {
    _fit.apply(world);
    if (_slide == 0) return;
    final step = _slideSpeed * dt;
    final next = _slide.abs() <= step ? 0.0 : _slide - step * _slide.sign;
    _shiftCards(world, next - _slide);
    _slide = next;
  }

  @override
  void handleTap(
    World world,
    eng.SceneController scenes,
    Offset worldPosition,
  ) {
    if (_back.rect.contains(worldPosition)) return config.onBack(scenes);
    if (_prev.rect.contains(worldPosition)) return _focus(world, _index - 1);
    if (_next.rect.contains(worldPosition)) return _focus(world, _index + 1);
    if (_enter.rect.contains(worldPosition)) {
      if (_index < config.unlocked()) {
        config.onOpen(config.zones[_index], scenes);
      }
      return;
    }
    // The focused card overlaps its neighbours' edges and wins the tap.
    for (final e in _cardRects.entries) {
      if (e.value != _index || !e.key.contains(worldPosition)) continue;
      if (_index < config.unlocked()) {
        config.onOpen(config.zones[_index], scenes);
      }
      return;
    }
    for (final e in _cardRects.entries) {
      if (e.key.contains(worldPosition)) return _focus(world, e.value);
    }
  }
}
