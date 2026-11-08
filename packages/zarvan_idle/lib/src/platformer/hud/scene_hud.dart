import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng show Text;

import 'hud_layout.dart';
import 'world_text.dart';

/// Labels for a portrait idle-combat scene: a status line, the
/// current enemy's name. Where they sit comes from a [HudLayout]; the enemy's
/// description is a `DialogueCaption`.
class SceneHud {
  SceneHud._(this._status, this._enemy, this._ult);

  final EntityId _status;
  final EntityId _enemy;

  /// The ultimate-meter label, present only when the layout has [HudLayout.ultText].
  final EntityId? _ult;

  factory SceneHud.spawn(
    World world, {
    required String status,
    HudLayout layout = const HudLayout(),
  }) => SceneHud._(
    _text(world, layout.status, status),
    _text(world, layout.enemy, ''),
    layout.ultText == null ? null : _text(world, layout.ultText!, ''),
  );

  void sync(
    World world, {
    required String status,
    required String enemy,
    String ultimate = '',
  }) {
    final texts = world.componentsOf<eng.Text>();
    texts.get(_status)?.text = status;
    texts.get(_enemy)?.text = enemy;
    if (_ult != null) texts.get(_ult)?.text = ultimate;
  }

  static EntityId _text(World world, HudTextStyle style, String text) =>
      spawnWorldText(
        world,
        style.x,
        style.y,
        text,
        fontSize: style.fontSize,
        colorArgb: style.colorArgb,
        zIndex: 110,
        maxWidth: style.maxWidth,
        rtl: style.rtl,
        align: style.align,
      );
}
