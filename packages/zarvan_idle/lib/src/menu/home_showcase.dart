import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    as eng
    show
        AtlasRegistry,
        ShaderEffect,
        Sprite,
        SpriteAtlas,
        loadSpriteSheet,
        spawnWorldText;

import 'art_sizes.dart';

/// One slot of the home page's bottom bar: an icon from a 32 px strip, a label,
/// and an optional red dot (something new inside).
class HomeTab {
  const HomeTab({
    required this.id,
    required this.label,
    required this.iconsStem,
    required this.icon,
    this.badge = false,
    this.iconCell = 32,
  });

  /// Reaches the home config's `onAction` when the slot is tapped.
  final String id;
  final String label;

  /// A `<stem>.png` + `.json` strip (cell 32) and the frame in it.
  final String iconsStem;
  final int icon;
  final bool badge;

  /// Pixel size of one frame in the strip (more pixels draw sharper).
  final double iconCell;
}

/// A currency pill at the top of the home page: an icon and a value.
class HomeCounter {
  const HomeCounter({
    required this.iconsStem,
    required this.icon,
    required this.text,
    this.iconCell = 32,
  });

  final String iconsStem;
  final int icon;
  final String text;
  final double iconCell;
}

/// The art and texts of the emblem layout of the home page: a shader-drawn portal in
/// the gate, a title banner, a "continue" scroll, one wide play plate, a
/// bottom bar of tabs, currency pills and flickering torches. All images are
/// plain assets; the glow, breathing and flicker are drawn by the engine.
class HomeShowcase {
  const HomeShowcase({
    required this.bannerImage,
    required this.title,
    required this.scrollImage,
    required this.continueLabel,
    required this.plateImage,
    required this.playId,
    required this.playLabel,
    required this.tabBarImage,
    required this.tabs,
    this.portalX = 90,
    this.portalY = 184.5,
    this.portalWidth = 33,
    this.portalHeight = 83,
    this.portalImages = const [],
    this.portalGlow = 0.85,
    this.shine = 0.6,
    this.pillImage,
    this.counters = const [],
    this.torchStem,
    this.torchFrames = const [6, 7, 8],
    this.torchCell = 32,
    this.torchSize = 24,
    this.fontFamily,
  });

  /// The portal in the gate's doorway: an engine `ShaderEffect` (a spiral
  /// computed on the GPU, no art) centred at ([portalX], [portalY]),
  /// [portalWidth] x [portalHeight] world units. A height of 0 hides it.
  final double portalX;
  final double portalY;
  final double portalWidth;
  final double portalHeight;

  /// Up to two image paths (bottom layer first) shown blurred inside the
  /// portal: a picture of the level it leads to.
  final List<String> portalImages;

  /// How strongly the portal lights the stone around the door and the floor in
  /// front of it (additive glows tinted from [portalImages]); 0 turns it off.
  final double portalGlow;

  /// Strength of the light that sweeps across the play plate every few seconds
  /// and of the very soft glow behind the title banner; 0 turns both off.
  final double shine;

  /// Banner behind [title] (drawn 140 wide).
  final String bannerImage;
  final String title;

  /// Parchment under [continueLabel]; empty label hides both.
  final String scrollImage;
  final String continueLabel;

  /// The wide button: reports [playId] when tapped.
  final String plateImage;
  final String playId;
  final String playLabel;

  /// 180 x 52 bar with four slots, and what goes in them (leading side first).
  final String tabBarImage;
  final List<HomeTab> tabs;

  /// Frame behind each of [counters] (trailing top corner).
  final String? pillImage;
  final List<HomeCounter> counters;

  /// Icon strip whose [torchFrames] are the flame frames of two side torches.
  final String? torchStem;
  final List<int> torchFrames;
  final double torchCell;

  /// How big the torches are drawn (world units).
  final double torchSize;

  /// A bundled display font for every text of the layer (null: the default).
  final String? fontFamily;
}

/// Builds and animates a [HomeShowcase] inside a home scene's world. Keeps the
/// scene itself small: it only asks for assets, spawns, ticks and hit-tests.
class HomeShowcaseLayer {
  HomeShowcaseLayer(this.show, {required this.rtl, required this.safeInset});

  final HomeShowcase show;
  final bool rtl;
  final double safeInset;

  static const _banner = 'hs_banner';
  static const _scroll = 'hs_scroll';
  static const _plate = 'hs_plate';
  static const _bar = 'hs_bar';
  static const _pill = 'hs_pill';
  static const _dot = 'hs_dot';
  static const _slotX = [0.167, 0.389, 0.611, 0.832];

  final _iconAtlas = <String, String>{};
  final _hits = <String, Rect>{};
  final _torches = <EntityId>[];
  EntityId? _plateE;
  double _t = 0;
  final _fit = ArtFitter();

  /// Asset path of the badge dot, set when assets load.
  String? dotPath;

  /// Where the play plate and the tab bar sit (world units).
  static const plateY = 246.0;
  static const _plateScale = 0.9;

