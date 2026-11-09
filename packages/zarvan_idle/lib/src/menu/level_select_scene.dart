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
import 'menu_button.dart';

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
    this.title = 'World map',
    this.backLabel = 'Back',
    this.rtl = false,
    this.perPage = 5,
    this.safeInset = 20,
  });

  final String backgroundImage;
  final String buttonImage;
  final String panelImage;

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
  final int perPage;

  /// Margin kept clear on both sides for the part a tall phone crops.
  final double safeInset;
}

/// The world map as a paged list of zone cards: thumbnail, name, stage range,
/// and a lock, a "current" marker or a "cleared" mark. Locked cards do nothing.
/// Built from [LevelSelectConfig] only, so any idle game can drive it.
class LevelSelectScene extends eng.Scene {
  LevelSelectScene(this.config);

  final LevelSelectConfig config;

  static const _bg = 'map_bg';
  static const _btn = 'map_btn';
  static const _panel = 'map_panel';
  static const _nodes = 'map_nodes';
  static String _thumb(String zone, int layer) => 'map_t_${zone}_$layer';

  int _page = 0;
  final _pageEntities = <EntityId>[];
  final _cardRects = <Rect, ZoneCard>{};
  late MenuButton _prev, _next, _back;
  late EntityId _pageLabel;

  int get _pages => (config.zones.length / config.perPage).ceil();

  @override
  bool get showOnScreenControls => false;

  @override
  double? get ambientBrightness => 1;

  @override
  Future<eng.AtlasRegistry> loadAssets() async {
    final r = eng.AtlasRegistry();
    Future<eng.SpriteAtlas> full(String p) =>
        eng.SpriteAtlas.loadFullImageFromAssets(p);
    r.register(_bg, await full(config.backgroundImage));
    r.register(_btn, UpgradeBar.atlasFor(await full(config.buttonImage)));
    r.register(_panel, eng.panelFrameAtlas(await full(config.panelImage), 24));
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
    void sprite(
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
    }

    sprite(_bg, 'full', w / 2, h / 2, w / 180, h / 320, 0);
    sprite(
      _panel,
      'f11',
      w / 2,
      h / 2,
      (w + 20) / 48,
      (h + 20) / 27,
      1,
      tint: 0x88000000,
    );
    eng.spawnWorldText(
      world,
      w / 2,
      17,
      config.title,
      fontSize: 9,
      colorArgb: 0xFFFFE38A,
      zIndex: 6,
      maxWidth: 140,
      rtl: config.rtl ? true : null,
    );
    final y = h - 22;
    _prev = MenuButton.spawn(
      world,
      atlasId: _btn,
      id: 'prev',
      label: config.rtl ? '›' : '‹',
      cx: config.safeInset + 16,
      cy: y,
      width: 34,
      fontSize: 9,
    );
    _next = MenuButton.spawn(
      world,
      atlasId: _btn,
      id: 'next',
      label: config.rtl ? '‹' : '›',
      cx: w - config.safeInset - 16,
      cy: y,
      width: 34,
      fontSize: 9,
    );
    _back = MenuButton.spawn(
      world,
      atlasId: _btn,
      id: 'back',
      label: config.backLabel,
      cx: w / 2,
      cy: y,
      width: 60,
      style: 'primary',
      fontSize: 7.5,
      rtl: config.rtl,
    );
    _pageLabel = eng.spawnWorldText(
      world,
      w / 2,
      y - 18,
      '',
      fontSize: 5.5,
      colorArgb: 0xFFD8C48A,
      zIndex: 6,
    );
    _buildPage(world);
  }

