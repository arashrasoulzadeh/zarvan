import 'dart:ui' show Offset, Rect;

import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    as eng
    show Sprite, Text, spawnWorldText;

import '../platformer/hud/upgrade_bar.dart' show ButtonSheet;

/// A button of a menu scene: a `ui_button_atlas` sprite (uniformly scaled, so
/// its ornaments are never stretched) with a centred label. [rect] is its
/// tap area. Restyle it with [setStyle] (`primary`, `secondary`, `disabled`).
class MenuButton {
  MenuButton.spawn(
    World world, {
    required this.atlasId,
    required this.id,
    required String label,
    required double cx,
    required double cy,
    required double width,
    String style = 'secondary',
    double fontSize = 8,
    int zIndex = 20,
    bool rtl = false,
  }) {
    final scale = width / ButtonSheet.cellWidth;
    final height = ButtonSheet.cellHeight * scale;
    rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: width,
      height: height,
    );
    sprite = world.spawn();
    world.componentsOf<Position>().set(sprite, Position(cx, cy));
    world.componentsOf<eng.Sprite>().set(
      sprite,
      eng.Sprite(atlasId, style, scaleX: scale, scaleY: scale, zIndex: zIndex),
    );
    text = eng.spawnWorldText(
      world,
      cx,
      cy,
      label,
      fontSize: fontSize,
      colorArgb: _textColorFor(style),
      zIndex: zIndex + 1,
      maxWidth: width * 0.8,
      rtl: rtl ? true : null,
    );
  }

  final String atlasId;

  /// What a game recognises the button by.
  final String id;
  late final Rect rect;
  late final EntityId sprite;
  late final EntityId text;

  /// Switches the look: `primary`, `secondary` or `disabled`.
  void setStyle(World world, String style) {
    world.componentsOf<eng.Sprite>().get(sprite)?.region = style;
    world.componentsOf<eng.Text>().get(text)?.colorArgb = _textColorFor(style);
  }

  /// Removes the button's entities.
  void destroy(World world) {
    world.destroy(sprite);
    world.destroy(text);
  }
}

/// Label color for each button style. `disabled` used to be a dark
/// brown-grey (`0xFF7D7468`) that all but disappeared against the equally
/// dark panel art it sits on — a real readability bug (reported against the
/// glossary's inactive category tabs), not just a lower-emphasis choice. A
/// lighter, more desaturated grey keeps it visually subordinate to
/// `primary`'s warm gold without going unreadable.
int _textColorFor(String style) =>
    style == 'disabled' ? 0xFFCFC6B5 : 0xFFFFF3C7;