  String _atlasOf(String stem) =>
      _iconAtlas.putIfAbsent(stem, () => 'hs_icons_${_iconAtlas.length}');

  /// Loads every image the layer draws into [r].
  Future<void> registerAssets(
    eng.AtlasRegistry r, {
    required String? dotImage,
  }) async {
    dotPath = dotImage;
    Future<eng.SpriteAtlas> full(String p) =>
        eng.SpriteAtlas.loadFullImageFromAssets(p);
    Future<void> add(String id, String path) async {
      final a = await full(path);
      artSizes[path] = Size(
        a.image.width.toDouble(),
        a.image.height.toDouble(),
      );
      r.register(id, a);
    }

    await add(_banner, show.bannerImage);
    await add(_scroll, show.scrollImage);
    await add(_plate, show.plateImage);
    for (var i = 0; i < show.portalImages.length && i < 2; i++) {
      await add('hs_portal_$i', show.portalImages[i]);
    }
    await add(_bar, show.tabBarImage);
    if (show.pillImage != null) await add(_pill, show.pillImage!);
    if (dotImage != null) await add(_dot, dotImage);
    final stems = {
      for (final t in show.tabs) t.iconsStem,
      for (final c in show.counters) c.iconsStem,
      ?show.torchStem,
    };
    for (final s in stems) {
      r.register(
        _atlasOf(s),
        (await eng.loadSpriteSheet(s, measurePivots: false)).atlas,
      );
    }
  }

