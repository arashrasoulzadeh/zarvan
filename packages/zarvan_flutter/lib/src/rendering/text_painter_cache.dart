import 'dart:collection' show LinkedHashMap;

import 'package:flutter/painting.dart' show TextPainter;

/// Laid-out `TextPainter`s, reused across frames. Shaping and laying out a
/// text is by far the most expensive part of drawing it, and the engine used
/// to redo it for every `Text` entity on every frame; on a phone a screen with
/// a few dozen texts (a poem in a calligraphic face) spent 25 ms in paint
/// about once a second. A painter is keyed by everything that changes how it
/// looks or lays out, so a text that is not changing costs one lookup. Least
/// recently used entries are dropped past [capacity]. An `EngineView` keeps
/// one in its `State`, because its painter is rebuilt every frame.
class TextPainterCache {
  TextPainterCache({this.capacity = 512});

  final int capacity;
  final LinkedHashMap<Object, TextPainter> _byKey = LinkedHashMap();

  /// The painter for [key], made by [create] the first time it is asked for.
  TextPainter obtain(Object key, TextPainter Function() create) {
    final hit = _byKey.remove(key);
    if (hit != null) {
      _byKey[key] = hit; // most recently used goes last
      return hit;
    }
    final fresh = create();
    _byKey[key] = fresh;
    while (_byKey.length > capacity) {
      final oldest = _byKey.keys.first;
      _byKey.remove(oldest)!.dispose();
    }
    return fresh;
  }

  void dispose() {
    for (final p in _byKey.values) {
      p.dispose();
    }
    _byKey.clear();
  }
}
