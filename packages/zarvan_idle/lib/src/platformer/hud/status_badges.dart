import 'dart:ui' show Size;

import 'package:zarvan_core/zarvan_core.dart' hide StatusEffect, StatusEffects;
import 'package:zarvan_flutter/zarvan_flutter.dart'
    as eng
    show Sprite, Text, spawnWorldText;

import '../combat/conditions.dart';

/// Where the hero's status badges sit (world units): a column starting at
/// ([x], [y]), [step] apart, each badge [size] wide. Put it on the side of the
/// screen opposite the skill icons.
class StatusBadgeStyle {
  const StatusBadgeStyle({
    required this.x,
    required this.y,
    this.step = 14,
    this.size = 11,
    this.colors = const {
      ConditionKind.bleed: 0xFFC8282E,
      ConditionKind.poison: 0xFF3FA34D,
      ConditionKind.stun: 0xFFE0B02A,
    },
  });

  /// Centre of the first badge; later ones are below it.
  final double x;
  final double y;
  final double step;
  final double size;

  /// Badge colour per condition.
  final Map<ConditionKind, int> colors;
}

/// One small badge per [ConditionKind] showing what afflicts a fighter and for
/// how many more seconds (with `xN` for stacks), instead of a text line.
/// Badges for conditions that are not active are parked off screen.
class StatusBadges {
  StatusBadges.spawn(
    World world, {
    required this.style,
    required String fillAtlasId,
    Size fillSize = const Size(48, 27),
    int zIndex = 112,
  }) {
    for (final kind in ConditionKind.values) {
      final block = world.spawn();
      world.componentsOf<Position>().set(block, Position(style.x, _hidden));
      world.componentsOf<eng.Sprite>().set(
        block,
        eng.Sprite(
          fillAtlasId,
          'f11',
          scaleX: style.size / fillSize.width,
          scaleY: style.size / fillSize.height,
          zIndex: zIndex,
          tintArgb: style.colors[kind] ?? 0xFFFFFFFF,
        ),
      );
      _blocks[kind] = block;
      _labels[kind] = eng.spawnWorldText(
        world,
        style.x,
        _hidden,
        '',
        fontSize: 4.6,
        colorArgb: 0xFFFFFFFF,
        zIndex: zIndex + 1,
      );
    }
  }

  static const _hidden = -1000.0;

  final StatusBadgeStyle style;
  final _blocks = <ConditionKind, EntityId>{};
  final _labels = <ConditionKind, EntityId>{};

  /// Shows a badge for each condition in [conditions] (null for none), stacked
  /// from the top of the column, and parks the rest.
  void sync(World world, Conditions? conditions) {
    final positions = world.componentsOf<Position>();
    final texts = world.componentsOf<eng.Text>();
    var slot = 0;
    for (final kind in ConditionKind.values) {
      StatusEffect? e;
      for (final a in conditions?.active ?? const <StatusEffect>[]) {
        if (a.kind == kind) e = a;
      }
      final y = e == null ? _hidden : style.y + slot * style.step;
      if (e != null) slot++;
      positions.get(_blocks[kind]!)?.y = y;
      positions.get(_labels[kind]!)?.y = y;
      texts.get(_labels[kind]!)?.text = e == null
          ? ''
          : '${e.remaining.ceil()}${e.stacks > 1 ? '×${e.stacks}' : ''}';
    }
  }
}