  EntityId _sprite(
    World w,
    String atlas,
    String region,
    double x,
    double y,
    double scale,
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
        scaleX: scale,
        scaleY: scale,
        zIndex: z,
        tintArgb: tint,
      ),
    );
    return e;
  }

  /// A sprite drawn [width] world units wide whatever the art's pixel size.
  EntityId _art(
    World w,
    String atlas,
    String path,
    double x,
    double y,
    double width,
    double nominal,
    int z,
  ) {
    final e = _sprite(w, atlas, 'full', x, y, artFit(path, width, nominal), z);
    _fit.add(e, path, width, nominal);
    return e;
  }

  /// A `shine` over an image already drawn [width] wide at ([x], [y]), with the
  /// same shape; [ratio] is its width over height until the real size is
  /// known.
  void _shineOver(
    World w,
    String atlas,
    String path,
    double x,
    double y,
    double width,
    double ratio,
    double period,
  ) {
    final art = artSizes[path];
    final height = width / (art == null ? ratio : art.width / art.height);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(x, y));
    w.componentsOf<eng.ShaderEffect>().set(
      e,
      eng.ShaderEffect(
        kind: eng.ShaderEffect.shine,
        width: width,
        height: height,
        images: [atlas],
        intensity: show.shine,
        period: period,
        coreArgb: 0xFFFFF6D0,
        zIndex: 8,
      ),
    );
  }

  EntityId _text(
    World w,
    double x,
    double y,
    String text,
    double size,
    int color,
    int z, {
    double maxWidth = 100,
    int? shadow = 0xCC000000,
  }) => eng.spawnWorldText(
    w,
    x,
    y,
    text,
    fontSize: size,
    colorArgb: color,
    zIndex: z,
    maxWidth: maxWidth,
    rtl: rtl ? true : null,
    fontFamily: show.fontFamily,
    shadowArgb: shadow,
  );

  /// Spawns the whole layer into [world].
  void populate(World world) {
    final w = world.width.toDouble(), h = world.height.toDouble();
    double mx(double x) => rtl ? w - x : x;

    if (show.portalHeight > 0) {
      final images = [
        for (var i = 0; i < show.portalImages.length && i < 2; i++)
          'hs_portal_$i',
      ];
      void effect(
        double x,
        double y,
        double w,
        double h,
        String kind, {
        int z = 2,
        double intensity = 0.5,
      }) {
        final e = world.spawn();
        world.componentsOf<Position>().set(e, Position(x, y));
        world.componentsOf<eng.ShaderEffect>().set(
          e,
          eng.ShaderEffect(
            kind: kind,
            width: w,
            height: h,
            images: images,
            intensity: intensity,
            zIndex: z,
          ),
        );
      }

      // The light first, so the portal draws over its middle: a halo on the
      // stone around the door and a pool on the steps and floor.
      if (show.portalGlow > 0) {
        effect(
          show.portalX,
          show.portalY,
          show.portalWidth * 3.4,
          show.portalHeight * 1.7,
          eng.ShaderEffect.glow,
          z: 1,
          intensity: show.portalGlow,
        );
        effect(
          show.portalX,
          show.portalY + show.portalHeight / 2 + 12,
          show.portalWidth * 3.8,
          show.portalWidth * 1.1,
          eng.ShaderEffect.glow,
          z: 1,
          intensity: show.portalGlow * 1.1,
        );
      }
      effect(
        show.portalX,
        show.portalY,
        show.portalWidth,
        show.portalHeight,
        eng.ShaderEffect.portal,
      );
    }

    if (show.shine > 0) {
      // A very soft warm glow behind the title banner.
      final e = world.spawn();
      world.componentsOf<Position>().set(e, Position(w / 2, 46));
      world.componentsOf<eng.ShaderEffect>().set(
        e,
        eng.ShaderEffect(
          kind: eng.ShaderEffect.glow,
          width: 190,
          height: 70,
          intensity: show.shine * 0.28,
          coreArgb: 0xFFFFC53D,
          zIndex: 7,
        ),
      );
    }
    _art(world, _banner, show.bannerImage, w / 2, 46, 140, 156, 8);
    _text(world, w / 2, 46, show.title, 15, 0xFFFFE38A, 9, maxWidth: 80);

    if (show.pillImage != null) {
      for (var i = 0; i < show.counters.length; i++) {
        final c = show.counters[i];
        final cx = mx(w - safeInset - 20 - i * 44);
        final s = rtl ? -1.0 : 1.0;
        _art(world, _pill, show.pillImage!, cx, 14, 40, 44, 8);
        _sprite(
          world,
          _atlasOf(c.iconsStem),
          '${c.icon}',
          cx - 12 * s,
          14,
          12 / c.iconCell,
          9,
        );
        _text(world, cx + 5 * s, 14, c.text, 5.6, 0xFFFFE7A0, 9, maxWidth: 22);
      }
    }

    if (show.continueLabel.isNotEmpty) {
      _art(world, _scroll, show.scrollImage, w / 2, 212, 104, 112, 8);
      _text(
        world,
        w / 2,
        212,
        show.continueLabel,
        7,
        0xFF3A2410,
        9,
        shadow: null,
      );
    }

    _plateE = _art(
      world,
      _plate,
      show.plateImage,
      w / 2,
      plateY,
      124 * _plateScale,
      124,
      8,
    );
    if (show.shine > 0) {
      _shineOver(
        world,
        _plate,
        show.plateImage,
        w / 2,
        plateY,
        124 * _plateScale,
        124 / 32,
        6,
      );
    }
    _text(
      world,
      w / 2,
      plateY,
      show.playLabel,
      11,
      0xFFFFF3C7,
      9,
      maxWidth: 90,
    );
    _hits[show.playId] = Rect.fromCenter(
      center: Offset(w / 2, plateY),
      width: 124 * _plateScale,
      height: 32 * _plateScale,
    );

    // A dock as wide as the part of the screen every phone shows; its four
    // slots sit at fixed fractions of the art.
    final barW = w - 2 * safeInset;
    final barArt = artSizes[show.tabBarImage];
    final barH =
        barW * (barArt == null ? 163 / 560 : barArt.height / barArt.width);
    final barTop = h - 10 - barH;
    _art(
      world,
      _bar,
      show.tabBarImage,
      w / 2,
      barTop + barH / 2,
      barW,
      560,
      12,
    );
    for (var i = 0; i < show.tabs.length && i < _slotX.length; i++) {
      final t = show.tabs[i];
      final cx = mx(safeInset + _slotX[i] * barW);
      final cy = barTop + barH * 0.615;
      _sprite(
        world,
        _atlasOf(t.iconsStem),
        '${t.icon}',
        cx,
        cy,
        12.5 / t.iconCell,
        13,
      );
      _text(
        world,
        cx,
        barTop + barH + 4.2,
        t.label,
        4.3,
        0xFFFFE9B0,
        14,
        maxWidth: 34,
      );
      if (t.badge) {
        _art(world, _dot, dotPath ?? '', cx + 8, cy - 9, 6, 12, 15);
      }
      _hits[t.id] = Rect.fromCenter(
        center: Offset(cx, cy + 3),
        width: barW * 0.22,
        height: barH * 0.8,
      );
    }

    final stem = show.torchStem;
    if (stem != null && show.torchFrames.isNotEmpty) {
      for (final x in [25.0, w - 25]) {
        _torches.add(
          _sprite(
            world,
            _atlasOf(stem),
            '${show.torchFrames.first}',
            x,
            240,
            show.torchSize / show.torchCell,
            11,
          ),
        );
      }
    }
  }

  /// Breathes the plate and flickers torches (the portal animates itself).
  void update(double dt, World world) {
    _t += dt;
    _fit.apply(world);
    final spr = world.componentsOf<eng.Sprite>();
    final plate = _plateE;
    if (plate != null) {
      final k =
          artFit(show.plateImage, 124 * _plateScale, 124) *
          (1 + 0.015 * math.sin(_t * 2.2));
      final s = spr.get(plate);
      s?.scaleX = k;
      s?.scaleY = k;
    }
    final frames = show.torchFrames;
    for (var i = 0; i < _torches.length; i++) {
      final f = frames[((_t * 7).floor() + i * 2) % frames.length];
      spr.get(_torches[i])?.region = '$f';
    }
  }

  /// The id of the tab or plate under [p], or null.
  String? hit(Offset p) {
    for (final e in _hits.entries) {
      if (e.value.contains(p)) return e.key;
    }
    return null;
  }
}
