import 'dart:ui' show Offset, Rect, Size;

import 'package:zarvan_core/zarvan_core.dart';
import '../rendering/sprite.dart';
import '../rendering/text.dart';
import 'world_text.dart';

/// One tab of the bottom navigation: [id] is what [ScreenChrome.hit] returns,
/// [icon] a frame of the icon strip (`WaveUiArt.iconsStem`).
class NavTab {
  const NavTab({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final int icon;
}

/// The frame around the fight: a currency bar and zone title across the top,
/// a dark dock behind the skill row, and a row of navigation tabs along the
/// bottom. World units on the 180x320 portrait world, authored for left to
/// right; [rtl] mirrors every block (sprites in the fight are not touched).
class ScreenChromeStyle {
  const ScreenChromeStyle({
    required this.tabs,
    this.rtl = false,
    this.inset = 5,
    this.topHeight = 20,
    this.navHeight = 28,
    this.dockTop = 228,
    this.dockBottom = 290,
    this.goldIcon = 0,
    this.gemIcon = 2,
  });

  final List<NavTab> tabs;

  /// Mirrors the layout for a right-to-left language.
  final bool rtl;

  /// Gap between the screen edge and the first block.
  final double inset;

  /// Height of the currency strip and of the tab bar.
  final double topHeight;
  final double navHeight;

  /// Vertical span of the dark panel behind the skills; equal values draw none.
  final double dockTop;
  final double dockBottom;

  /// Frames of the currency icon strip (`WaveUiArt.currencyIconsStem`).
  final int goldIcon;
  final int gemIcon;
}

/// The top currency bar, skill dock and bottom tab bar of a wave-combat
/// scene, built from ordinary sprite and text entities.
///
/// [sync] writes the numbers and title; [hit] maps a tap to the tab it
/// pressed; [setActive] moves the highlight. Everything sits above the fight
/// but below the popups, except the tab bar, which stays above the dialog's
/// dim veil so it can be used while a dialog is open.
class ScreenChrome {
  ScreenChrome._(
    this.style,
    this._world,
    this._gold,
    this._gems,
    this._title,
    this._highlight,
    this._tabRects,
  );

  /// Draw order of the top bar and dock, and of the tab bar.
  static const topZ = 112;
  static const navZ = 146;

  final ScreenChromeStyle style;
  final World _world;
  final EntityId _gold;
  final EntityId _gems;
  final EntityId _title;
  final EntityId _highlight;
  final List<Rect> _tabRects;
  int _active = -1;

  /// Spawns the chrome. [fillAtlasId] is an atlas whose region `f11` is a flat
  /// piece of [fillSize] pixels (the middle of the panel frame), stretched and
  /// tinted into every dark block; [iconAtlasId] holds the tab icons (square
  /// cells of [iconCell] pixels) and [currencyAtlasId] the coin and gem icons
  /// (cells of [currencyCell]). Either icon atlas may be null.
  factory ScreenChrome.spawn(
    World world, {
    required ScreenChromeStyle style,
    required String fillAtlasId,
    Size fillSize = const Size(48, 27),
    String? iconAtlasId,
    double iconCell = 32,
    String? currencyAtlasId,
    double currencyCell = 32,
  }) {
    final w = world.width.toDouble();
    final h = world.height.toDouble();
    double mx(double x, double width) => style.rtl ? w - x - width : x;

    void block(
      double x,
      double y,
      double width,
      double height,
      int argb,
      int z,
    ) {
      final e = world.spawn();
      world.componentsOf<Position>().set(
        e,
        Position(x + width / 2, y + height / 2),
      );
      world.componentsOf<Sprite>().set(
        e,
        Sprite(
          fillAtlasId,
          'f11',
          scaleX: width / fillSize.width,
          scaleY: height / fillSize.height,
          zIndex: z,
          tintArgb: argb,
        ),
      );
    }

    EntityId icon(
      String atlas,
      double cell,
      int frame,
      double x,
      double y,
      double size,
      int z,
    ) {
      final e = world.spawn();
      world.componentsOf<Position>().set(
        e,
        Position(x + size / 2, y + size / 2),
      );
      world.componentsOf<Sprite>().set(
        e,
        Sprite(
          atlas,
          '$frame',
          scaleX: size / cell,
          scaleY: size / cell,
          zIndex: z,
        ),
      );
      return e;
    }

    EntityId text(
      double x,
      double y,
      double width,
      double size,
      int color,
      int z, {
      required bool toTheRight,
    }) {
      // Left-to-right text starts at the block's left edge, mirrored text at
      // the right edge; `toTheRight` is the side the block grows towards.
      final align = toTheRight != style.rtl
          ? TextAlignment.left
          : TextAlignment.right;
      final edge = align == TextAlignment.left ? x : x + width;
      final id = spawnWorldText(
        world,
        edge,
        y,
        '',
        fontSize: size,
        colorArgb: color,
        zIndex: z,
        maxWidth: width,
        rtl: style.rtl ? true : null,
        align: align,
      );
      return id;
    }

    final top = style.topHeight;
    // A fading brown strip: opaque at the top edge, clear at the bottom.
    const steps = 5;
    for (var i = 0; i < steps; i++) {
      final alpha = (0xD0 * (1 - i / steps)).round();
      block(
        0,
        top * i / steps,
        w,
        top / steps,
        alpha << 24 | 0x2A140C,
        topZ - 2,
      );
    }

    if (style.dockBottom > style.dockTop) {
      final dh = style.dockBottom - style.dockTop;
      block(0, style.dockTop, w, dh, 0xCC1A0E08, topZ - 2);
      block(0, style.dockTop, w, 1.2, 0xFFB8893A, topZ - 1);
      block(0, style.dockBottom - 1.2, w, 1.2, 0xFFB8893A, topZ - 1);
    }

    final i = style.inset;
    final coinX = mx(i, 14);
    final gemX = mx(66, 14);
    if (currencyAtlasId != null) {
      icon(currencyAtlasId, currencyCell, style.goldIcon, coinX, 2.5, 14, topZ);
      icon(currencyAtlasId, currencyCell, style.gemIcon, gemX, 2.5, 14, topZ);
    }
    final gold = text(
      mx(i + 16, 44),
      5.5,
      44,
      8,
      0xFFFFE38A,
      topZ,
      toTheRight: true,
    );
    final gems = text(
      mx(68 + 14, 30),
      5.5,
      30,
      8,
      0xFF9FD4FF,
      topZ,
      toTheRight: true,
    );
    final title = text(
      mx(w - 78 - i, 78),
      5.5,
      78,
      6.6,
      0xFFF6E7B4,
      topZ,
      toTheRight: false,
    );

    // Tab bar: a dark strip with a gold rule on top.
    final navTop = h - style.navHeight;
    block(0, navTop, w, style.navHeight, 0xFA140A06, navZ - 2);
    block(0, navTop, w, 1.6, 0xFFB8893A, navZ - 1);
    final n = style.tabs.length;
    final slot = (w - 6) / n;
    final rects = <Rect>[];
    final labelSize = style.rtl ? 5.0 : 4.2;
    for (var t = 0; t < n; t++) {
      final x = mx(3 + t * slot, slot - 1);
      rects.add(Rect.fromLTWH(x, navTop, slot - 1, style.navHeight));
      if (iconAtlasId != null) {
        icon(
          iconAtlasId,
          iconCell,
          style.tabs[t].icon,
          x + (slot - 1 - 17) / 2,
          navTop + 2.5,
          17,
          navZ,
        );
      }
      final label = spawnWorldText(
        world,
        x + (slot - 1) / 2,
        navTop + style.navHeight - 5.5,
        style.tabs[t].label,
        fontSize: labelSize,
        colorArgb: 0xFFF6E7B4,
        zIndex: navZ,
        maxWidth: slot + 2,
        rtl: style.rtl ? true : null,
      );
      world.componentsOf<Text>().get(label)?.text = style.tabs[t].label;
    }
    // The active tab's lit square, moved by [setActive]; a gold frame and a
    // warm wash, as in the mockups.
    final highlight = world.spawn();
    world.componentsOf<Position>().set(highlight, Position(0, 0));
    world.componentsOf<Sprite>().set(
      highlight,
      Sprite(
        fillAtlasId,
        'f11',
        scaleX: (slot - 1) / fillSize.width,
        scaleY: (style.navHeight - 2) / fillSize.height,
        zIndex: navZ - 1,
        tintArgb: 0x80C0802C,
      ),
    );
    final chrome = ScreenChrome._(
      style,
      world,
      gold,
      gems,
      title,
      highlight,
      rects,
    );
    chrome.setActive(-1);
    return chrome;
  }

  /// The tab the highlight is on, or -1 when none is open.
  int get active => _active;

  /// Moves the highlight to tab [index]; -1 (or any out-of-range index below
  /// zero) hides it, as at game start when no tab page is open.
  void setActive(int index) {
    _active = index < 0 ? -1 : index.clamp(0, _tabRects.length - 1).toInt();
    final p = _position(_highlight);
    if (p == null) return;
    if (_active < 0) {
      p.y = -1000;
      return;
    }
    final r = _tabRects[_active];
    p
      ..x = r.center.dx
      ..y = r.top + r.height / 2 + 0.5;
  }

  Position? _position(EntityId e) => _world.componentsOf<Position>().get(e);

  /// Writes the gold and gem counts and the zone title.
  void sync({required String gold, required String gems, String? title}) {
    final texts = _world.componentsOf<Text>();
    texts.get(_gold)?.text = gold;
    texts.get(_gems)?.text = gems;
    if (title != null) texts.get(_title)?.text = title;
  }

  /// The id of the tab at [worldPosition], or null when the tap is not on the
  /// tab bar.
  String? hit(Offset worldPosition) {
    for (var i = 0; i < _tabRects.length; i++) {
      if (_tabRects[i].contains(worldPosition)) return style.tabs[i].id;
    }
    return null;
  }

  /// Index of the tab with [id], or -1.
  int indexOf(String id) => style.tabs.indexWhere((t) => t.id == id);
}
