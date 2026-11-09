import 'package:zarvan_flutter/zarvan_flutter.dart' show TextAlignment;

import 'status_badges.dart';

/// One label of the wave-combat HUD. All positions and sizes are world units
/// (the text scales with the window like the rest of the scene).
class HudTextStyle {
  const HudTextStyle({
    required this.x,
    required this.y,
    this.fontSize = 5,
    this.colorArgb = 0xFFFFFFFF,
    this.maxWidth = 80,
    this.rtl,
    this.align = TextAlignment.center,
  });

  /// Centre of the label, or its left/right edge for a non-centred [align].
  final double x;
  final double y;
  final double fontSize;
  final int colorArgb;
  final double maxWidth;

  /// Forces right-to-left layout (`Text.rtl`); null follows the locale.
  final bool? rtl;

  /// Horizontal alignment of the text about [x].
  final TextAlignment align;
}

/// One health bar of the wave-combat HUD (world units). With generated bar
/// art ([WaveUiArt.barsStem]) only [x], [y] and [width] matter; [height] and
/// [fillColorArgb] are for the plain-rectangle fallback.
class HudBarStyle {
  const HudBarStyle({
    required this.x,
    required this.y,
    this.width = 80,
    this.height = 6,
    required this.fillColorArgb,
    this.artHeight,
    this.fillArt,
  });

  /// Top-left corner.
  final double x;
  final double y;
  final double width;
  final double height;
  final int fillColorArgb;

  /// With bar art, stretches the frame to this height (world units) instead of
  /// keeping the sheet's aspect ratio; null keeps the aspect.
  final double? artHeight;

  /// With bar art, the fill sprite to use (`hp`, `xp` or `boss`); null picks
  /// the default for the bar (the enemy bar turns `boss` on the boss wave).
  final String? fillArt;
}

/// Where the wave-combat HUD sits (a 180x320 portrait world): the hero's bar
/// top-left, the enemy's top-right, a status label under the first and the
/// enemy's name under the second, and the enemy description centred. Replace
/// any part for another layout, size or palette.
class HudLayout {
  const HudLayout({
    this.status = const HudTextStyle(
      x: 45,
      y: 26.5,
      fontSize: 4.6,
      colorArgb: 0xFFFFE7A0,
    ),
    this.enemy = const HudTextStyle(
      x: 135,
      y: 26.5,
      fontSize: 4.6,
      colorArgb: 0xFFFFCCBC,
    ),
    this.description = const HudTextStyle(
      x: 90,
      y: 160,
      fontSize: 7.5,
      colorArgb: 0xFFFFF3D0,
      maxWidth: 124,
      rtl: true,
    ),
    this.heroBar = const HudBarStyle(x: 5, y: 3, fillColorArgb: 0xFF2AA198),
    this.enemyBar = const HudBarStyle(x: 95, y: 3, fillColorArgb: 0xFFE0304C),
    this.bossBarColorArgb = 0xFFE65100,
    this.ultBar,
    this.ultText,
    this.gearY = 74,
    this.enemyOverhead,
    this.statusBadges,
  });

  final HudTextStyle status;
  final HudTextStyle enemy;

  /// The enemy's description, typed in at the centre of the world by a
  /// `DialogueCaption` for as long as the enemy lives.
  final HudTextStyle description;
  final HudBarStyle heroBar;
  final HudBarStyle enemyBar;

  /// The hero's ultimate meter: a second bar under the hero's and a label
  /// ("ULT 60%") under that. Both null (the default) draw neither.
  final HudBarStyle? ultBar;
  final HudTextStyle? ultText;

  /// A small plain bar floating above every living enemy (only [HudBarStyle]'s
  /// `width`, `height` and `fillColorArgb` count; the position follows the
  /// enemy). When set it replaces the single [enemyBar] at the top.
  final HudBarStyle? enemyOverhead;

  /// When set, the hero's conditions (bleed, poison, stun) show as a column of
  /// small badges here instead of a text line over its head.
  final StatusBadgeStyle? statusBadges;

  /// Height of the worn-gear summary line.
  final double gearY;

  /// Fill of the enemy bar during the boss encounter (plain-bar fallback).
  final int bossBarColorArgb;
}
