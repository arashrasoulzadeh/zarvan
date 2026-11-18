import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart' show World;

import '../rendering/text.dart';
import 'ui_builder.dart';

/// A page of words that swirls in from the edges of the screen and settles in
/// rows, or lifts off and scatters again: the text half of a "verse dissolve"
/// transition. Each word is an ordinary engine [Text] entity, so it can be
/// any script the font has; the game gives it words (lines of poetry) and
/// calls [apply] with a progress from 0 (nothing visible) to 1 (the screen
/// filled with words), usually under a dark full-screen effect.
class WordSwarm {
  /// Spawns one text entity per cell of a grid over [width] x [height] world
  /// units, taking words from [words] (repeating them when there are fewer).
  /// [seed] fixes where each word comes from and when it moves.
  WordSwarm(
    World world,
    List<String> words, {
    required this.width,
    required this.height,
    required String fontFamily,
    required int color,
    required int accentColor,
    this.rtl = false,
    this.fontSize = 22,
    this.columns = 3,
    this.rowHeight = 40,
    int zIndex = 101,
    int seed = 1,
  }) : _world = world {
    final rng = math.Random(seed);
    final rows = math.max(1, (height / rowHeight).floor());
    final cellW = width / columns;
    final pool = words.where((w) => w.trim().isNotEmpty).toList();
    if (pool.isEmpty) return;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final word = pool[rng.nextInt(pool.length)];
        final node = UiNode.textNode(
          world,
          Text(
            word,
            fontSize: fontSize,
            colorArgb: rng.nextDouble() < 0.22 ? accentColor : color,
            zIndex: zIndex,
            rtl: rtl,
          ),
          fontFamily: fontFamily,
        );
        node.text!.alpha = 0;
        _words.add(
          _SwarmWord(
            node,
            targetX:
                (c + 0.5) * cellW + (rng.nextDouble() - 0.5) * cellW * 0.25,
            targetY: (r + 0.5) * (height / rows),
            delay: rng.nextDouble(),
            turn: (rng.nextBool() ? 1 : -1) * (1.6 + rng.nextDouble() * 1.6),
          ),
        );
      }
    }
  }

  final World _world;
  final double width;
  final double height;
  final bool rtl;
  final double fontSize;
  final int columns;
  final double rowHeight;
  final List<_SwarmWord> _words = [];

  /// How many words there are.
  int get length => _words.length;

  /// The text entities, in grid order (left to right, top to bottom).
  Iterable<UiNode> get nodes => _words.map((w) => w.node);

  /// Places every word for [progress] (0 hidden, 1 settled in its row). Words
  /// spiral in around ([originX], [originY]) (fractions of the screen), each
  /// starting a little after the last so the page fills like a wave; going
  /// back down the same path scatters them.
  void apply(double progress, {double originX = 0.5, double originY = 0.5}) {
    final ox = originX * width;
    final oy = originY * height;
    final reach = math.sqrt(width * width + height * height);
    for (final w in _words) {
      final raw = ((progress * 1.8 - w.delay * 0.9) / 0.7).clamp(0.0, 1.0);
      final t = 1 - math.pow(1 - raw, 3).toDouble();
      final dx = w.targetX - ox;
      final dy = w.targetY - oy;
      final radius = math.sqrt(dx * dx + dy * dy);
      final angle = math.atan2(dy, dx);
      final r = radius + (1 - t) * reach * 0.55;
      final a = angle + (1 - t) * w.turn;
      w.node.pos.x = ox + math.cos(a) * r;
      w.node.pos.y = oy + math.sin(a) * r;
      w.node.text!
        ..alpha = raw <= 0 ? 0 : math.min(1.0, raw * 2)
        ..textScale = 0.55 + 0.45 * t;
    }
  }

  /// Removes every word from the world.
  void dispose() {
    for (final w in _words) {
      _world.destroy(w.node.id);
    }
    _words.clear();
  }
}

class _SwarmWord {
  _SwarmWord(
    this.node, {
    required this.targetX,
    required this.targetY,
    required this.delay,
    required this.turn,
  });

  final UiNode node;
  final double targetX;
  final double targetY;
  final double delay;
  final double turn;
}