  void _buildPage(World world) {
    for (final e in _pageEntities) {
      world.destroy(e);
    }
    _pageEntities.clear();
    _cardRects.clear();
    final unlocked = config.unlocked();
    final w = world.width.toDouble();
    final left = config.safeInset, right = w - config.safeInset;
    const cardH = 40.0, step = 46.0;
    final from = _page * config.perPage;
    final to = (from + config.perPage).clamp(0, config.zones.length);
    double mx(double x, double width) => config.rtl ? w - x - width : x;
    for (var i = from; i < to; i++) {
      final z = config.zones[i];
      final top = 32 + (i - from) * step;
      final rect = Rect.fromLTWH(left, top, right - left, cardH);
      _cardRects[rect] = z;
      final locked = i >= unlocked;
      for (final e in eng.spawnPanelFrame(
        world,
        atlasId: _panel,
        rect: rect,
        source: const Size(96, 75),
        inset: 24,
        corner: 7,
        zIndex: 10,
      )) {
        world.componentsOf<eng.Sprite>().get(e)?.tintArgb = locked
            ? 0xCC0A0A14
            : 0xE0140A06;
        _pageEntities.add(e);
      }
      // Thumbnail on the leading side.
      const tw = 44.0, th = 29.0;
      final tx = mx(left + 4, tw);
      for (var l = 0; l < z.thumbImages.length; l++) {
        final e = world.spawn();
        world.componentsOf<Position>().set(
          e,
          Position(tx + tw / 2, top + cardH / 2),
        );
        world.componentsOf<eng.Sprite>().set(
          e,
          eng.Sprite(
            _thumb(z.key, l),
            'full',
            scaleX: tw / 480,
            scaleY: th / 320,
            zIndex: 12 + l,
            tintArgb: locked ? 0xFF606070 : null,
          ),
        );
        _pageEntities.add(e);
      }
      final textX = config.rtl ? tx - 5 : tx + tw + 5;
      final textW = right - left - tw - 34;
      final align = config.rtl
          ? eng.TextAlignment.right
          : eng.TextAlignment.left;
      for (final (text, dy, size, color) in [
        (z.title, 13.0, 7.5, locked ? 0xFF9A9078 : 0xFFFFE38A),
        (z.subtitle, 27.0, 5.2, 0xFFD8C48A),
      ]) {
        _pageEntities.add(
          eng.spawnWorldText(
            world,
            config.rtl ? textX - textW : textX,
            top + dy,
            text,
            fontSize: size.toDouble(),
            colorArgb: color,
            zIndex: 14,
            maxWidth: textW,
            rtl: config.rtl ? true : null,
            align: align,
          ),
        );
      }
      // Status mark on the trailing side: lock / current / cleared.
      final node = locked ? '0' : (i == unlocked - 1 ? '1' : '2');
      final nx = mx(right - 16, 12) + 6;
      final e = world.spawn();
      world.componentsOf<Position>().set(
        e,
        Position(config.rtl ? left + 16 : nx, top + cardH / 2),
      );
      world.componentsOf<eng.Sprite>().set(
        e,
        eng.Sprite(_nodes, node, scaleX: 12 / 32, scaleY: 12 / 32, zIndex: 14),
      );
      _pageEntities.add(e);
    }
    _prev.setStyle(world, _page > 0 ? 'secondary' : 'disabled');
    _next.setStyle(world, _page < _pages - 1 ? 'secondary' : 'disabled');
    world.componentsOf<eng.Text>().get(_pageLabel)?.text =
        '${_page + 1} / $_pages';
  }

  @override
  void handleTap(
    World world,
    eng.SceneController scenes,
    Offset worldPosition,
  ) {
    if (_back.rect.contains(worldPosition)) return config.onBack(scenes);
    if (_prev.rect.contains(worldPosition) && _page > 0) {
      _page--;
      return _buildPage(world);
    }
    if (_next.rect.contains(worldPosition) && _page < _pages - 1) {
      _page++;
      return _buildPage(world);
    }
    final unlocked = config.unlocked();
    for (final e in _cardRects.entries) {
      if (!e.key.contains(worldPosition)) continue;
      if (config.zones.indexOf(e.value) < unlocked) {
        config.onOpen(e.value, scenes);
      }
      return;
    }
  }
}
