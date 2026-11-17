import 'dart:convert';

const int _mask = 0xFFFFFFFF;

/// 32-bit multiply that stays exact on the web, where `int` is a double and a
/// plain `a * b` of two 32-bit values loses low bits above 2^53. Splitting
/// one operand into 16-bit halves keeps every partial product under 2^49.
int _imul(int a, int b) {
  final hi = (a >> 16) & 0xFFFF;
  final lo = a & 0xFFFF;
  return ((lo * b) + (((hi * b) & 0xFFFF) << 16)) & _mask;
}

/// A seed from text, so a game can write `seedOf('daily:2026-11-17')`.
/// FNV-1a over the UTF-8 bytes, 32 bits: the same on every platform.
int seedOf(String key) {
  var h = 0x811C9DC5;
  for (final byte in utf8.encode(key)) {
    h = _imul(h ^ byte, 0x01000193);
  }
  return h & _mask;
}

/// A seeded generator (mulberry32) that gives the same sequence on the VM and
/// on the web. `dart:math` `Random(seed)` promises neither, and a daily
/// challenge must show every player the same questions.
class SeededRandom {
  SeededRandom(int seed) : _state = seed & _mask;

  int _state;

  /// The next value in `[0, 2^32)`.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _imul((_state ^ (_state >> 15)) & _mask, (1 | _state) & _mask);
    t = ((t + _imul((t ^ (t >> 7)) & _mask, (61 | t) & _mask)) & _mask) ^ t;
    return (t ^ (t >> 14)) & _mask;
  }

  /// A double in `[0, 1)`.
  double nextDouble() => nextUint32() / 4294967296;

  /// An int in `[0, max)`. Goes through the double so no product exceeds
  /// 2^53, which would round differently on the web.
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    return (nextDouble() * max).floor();
  }

  /// Fisher-Yates in place, so the order depends only on the seed.
  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }

  /// One element of [list].
  T pick<T>(List<T> list) {
    if (list.isEmpty) throw ArgumentError('cannot pick from an empty list');
    return list[nextInt(list.length)];
  }
}
