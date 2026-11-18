import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/src/rendering/text_painter_cache.dart';

TextPainter _painter(String s) => TextPainter(
  text: TextSpan(text: s),
  textDirection: TextDirection.ltr,
)..layout();

void main() {
  test('the same key returns the same laid-out painter, made only once', () {
    final cache = TextPainterCache();
    var made = 0;
    final a = cache.obtain('a', () {
      made++;
      return _painter('a');
    });
    final again = cache.obtain('a', () {
      made++;
      return _painter('a');
    });
    expect(identical(a, again), isTrue);
    expect(made, 1, reason: 'a text that did not change is not laid out again');
    cache.dispose();
  });

  test(
    'a different key (another colour, size or text) gets its own painter',
    () {
      final cache = TextPainterCache();
      final a = cache.obtain(('x', 12.0, 0xFF000000), () => _painter('x'));
      final b = cache.obtain(('x', 12.0, 0x80000000), () => _painter('x'));
      expect(identical(a, b), isFalse);
      cache.dispose();
    },
  );

  test('past its capacity the least recently used painter is dropped', () {
    final cache = TextPainterCache(capacity: 2);
    var made = 0;
    TextPainter make(String s) => cache.obtain(s, () {
      made++;
      return _painter(s);
    });
    make('a');
    make('b');
    make('a'); // a is now the most recently used
    make('c'); // evicts b
    expect(made, 3);
    make('a'); // still cached
    expect(made, 3);
    make('b'); // was evicted: laid out again
    expect(made, 4);
    cache.dispose();
  });
}
